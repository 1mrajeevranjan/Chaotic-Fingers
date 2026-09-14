// App-wide menu commands for starting and stopping blocking, plus a Help item
// listing the recovery gestures.

import SwiftUI
import AppKit
import ChaoticFingersCore

struct AppCommands: Commands {
    private var delegate: AppDelegate? { AppDelegate.shared }

    var body: some Commands {
        CommandMenu("Blocking") {
            Button("Start Keyboard Blocking") { delegate?.startBlocking(mode: .keyboard) }
                .keyboardShortcut("k", modifiers: [.command, .shift])

            Button("Start Trackpad Blocking") { delegate?.startBlocking(mode: .trackpad) }
                .keyboardShortcut("t", modifiers: [.command, .shift])

            Button("Start Both") { delegate?.startBlocking(mode: .both) }
                .keyboardShortcut("b", modifiers: [.command, .shift])

            Divider()

            Button("Stop Blocking") { delegate?.stopBlocking() }
                .keyboardShortcut(".", modifiers: .command)
        }

        // Without this the dashboard is unreachable from the menu bar once it
        // has been closed — the status item menu was the only way back.
        CommandGroup(before: .windowList) {
            Button("Dashboard") { delegate?.showMainWindow() }
                .keyboardShortcut("0", modifiers: .command)
            Divider()
        }

        // Replaces the stock Help item — a second `CommandMenu("Help")` would
        // add a duplicate Help menu next to the one AppKit already installs.
        CommandGroup(replacing: .help) {
            Button("Chaotic Fingers Help") { AppCommands.showGestureHelp() }
                .keyboardShortcut("?", modifiers: .command)
        }
    }

    static func showGestureHelp() {
        let alert = NSAlert()
        alert.messageText = "Recovery gestures"
        alert.informativeText = """
        If this window is hidden while inputs are locked, hold the pair for \
        3 seconds:

        • Keyboard mode — both Shift keys
        • Trackpad mode — both Option keys
        • Both mode — both Command keys

        Last resort: press Esc, Esc, Return, Return to quit the app.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
