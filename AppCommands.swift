// Create app-wide menu commands for Start/Stop Blocking and a Help item.
// These commands interact with the InputBlocker via the AppDelegate reference.

import SwiftUI
import AppKit

private var blocker: InputBlocker { (NSApp.delegate as? AppDelegate)?.blocker ?? InputBlocker() }

struct AppCommands: Commands {
    var body: some Commands {
        CommandMenu("Chaotic Fingers") {
            Button("Start Keyboard Blocking") {
                (NSApp.delegate as? AppDelegate)?.startBlocking(mode: .keyboard)
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
            .disabled(blocker.isBlocking)

            Button("Start Trackpad Blocking") {
                (NSApp.delegate as? AppDelegate)?.startBlocking(mode: .trackpad)
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .disabled(blocker.isBlocking)

            Button("Start Both") {
                (NSApp.delegate as? AppDelegate)?.startBlocking(mode: .both)
            }
            .keyboardShortcut("b", modifiers: [.command, .shift])
            .disabled(blocker.isBlocking)

            Divider()

            Button("Stop Blocking") {
                (NSApp.delegate as? AppDelegate)?.stopBlocking()
            }
            .keyboardShortcut(".")
            .disabled(!blocker.isBlocking)
        }

        CommandMenu("Help") {
            Link("Chaotic Fingers Help", destination: URL(string: "https://github.com/your-org/chaotic-fingers#readme")!)
        }
    }
}

