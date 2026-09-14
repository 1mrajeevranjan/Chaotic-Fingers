import Foundation
import CoreGraphics
import ChaoticFingersCore

/// Watches the tapped keyboard stream for the physical escape hatches.
///
/// Recognition itself lives in `ChaoticFingersCore` (`ModifierPairs`,
/// `FailsafeTracker`); this type only owns the CGEvent glue and the hold timers.
final class GestureDetector {
    static let holdDuration: TimeInterval = 3.0

    var onGestureTriggered: ((GestureType) -> Void)?

    private var pairs = ModifierPairs()
    private var failsafe = FailsafeTracker()
    private var holdTimers: [GestureType: Timer] = [:]

    func handleKeyboardEvent(_ event: CGEvent, type: CGEventType) {
        if type == .flagsChanged {
            pairs.update(flags: event.flags.rawValue)
            syncHoldTimers()
            return
        }

        guard type == .keyDown else { return }
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        if failsafe.accept(keyCode: keyCode, at: Date()) {
            onGestureTriggered?(.forceQuit)
        }
    }

    /// Drops every in-flight hold. Called when blocking stops so a modifier
    /// still held at that moment cannot fire against the next session.
    func reset() {
        for timer in holdTimers.values { timer.invalidate() }
        holdTimers.removeAll()
        pairs = ModifierPairs()
        failsafe.reset()
    }

    private func syncHoldTimers() {
        let active = pairs.activeHolds

        for (gesture, timer) in holdTimers where !active.contains(gesture) {
            timer.invalidate()
            holdTimers[gesture] = nil
        }

        for gesture in active where holdTimers[gesture] == nil {
            let timer = Timer(timeInterval: Self.holdDuration, repeats: false) { [weak self] _ in
                guard let self, self.pairs.activeHolds.contains(gesture) else { return }
                self.holdTimers[gesture] = nil
                self.onGestureTriggered?(gesture)
            }
            // .common, not the default mode: a tracking loop (open menu, window
            // drag) would otherwise stall the timer past its fire date.
            RunLoop.main.add(timer, forMode: .common)
            holdTimers[gesture] = timer
        }
    }
}
