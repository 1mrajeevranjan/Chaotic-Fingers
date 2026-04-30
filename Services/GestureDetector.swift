import Foundation
import CoreGraphics
import AppKit

enum GestureType {
    case shiftHold // Left + Right Shift hold 3s (Keyboard)
    case commandHold // Left + Right Command hold 3s (Both)
    case optionHold // Left + Right Option hold 3s (Trackpad)
    case forceQuit // ESC x2 -> Return x2
}

class GestureDetector {
    var onGestureTriggered: ((GestureType) -> Void)?
    
    // State for Keyboard (Left + Right Shift hold 3s)
    private var isLShiftDown = false
    private var isRShiftDown = false
    private var shiftHoldTimer: Timer?
    
    // State for Both (Left + Right Command hold 3s)
    private var isLCommandDown = false
    private var isRCommandDown = false
    private var commandHoldTimer: Timer?
    
    // State for Trackpad (Left + Right Option hold 3s)
    private var isLOptionDown = false
    private var isROptionDown = false
    private var optionHoldTimer: Timer?
    
    // State for Force Quit (ESC x2 -> Return x2)
    private var failsafeSequence: [Int] = []
    private var lastFailsafeTime: Date?
    
    // MARK: - Event Handling
    
    func handleMouseEvent(_ event: CGEvent, type: CGEventType) {
        // Trackpad gestures now use Option+Option hold (detected via handleKeyboardEvent flagsChanged)
        // This method can be kept for future mouse-specific needs or left empty for now.
    }
    
    func handleKeyboardEvent(_ event: CGEvent, type: CGEventType) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        if type == .flagsChanged {
            let flags = event.flags
            
            // Shift Keys: Left (56), Right (60)
            if keyCode == 56 {
                isLShiftDown = flags.contains(.maskShift)
            } else if keyCode == 60 {
                isRShiftDown = flags.contains(.maskShift)
            }
            
            // Command Keys: Left (55), Right (54)
            if keyCode == 55 {
                isLCommandDown = flags.contains(.maskCommand)
            } else if keyCode == 54 {
                isRCommandDown = flags.contains(.maskCommand)
            }
            
            // Option Keys: Left (58), Right (61)
            if keyCode == 58 {
                isLOptionDown = flags.contains(.maskAlternate)
            } else if keyCode == 61 {
                isROptionDown = flags.contains(.maskAlternate)
            }
            
            checkModifierGestures()
            return
        }
        
        // Failsafe part for ESC (53) and Return (36)
        if keyCode == 53 || keyCode == 36 {
            handleFailsafe(keyCode: Int(keyCode), type: type)
        }
    }
    
    private func checkModifierGestures() {
        // Keyboard Mode Gesture: L+R Shift
        if isLShiftDown && isRShiftDown {
            if shiftHoldTimer == nil {
                startHoldTimer(for: .shiftHold)
            }
        } else {
            shiftHoldTimer?.invalidate()
            shiftHoldTimer = nil
        }
        
        // Both Mode Gesture: L+R Command
        if isLCommandDown && isRCommandDown {
            if commandHoldTimer == nil {
                startHoldTimer(for: .commandHold)
            }
        } else {
            commandHoldTimer?.invalidate()
            commandHoldTimer = nil
        }
        
        // Trackpad Mode Gesture: L+R Option
        if isLOptionDown && isROptionDown {
            if optionHoldTimer == nil {
                startHoldTimer(for: .optionHold)
            }
        } else {
            optionHoldTimer?.invalidate()
            optionHoldTimer = nil
        }
    }
    
    private func startHoldTimer(for gesture: GestureType) {
        switch gesture {
        case .shiftHold:
            shiftHoldTimer?.invalidate()
            shiftHoldTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                if self?.isLShiftDown == true && self?.isRShiftDown == true {
                    self?.onGestureTriggered?(.shiftHold)
                }
            }
        case .commandHold:
            commandHoldTimer?.invalidate()
            commandHoldTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                if self?.isLCommandDown == true && self?.isRCommandDown == true {
                    self?.onGestureTriggered?(.commandHold)
                }
            }
        case .optionHold:
            optionHoldTimer?.invalidate()
            optionHoldTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                if self?.isLOptionDown == true && self?.isROptionDown == true {
                    self?.onGestureTriggered?(.optionHold)
                }
            }
        default:
            break
        }
    }
    
    private func handleFailsafe(keyCode: Int, type: CGEventType) {
        guard type == .keyDown else { return }
        
        let now = Date()
        if let last = lastFailsafeTime, now.timeIntervalSince(last) > 2.0 {
            failsafeSequence.removeAll()
        }
        lastFailsafeTime = now
        
        failsafeSequence.append(keyCode)
        
        // Keep only last 4 keys
        if failsafeSequence.count > 4 {
            failsafeSequence.removeFirst()
        }
        
        if failsafeSequence == [53, 53, 36, 36] {
            onGestureTriggered?(.forceQuit)
            failsafeSequence.removeAll()
        }
    }
}
