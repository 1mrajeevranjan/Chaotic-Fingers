import Foundation
import CoreGraphics
import AppKit
import Observation
import ChaoticFingersCore

@Observable
@MainActor
final class InputBlocker {
    typealias BlockingMode = ChaoticFingersCore.BlockingMode

    private(set) var currentMode: BlockingMode = .none
    /// Set when a tap could not be created — almost always a missing
    /// Accessibility grant. Without this the UI would claim to be blocking
    /// while every event sailed through.
    private(set) var permissionDenied = false

    var isBlocking: Bool { currentMode != .none }

    /// Why blocking ended. A gesture can fire with every window hidden, which
    /// is the only case that may need the UI brought forward.
    enum DeactivationReason {
        case request
        case gesture
    }

    var onDeactivate: ((DeactivationReason) -> Void)?

    private var taps: [EventTap] = []
    private var isCursorHidden = false

    /// Callback-visible state. CGEvent tap callbacks are C functions, so they
    /// cannot touch the MainActor-isolated class directly.
    private let state = InternalState()

    init() {
        state.onGesture = { [weak self] gesture in
            Task { @MainActor in
                self?.handleGesture(gesture)
            }
        }
    }

    // MARK: - Lifecycle

    func startBlocking(_ mode: BlockingMode) {
        guard mode != .none else {
            stopBlocking()
            return
        }

        teardownTaps()
        state.currentMode = mode
        state.detector.reset()
        updateWindowFrames()

        // The keyboard tap is installed in every mode: release gestures are
        // modifier holds, so the keystream must be observed even when keys
        // themselves are passed through.
        var created: [EventTap] = []
        if let keyboard = makeTap(mask: Self.keyboardMask, callback: Self.keyboardCallback) {
            created.append(keyboard)
        }
        if mode.suppressesPointer, let pointer = makeTap(mask: Self.pointerMask, callback: Self.pointerCallback) {
            created.append(pointer)
        }

        let expected = mode.suppressesPointer ? 2 : 1
        taps = created
        state.ports = created.map(\.port)

        guard created.count == expected else {
            teardownTaps()
            state.currentMode = .none
            currentMode = .none
            permissionDenied = true
            return
        }

        permissionDenied = false
        currentMode = mode
        setCursorHidden(mode.suppressesPointer)
    }

    func stopBlocking(reason: DeactivationReason = .request) {
        guard currentMode != .none else { return }

        teardownTaps()
        state.currentMode = .none
        state.detector.reset()
        currentMode = .none
        setCursorHidden(false)

        onDeactivate?(reason)
    }

    func clearPermissionWarning() {
        permissionDenied = false
    }

    private func handleGesture(_ gesture: GestureType) {
        if gesture == .forceQuit {
            NSApp.terminate(nil)
            return
        }
        guard currentMode.releaseGesture == gesture else { return }
        stopBlocking(reason: .gesture)
    }

    // MARK: - Event taps

    private static func mask(_ types: [CGEventType]) -> CGEventMask {
        types.reduce(into: CGEventMask(0)) { $0 |= CGEventMask(1) << CGEventMask($1.rawValue) }
    }

    private static let keyboardMask = mask([.keyDown, .keyUp, .flagsChanged])

    private static let pointerMask = mask([
        .leftMouseDown, .leftMouseUp, .leftMouseDragged,
        .rightMouseDown, .rightMouseUp, .rightMouseDragged,
        .otherMouseDown, .otherMouseUp, .otherMouseDragged,
        .mouseMoved, .scrollWheel,
        .tabletPointer, .tabletProximity
    ])

    private static let keyboardCallback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let state = Unmanaged<InternalState>.fromOpaque(refcon).takeUnretainedValue()

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            state.reenableTaps()
            return nil
        }

        state.detector.handleKeyboardEvent(event, type: type)
        return state.currentMode.suppressesKeyboard ? nil : Unmanaged.passUnretained(event)
    }

    private static let pointerCallback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let state = Unmanaged<InternalState>.fromOpaque(refcon).takeUnretainedValue()

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            state.reenableTaps()
            return nil
        }

        // Our own windows stay clickable so Stop is always reachable by mouse.
        let location = event.location
        let overOwnWindow = state.windowFrames.contains { $0.contains(location) }
        return overOwnWindow ? Unmanaged.passUnretained(event) : nil
    }

    private struct EventTap {
        let port: CFMachPort
        let source: CFRunLoopSource
    }

    private func makeTap(mask: CGEventMask, callback: @escaping CGEventTapCallBack) -> EventTap? {
        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(state).toOpaque())
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: userInfo
        ) else { return nil }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else {
            CFMachPortInvalidate(port)
            return nil
        }

        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return EventTap(port: port, source: source)
    }

    /// Disabling a tap is not enough — the run loop source and mach port stay
    /// alive and every start/stop cycle would leak one of each.
    private func teardownTaps() {
        for tap in taps {
            CGEvent.tapEnable(tap: tap.port, enable: false)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), tap.source, .commonModes)
            CFMachPortInvalidate(tap.port)
        }
        taps.removeAll()
        state.ports.removeAll()
    }

    // MARK: - Helpers

    /// `NSCursor.hide()`/`unhide()` are reference counted; an unbalanced pair
    /// leaves the pointer invisible for the rest of the session.
    private func setCursorHidden(_ hidden: Bool) {
        guard hidden != isCursorHidden else { return }
        isCursorHidden = hidden
        if hidden { NSCursor.hide() } else { NSCursor.unhide() }
    }

    private func updateWindowFrames() {
        guard let primary = NSScreen.screens.first else { return }
        let globalMaxY = primary.frame.maxY

        state.windowFrames = NSApp.windows.filter(\.isVisible).map { window in
            // AppKit frames are bottom-left origin; CGEvent locations are top-left.
            CGRect(x: window.frame.minX,
                   y: globalMaxY - window.frame.maxY,
                   width: window.frame.width,
                   height: window.frame.height)
        }
    }

    private final class InternalState: @unchecked Sendable {
        var currentMode: BlockingMode = .none
        var windowFrames: [CGRect] = []
        var ports: [CFMachPort] = []
        let detector = GestureDetector()
        var onGesture: ((GestureType) -> Void)?

        init() {
            detector.onGestureTriggered = { [weak self] gesture in
                self?.onGesture?(gesture)
            }
        }

        /// macOS kills a tap whose callback runs long. Without this the app
        /// silently stops blocking and never recovers.
        func reenableTaps() {
            for port in ports {
                CGEvent.tapEnable(tap: port, enable: true)
            }
        }
    }
}
