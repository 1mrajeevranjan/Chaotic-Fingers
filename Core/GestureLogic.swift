import Foundation

/// Which inputs are currently suppressed.
public enum BlockingMode: String, Sendable {
    case none, keyboard, trackpad, both
}

/// Physical escape hatches. Every blocking mode has exactly one release
/// gesture; `forceQuit` works in any mode.
public enum GestureType: Hashable, Sendable {
    case shiftHold
    case optionHold
    case commandHold
    case forceQuit
}

public extension BlockingMode {
    var releaseGesture: GestureType? {
        switch self {
        case .keyboard: return .shiftHold
        case .trackpad: return .optionHold
        case .both:     return .commandHold
        case .none:     return nil
        }
    }

    /// Compact label for menus and pickers, matching the dashboard's segments.
    var shortTitle: String {
        switch self {
        case .keyboard: return "Keyboard"
        case .trackpad: return "Trackpad"
        case .both:     return "Both"
        case .none:     return "Nothing"
        }
    }

    /// Spelled-out name, for tooltips and status copy where there is room.
    var title: String {
        switch self {
        case .keyboard: return "Keyboard"
        case .trackpad: return "Trackpad"
        case .both:     return "Keyboard and Trackpad"
        case .none:     return "Nothing"
        }
    }

    /// The modes a user can actually pick, in display order.
    static var selectable: [BlockingMode] { [.keyboard, .trackpad, .both] }

    /// Keyboard events are suppressed in these modes. A tap is installed in
    /// every mode regardless, because release gestures are modifier holds.
    var suppressesKeyboard: Bool { self == .keyboard || self == .both }

    var suppressesPointer: Bool { self == .trackpad || self == .both }
}

/// Left/right state of the three modifier pairs used for release gestures.
///
/// `CGEventFlags.maskShift` only says "a shift is down" — it cannot tell the
/// sides apart, so releasing one shift while the other is held leaves the
/// released side stuck "down" forever. The device-dependent bits that macOS
/// puts in the same flags field do distinguish them.
public struct ModifierPairs: Equatable, Sendable {
    public var leftShift = false
    public var rightShift = false
    public var leftOption = false
    public var rightOption = false
    public var leftCommand = false
    public var rightCommand = false

    public init() {}

    // IOKit NX_DEVICE*KEYMASK values (IOLLEvent.h).
    private enum Mask {
        static let leftShift: UInt64   = 0x0000_0002
        static let rightShift: UInt64  = 0x0000_0004
        static let leftCommand: UInt64 = 0x0000_0008
        static let rightCommand: UInt64 = 0x0000_0010
        static let leftOption: UInt64  = 0x0000_0020
        static let rightOption: UInt64 = 0x0000_0040
    }

    public mutating func update(flags: UInt64) {
        leftShift    = flags & Mask.leftShift != 0
        rightShift   = flags & Mask.rightShift != 0
        leftOption   = flags & Mask.leftOption != 0
        rightOption  = flags & Mask.rightOption != 0
        leftCommand  = flags & Mask.leftCommand != 0
        rightCommand = flags & Mask.rightCommand != 0
    }

    /// Hold gestures whose key pair is fully depressed right now.
    public var activeHolds: Set<GestureType> {
        var holds = Set<GestureType>()
        if leftShift && rightShift { holds.insert(.shiftHold) }
        if leftOption && rightOption { holds.insert(.optionHold) }
        if leftCommand && rightCommand { holds.insert(.commandHold) }
        return holds
    }
}

/// Last-resort quit sequence: Esc, Esc, Return, Return typed within
/// `window` seconds of each other.
public struct FailsafeTracker: Sendable {
    public static let escapeKeyCode = 53
    public static let returnKeyCode = 36
    public static let pattern = [escapeKeyCode, escapeKeyCode, returnKeyCode, returnKeyCode]
    public static let window: TimeInterval = 2.0

    private var recent: [Int] = []
    private var lastKeyAt: Date?

    public init() {}

    /// Feeds one key-down. Returns `true` on the keystroke that completes the
    /// sequence, and resets so the next completion needs the full pattern again.
    public mutating func accept(keyCode: Int, at now: Date) -> Bool {
        guard Self.pattern.contains(keyCode) else {
            reset()
            return false
        }
        if let last = lastKeyAt, now.timeIntervalSince(last) > Self.window {
            recent.removeAll()
        }
        lastKeyAt = now

        recent.append(keyCode)
        if recent.count > Self.pattern.count {
            recent.removeFirst(recent.count - Self.pattern.count)
        }
        guard recent == Self.pattern else { return false }
        reset()
        return true
    }

    public mutating func reset() {
        recent.removeAll()
        lastKeyAt = nil
    }
}
