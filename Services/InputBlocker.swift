import Foundation
import CoreGraphics
import AppKit
import Observation

@Observable
@MainActor
class InputBlocker {
    enum BlockingMode: String {
        case none, keyboard, trackpad, both
    }
    
    var currentMode: BlockingMode = .none
    var isBlocking: Bool { currentMode != .none }
    
    private var keyboardTap: CFMachPort?
    private var trackpadTap: CFMachPort?
    
    // Non-isolated state for the tap callbacks
    private let state = InternalState()
    
    var onDeactivate: (() -> Void)?
    
    init() {
        state.onGesture = { [weak self] gesture in
            Task { @MainActor in
                self?.handleGesture(gesture)
            }
        }
    }
    
    func startBlocking(_ mode: BlockingMode) {
        stopBlocking()
        currentMode = mode
        state.currentMode = mode
        
        switch mode {
        case .keyboard:
            setupKeyboardTap()
        case .trackpad:
            updateWindowFrames()
            setupKeyboardTap()
            setupTrackpadTap()
            NSCursor.hide()
        case .both:
            updateWindowFrames()
            setupKeyboardTap()
            setupTrackpadTap()
            NSCursor.hide()
        case .none:
            break
        }
    }
    
    func stopBlocking() {
        if let tap = keyboardTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            keyboardTap = nil
        }
        if let tap = trackpadTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            trackpadTap = nil
        }
        currentMode = .none
        state.currentMode = .none
        
        // Ensure cursor is shown when blocking stops
        NSCursor.unhide()
        
        onDeactivate?()
    }
    
    private func handleGesture(_ gesture: GestureType) {
        switch (currentMode, gesture) {
        case (.keyboard, .shiftHold),
             (.trackpad, .optionHold),
             (.both, .commandHold):
            stopBlocking()
            onDeactivate?()
        case (_, .forceQuit):
            NSApp.terminate(nil)
        default:
            break
        }
    }
    
    // MARK: - Tap Setup
    
    private func setupKeyboardTap(allowEsc: Bool = false) {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(state).toOpaque())
        
        keyboardTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let state = Unmanaged<InternalState>.fromOpaque(refcon).takeUnretainedValue()
                
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                state.detector.handleKeyboardEvent(event, type: type)
                
                if state.currentMode == .keyboard {
                    return nil
                } else if state.currentMode == .both {
                    if keyCode == 53 { return Unmanaged.passUnretained(event) } // Allow ESC for force quit
                    return nil
                } else if state.currentMode == .trackpad {
                    // Keyboard is NOT blocked in trackpad mode, just passing through to detector
                    return Unmanaged.passUnretained(event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: userInfo
        )
        
        if let tap = keyboardTap {
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
    
    private func setupTrackpadTap() {
        let mask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.leftMouseUp.rawValue) |
                   (1 << CGEventType.rightMouseDown.rawValue) | (1 << CGEventType.rightMouseUp.rawValue) |
                   (1 << CGEventType.mouseMoved.rawValue) | (1 << CGEventType.scrollWheel.rawValue) |
                   (1 << CGEventType.otherMouseDown.rawValue) | (1 << CGEventType.otherMouseUp.rawValue) |
                   (1 << CGEventType.leftMouseDragged.rawValue) | (1 << CGEventType.rightMouseDragged.rawValue) |
                   (1 << CGEventType.otherMouseDragged.rawValue) | (1 << CGEventType.tabletPointer.rawValue) |
                   (1 << CGEventType.tabletProximity.rawValue) | (1 << CGEventType.mouseMoved.rawValue)
        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(state).toOpaque())
        
        trackpadTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let state = Unmanaged<InternalState>.fromOpaque(refcon).takeUnretainedValue()
                
                // Fast check using stored frames
                let location = event.location
                var isOurWindow = false
                
                // CGEvent location is (0,0) top-left. 
                // We need to check against our windows.
                for frame in state.windowFrames {
                    if location.x >= frame.origin.x && 
                       location.x <= (frame.origin.x + frame.size.width) &&
                       location.y >= frame.origin.y && 
                       location.y <= (frame.origin.y + frame.size.height) {
                        isOurWindow = true
                        break
                    }
                }
                
                state.detector.handleMouseEvent(event, type: type)
                
                if isOurWindow {
                    return Unmanaged.passUnretained(event)
                }
                return nil
            },
            userInfo: userInfo
        )
        
        if let tap = trackpadTap {
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
    
    
    private func updateWindowFrames() {
        let screens = NSScreen.screens
        guard let mainScreen = screens.first else { return }
        let screenHeight = mainScreen.frame.height
        
        state.windowFrames = NSApp.windows.filter { $0.isVisible }.map { window in
            let frame = window.frame
            // Convert bottom-left origin to top-left origin for CGEvent comparison
            return CGRect(x: frame.origin.x, 
                          y: screenHeight - (frame.origin.y + frame.size.height), 
                          width: frame.size.width, 
                          height: frame.size.height)
        }
    }
    
    // Internal class to hold state safely for C callbacks
    private class InternalState: @unchecked Sendable {
        var currentMode: BlockingMode = .none
        let detector = GestureDetector()
        var onGesture: ((GestureType) -> Void)?
        var windowFrames: [CGRect] = []
        
        init() {
            detector.onGestureTriggered = { [weak self] gesture in
                self?.onGesture?(gesture)
            }
        }
    }
}
