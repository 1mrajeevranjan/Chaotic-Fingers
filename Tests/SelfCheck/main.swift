// Assert-based self-check for the pure gesture logic.
//
// Run with:  swift run SelfCheck
//
// XCTest and swift-testing both ship inside Xcode, which is not required to
// build this package, so `swift test` cannot run here. This executable covers
// the same logic and exits non-zero on the first failure.

import Foundation
import ChaoticFingersCore

var failures = 0
var checks = 0

func check(_ name: String, _ condition: @autoclosure () -> Bool) {
    checks += 1
    if condition() {
        print("  ok   \(name)")
    } else {
        print("  FAIL \(name)")
        failures += 1
    }
}

func suite(_ name: String, _ body: () -> Void) {
    print("\(name)")
    body()
}

// Device-dependent modifier bits (IOLLEvent.h).
let lShift: UInt64  = 0x02
let rShift: UInt64  = 0x04
let lCommand: UInt64 = 0x08
let rCommand: UInt64 = 0x10
let lOption: UInt64 = 0x20
let rOption: UInt64 = 0x40
let shiftFlag: UInt64 = 0x0002_0000 // CGEventFlags.maskShift, side-agnostic

suite("BlockingMode") {
    check("keyboard releases on both-shift hold", BlockingMode.keyboard.releaseGesture == .shiftHold)
    check("trackpad releases on both-option hold", BlockingMode.trackpad.releaseGesture == .optionHold)
    check("both releases on both-command hold", BlockingMode.both.releaseGesture == .commandHold)
    check("none has no release gesture", BlockingMode.none.releaseGesture == nil)

    check("keyboard suppresses keys", BlockingMode.keyboard.suppressesKeyboard)
    check("both suppresses keys", BlockingMode.both.suppressesKeyboard)
    check("trackpad leaves keys alone", !BlockingMode.trackpad.suppressesKeyboard)
    check("trackpad suppresses pointer", BlockingMode.trackpad.suppressesPointer)
    check("keyboard leaves pointer alone", !BlockingMode.keyboard.suppressesPointer)

    // The menu bar's default-mode picker and the More submenu are both built
    // from `selectable`, so `.none` must never leak into either.
    check("three selectable modes", BlockingMode.selectable.count == 3)
    check("none is not selectable", !BlockingMode.selectable.contains(.none))
    check("every selectable mode blocks something",
          BlockingMode.selectable.allSatisfy { $0.suppressesKeyboard || $0.suppressesPointer })
    check("every selectable mode has a release gesture",
          BlockingMode.selectable.allSatisfy { $0.releaseGesture != nil })
    check("selectable modes have distinct titles",
          Set(BlockingMode.selectable.map(\.title)).count == 3)
    check("keyboard title reads Keyboard", BlockingMode.keyboard.title == "Keyboard")
}

suite("ModifierPairs") {
    var pairs = ModifierPairs()
    check("starts with nothing held", pairs.activeHolds.isEmpty)

    pairs.update(flags: shiftFlag | lShift)
    check("one shift is not a hold", pairs.activeHolds.isEmpty)

    pairs.update(flags: shiftFlag | lShift | rShift)
    check("both shifts trigger shiftHold", pairs.activeHolds == [.shiftHold])

    // Regression: the side-agnostic maskShift bit stays set while the other
    // shift is still down, so a side-agnostic reader would keep both sides
    // latched and never cancel the hold.
    pairs.update(flags: shiftFlag | rShift)
    check("releasing left shift clears the hold", pairs.activeHolds.isEmpty)
    check("left shift reads as up", !pairs.leftShift)
    check("right shift still reads as down", pairs.rightShift)

    pairs.update(flags: 0)
    check("clearing flags releases everything", pairs == ModifierPairs())

    pairs.update(flags: lOption | rOption)
    check("both options trigger optionHold", pairs.activeHolds == [.optionHold])

    pairs.update(flags: lCommand | rCommand)
    check("both commands trigger commandHold", pairs.activeHolds == [.commandHold])

    pairs.update(flags: lShift | rShift | lCommand | rCommand)
    check("two pairs report two holds", pairs.activeHolds == [.shiftHold, .commandHold])

    pairs.update(flags: lShift | rOption)
    check("mismatched sides are not a hold", pairs.activeHolds.isEmpty)
}

suite("FailsafeTracker") {
    let esc = FailsafeTracker.escapeKeyCode
    let ret = FailsafeTracker.returnKeyCode
    let t0 = Date(timeIntervalSince1970: 1_000)

    var tracker = FailsafeTracker()
    check("esc alone does not fire", !tracker.accept(keyCode: esc, at: t0))
    check("second esc does not fire", !tracker.accept(keyCode: esc, at: t0.addingTimeInterval(0.2)))
    check("first return does not fire", !tracker.accept(keyCode: ret, at: t0.addingTimeInterval(0.4)))
    check("second return fires", tracker.accept(keyCode: ret, at: t0.addingTimeInterval(0.6)))
    check("sequence resets after firing", !tracker.accept(keyCode: ret, at: t0.addingTimeInterval(0.8)))

    var slow = FailsafeTracker()
    _ = slow.accept(keyCode: esc, at: t0)
    _ = slow.accept(keyCode: esc, at: t0.addingTimeInterval(0.1))
    _ = slow.accept(keyCode: ret, at: t0.addingTimeInterval(0.2))
    check("a gap past the window drops the sequence",
          !slow.accept(keyCode: ret, at: t0.addingTimeInterval(0.2 + FailsafeTracker.window + 0.1)))

    var interrupted = FailsafeTracker()
    _ = interrupted.accept(keyCode: esc, at: t0)
    _ = interrupted.accept(keyCode: esc, at: t0)
    check("an unrelated key resets", !interrupted.accept(keyCode: 0, at: t0))
    _ = interrupted.accept(keyCode: ret, at: t0)
    check("return after a reset does not fire", !interrupted.accept(keyCode: ret, at: t0))

    var noisy = FailsafeTracker()
    _ = noisy.accept(keyCode: ret, at: t0)
    _ = noisy.accept(keyCode: esc, at: t0)
    _ = noisy.accept(keyCode: esc, at: t0)
    _ = noisy.accept(keyCode: ret, at: t0)
    check("leading noise still lets the pattern complete", noisy.accept(keyCode: ret, at: t0))
}

print("")
if failures == 0 {
    print("\(checks) checks passed")
} else {
    print("\(failures) of \(checks) checks FAILED")
    exit(1)
}
