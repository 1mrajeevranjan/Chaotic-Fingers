import Foundation
import AppKit

@MainActor
class AppSetup {
    static let shared = AppSetup()
    
    // MARK: - Accessibility Permissions
    
    func checkAccessibilityPermission() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    func requestAccessibilityPermission() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - Dock Icon Toggle
    
    func setDockIconVisibility(_ visible: Bool) {
        if visible {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    // MARK: - Move to Applications
    
    func moveToApplicationsIfNeeded() {
        let bundlePath = Bundle.main.bundlePath
        
        if bundlePath.hasPrefix("/Applications") || bundlePath.hasPrefix("/Users/\(NSUserName())/Applications") {
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Move to Applications?"
        alert.informativeText = "Chaotic Fingers works best when installed in your Applications folder."
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Stay here")
        
        if alert.runModal() == .alertFirstButtonReturn {
            let fileManager = FileManager.default
            let targetURL = URL(fileURLWithPath: "/Applications").appendingPathComponent(URL(fileURLWithPath: bundlePath).lastPathComponent)
            
            do {
                if fileManager.fileExists(atPath: targetURL.path) {
                    try fileManager.removeItem(at: targetURL)
                }
                try fileManager.copyItem(at: URL(fileURLWithPath: bundlePath), to: targetURL)
                
                let configuration = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.openApplication(at: targetURL, configuration: configuration) { _, error in
                    if error == nil {
                        Task { @MainActor in
                            NSApplication.shared.terminate(nil)
                        }
                    }
                }
            } catch {
                print("Failed to move to Applications: \(error)")
            }
        }
    }
}
