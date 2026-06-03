import SwiftUI
import AppKit
import ServiceManagement
import ApplicationServices

@main
struct ChaoticFingersApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
        .commands {
            AppCommands()
            CommandGroup(replacing: .appInfo) {
                Button("About Chaotic Fingers") {
                    NSApp.orderFrontStandardAboutPanel(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }
}

struct RootWrapper<Content: View>: View {
    @AppStorage("appAppearance") private var appAppearance: AppAppearance = .system
    let content: Content
    
    var body: some View {
        content
            .preferredColorScheme(appAppearance.colorScheme)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var blocker = InputBlocker()
    var mainWindow: NSWindow?
    var statusItem: NSStatusItem?
    
    // Persistent Settings
    @AppStorage("showInDock") private var showInDock = true
    @AppStorage("showInMenuBar") private var showInMenuBar = false
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("appAppearance") private var appAppearance: AppAppearance = .system
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup blocker callbacks
        blocker.onDeactivate = { [weak self] in
            self?.showMainWindow()
            self?.mainWindow?.level = .normal
        }
        
        applyVisibilitySettings()
        applyLoginItemSettings()
        applyAppearanceSettings()
        showMainWindow()
        
        // Initial setup check
        if !isAccessibilityGranted(promptIfNeeded: false) {
            showOnboarding()
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applyVisibilitySettings() {
        if showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
        
        if showInMenuBar {
            setupStatusItem()
        } else {
            statusItem = nil
        }
    }
    
    func applyLoginItemSettings() {
        let service = SMAppService.mainApp
        do {
            if launchAtLogin {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
        } catch {
            print("Failed to update login item status: \(error)")
        }
    }
    
    func applyAppearanceSettings() {
        switch appAppearance {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system:
            NSApp.appearance = nil
        }
    }
    
    private func setupStatusItem() {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = statusItem?.button {
                button.image = NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: "Chaotic Fingers")
                button.action = #selector(statusItemClicked)
                button.target = self
            }
            
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Show Chaotic Fingers", action: #selector(showMainWindow), keyEquivalent: "s"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusItem?.menu = menu
        }
    }
    
    @objc func statusItemClicked() {
        showMainWindow()
    }
    
    @objc func showMainWindow() {
        if mainWindow == nil {
            let view = RootWrapper(content: LandingView(onAction: { [weak self] mode in
                self?.startBlocking(mode: mode)
            }).environment(blocker))
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 550),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Chaotic Fingers"
            window.center()
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: view)
            mainWindow = window
        }
        
        applyAppearanceSettings() // Refresh window appearance
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }
    
    func showOnboarding() {
        let view = RootWrapper(content: OnboardingView(onComplete: { [weak self] in
            self?.applyVisibilitySettings()
            self?.applyLoginItemSettings()
            self?.applyAppearanceSettings()
            
            self?.mainWindow?.contentView = NSHostingView(rootView: LandingView(onAction: { mode in
                self?.startBlocking(mode: mode)
            }).environment(self!.blocker))
        }))
        
        mainWindow?.contentView = NSHostingView(rootView: view)
    }
    
    func startBlocking(mode: InputBlocker.BlockingMode) {
        blocker.startBlocking(mode)
        mainWindow?.level = .floating
    }
    
    func stopBlocking() {
        blocker.stopBlocking()
        mainWindow?.level = .normal
    }
    
    private func isAccessibilityGranted(promptIfNeeded: Bool) -> Bool {
        if AXIsProcessTrusted() { return true }
        if promptIfNeeded {
            let key = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
            let options: CFDictionary = [key: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        return AXIsProcessTrusted()
    }
}
