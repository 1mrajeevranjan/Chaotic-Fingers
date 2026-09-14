import SwiftUI
import AppKit
import ServiceManagement
import ApplicationServices
import ChaoticFingersCore

@main
struct ChaoticFingersApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // The scene exists only because an App needs one, and because SwiftUI
        // opens it at launch it is parked out of sight immediately. The real
        // settings window is hosted by the delegate: SwiftUI reapplies its own
        // title bar whenever this scene is shown, which clobbered the centred
        // title and the native title bar metrics every time.
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { AppDelegate.shared?.openSettings() }
                    .keyboardShortcut(",", modifiers: .command)
            }
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
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    /// `NSApp.delegate as? AppDelegate` returns nil under
    /// `@NSApplicationDelegateAdaptor` — SwiftUI does not leave our instance
    /// there — so every view and command that looked the delegate up that way
    /// silently did nothing. Hold an explicit reference instead.
    private(set) static var shared: AppDelegate?

    let blocker = InputBlocker()
    var mainWindow: NSWindow?
    private var statusItem: NSStatusItem?

    enum DefaultsKey {
        static let showInDock = "showInDock"
        static let showInMenuBar = "showInMenuBar"
        static let launchAtLogin = "launchAtLogin"
        static let appAppearance = "appAppearance"
        static let defaultBlockingMode = "defaultBlockingMode"

        static let registered: [String: Any] = [
            showInDock: true,
            showInMenuBar: false,
            launchAtLogin: false,
            appAppearance: AppAppearance.system.rawValue,
            defaultBlockingMode: BlockingMode.keyboard.rawValue
        ]
    }

    // Read straight from the store. `@AppStorage` is a DynamicProperty: outside
    // a SwiftUI view nothing drives its updates, so it can hand back the value
    // it was initialised with long after the store has moved on.
    private var showInDock: Bool { UserDefaults.standard.bool(forKey: DefaultsKey.showInDock) }
    private var showInMenuBar: Bool { UserDefaults.standard.bool(forKey: DefaultsKey.showInMenuBar) }
    private var launchAtLogin: Bool { UserDefaults.standard.bool(forKey: DefaultsKey.launchAtLogin) }

    private var appAppearance: AppAppearance {
        AppAppearance(rawValue: UserDefaults.standard.string(forKey: DefaultsKey.appAppearance) ?? "") ?? .system
    }

    private var defaultBlockingMode: BlockingMode {
        BlockingMode(rawValue: UserDefaults.standard.string(forKey: DefaultsKey.defaultBlockingMode) ?? "") ?? .keyboard
    }

    static let appName = "Chaotic Fingers"

    private var warningReset: DispatchWorkItem?
    private var mouseMonitor: Any?
    /// Set from the mouse-down that precedes the button's mouse-up action.
    private var lastClickWasSecondary = false
    private var hasPromptedForAccessibility = false

    /// SwiftUI's settings window, parked out of sight at launch.
    private var settingsWindow: NSWindow?

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: DefaultsKey.registered)

        blocker.onDeactivate = { [weak self] reason in
            guard let self else { return }
            self.mainWindow?.level = .normal
            self.refreshStatusItem()

            // A gesture unlock can happen with every window hidden. Surface the
            // dashboard only when there is no menu bar icon to report it —
            // otherwise the filled-to-hollow hand is feedback enough, and an
            // unlock from the icon itself should open nothing at all.
            if reason == .gesture && self.statusItem == nil {
                self.showMainWindow()
            }
        }

        applyVisibilitySettings()
        applyLoginItemSettings()
        applyAppearanceSettings()
        showMainWindow()

        if !AXIsProcessTrusted() {
            showOnboarding()
        }

        captureSettingsWindow()
    }

    /// Closing the window must not quit the app when the menu bar item is the
    /// only remaining way back in.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !showInMenuBar
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let toggle = NSMenuItem(
            title: blocker.isBlocking ? "Stop Blocking" : "Start Blocking (\(defaultBlockingMode.shortTitle))",
            action: #selector(toggleFromDock),
            keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)

        let dashboard = NSMenuItem(title: "Dashboard", action: #selector(showMainWindow), keyEquivalent: "")
        dashboard.target = self
        menu.addItem(dashboard)
        return menu
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Leaving a tap installed would keep input dead after the app is gone.
        // Drop the callback first so teardown does not re-open the window on
        // the way out.
        blocker.onDeactivate = nil
        blocker.stopBlocking()
    }

    @objc private func toggleFromDock() {
        toggleBlocking()
    }

    /// `Settings` is the only SwiftUI scene in the App body, so SwiftUI opens
    /// it at launch on top of the real window. Park it out of sight instead of
    /// closing it — a closed scene window leaves `showSettingsWindow:` with
    /// nothing to reopen, which made "Settings…" fall through to merely
    /// activating the app and surfacing the dashboard instead.
    private func captureSettingsWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            for window in NSApp.windows where self.isStraySettingsScene(window) {
                window.orderOut(nil)
            }
        }
    }

    private func isStraySettingsScene(_ window: NSWindow) -> Bool {
        window !== mainWindow
            && window !== settingsWindow
            && window.identifier?.rawValue == "com_apple_SwiftUI_Settings_window"
    }

    // MARK: - Settings application

    /// SwiftUI fires `onChange` before `@AppStorage` commits, so callers pass
    /// the new value explicitly; omitting it falls back to the stored value.
    func applyVisibilitySettings(showInDock dock: Bool? = nil, showInMenuBar menuBar: Bool? = nil) {
        NSApp.setActivationPolicy((dock ?? showInDock) ? .regular : .accessory)

        if menuBar ?? showInMenuBar {
            setupStatusItem()
        } else {
            removeStatusItem()
        }
    }

    func applyLoginItemSettings(_ enabled: Bool? = nil) {
        let launchAtLogin = enabled ?? self.launchAtLogin
        let service = SMAppService.mainApp
        do {
            if launchAtLogin, service.status != .enabled {
                try service.register()
            } else if !launchAtLogin, service.status == .enabled {
                try service.unregister()
            }
        } catch {
            NSLog("Failed to update login item status: \(error.localizedDescription)")
        }
    }

    func applyAppearanceSettings(_ appearance: AppAppearance? = nil) {
        let target: NSAppearance?
        switch appearance ?? appAppearance {
        case .light:  target = NSAppearance(named: .aqua)
        case .dark:   target = NSAppearance(named: .darkAqua)
        case .system: target = nil
        }

        NSApp.appearance = target
        // `preferredColorScheme` does not reach a bare NSHostingView, so each
        // window has to be told directly or the dashboard keeps the old theme.
        for window in NSApp.windows {
            window.appearance = target
        }
    }

    // MARK: - Menu bar item

    private func setupStatusItem() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            // A menu assigned to the status item swallows the button action
            // outright, so the menu is popped up by hand on a double click.
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        // The button action fires on mouse-up, where neither
        // `NSApp.currentEvent` (nil in some dispatches) nor
        // `NSEvent.pressedMouseButtons` (already released) can say which button
        // was used. The preceding mouse-down can, so record it here. A left
        // mouse-down always clears the flag, so a secondary click elsewhere in
        // the app cannot leak into the next click on the icon.
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.lastClickWasSecondary = event.type == .rightMouseDown
                || event.modifierFlags.contains(.control)
            return event
        }

        statusItem = item
        refreshStatusItem()
    }

    private func removeStatusItem() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
    }

    /// Repaints the icon and tooltip for the current blocking state. Safe to
    /// call when the menu bar item is switched off.
    func refreshStatusItem() {
        guard let button = statusItem?.button else { return }

        let blocking = blocker.isBlocking
        // Hollow hand while inputs are live, solid once they are locked.
        let symbol = blocking ? "hand.raised.fill" : "hand.raised"
        let description = blocking
            ? "\(Self.appName) — \(blocker.currentMode.title) locked"
            : "\(Self.appName) — inputs active"

        warningReset?.cancel()
        warningReset = nil
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
        button.toolTip = blocking
            ? "\(blocker.currentMode.title) locked. Click to unlock, right-click for more."
            : "Click to lock \(defaultBlockingMode.title). Right-click for more."
    }

    @objc private func statusItemClicked() {
        if isSecondaryClick() {
            showStatusMenu()
        } else {
            toggleFromStatusItem()
        }
    }

    /// Right click, two-finger tap and Control-click all open the menu.
    private func isSecondaryClick() -> Bool {
        if let event = NSApp.currentEvent {
            switch event.type {
            case .rightMouseDown, .rightMouseUp:
                return true
            case .leftMouseDown, .leftMouseUp:
                return event.modifierFlags.contains(.control)
            default:
                break
            }
        }
        return lastClickWasSecondary
    }

    private func toggleFromStatusItem() {
        toggleBlocking()
    }

    private func toggleBlocking() {
        guard !blocker.isBlocking else {
            stopBlocking()
            return
        }

        startBlocking(mode: defaultBlockingMode)

        // Nothing was locked, so the icon correctly stays hollow. Report it in
        // the menu bar instead of opening the dashboard — a click on a toggle
        // should never turn into a window.
        if blocker.permissionDenied {
            signalMissingAccessibility()
        }
    }

    /// Flags a failed lock without stealing focus: prompt once per launch (macOS
    /// shows its dialog at most once anyway), then flash the icon so a later
    /// click still visibly reports that nothing happened.
    private func signalMissingAccessibility() {
        if !hasPromptedForAccessibility {
            hasPromptedForAccessibility = true
            AppSetup.shared.promptForAccessibility()
        }

        guard let button = statusItem?.button else { return }

        warningReset?.cancel()
        button.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill",
                               accessibilityDescription: "\(Self.appName) — Accessibility access required")
        button.toolTip = "\(Self.appName) needs Accessibility access before it can lock anything."

        let reset = DispatchWorkItem { [weak self] in self?.refreshStatusItem() }
        warningReset = reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: reset)
    }

    private func showStatusMenu() {
        guard let item = statusItem, let button = item.button else { return }
        // Rebuilt on every open so checkmarks and Stop track the live state.
        item.menu = makeStatusMenu()
        button.performClick(nil)
        item.menu = nil
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(menuItem("Dashboard", #selector(showMainWindow), symbol: "macwindow"))

        let settings = menuItem("Settings…", #selector(openSettings), symbol: "gearshape")
        settings.keyEquivalent = ","
        settings.keyEquivalentModifierMask = .command
        menu.addItem(settings)

        let more = NSMenuItem(title: "More", action: nil, keyEquivalent: "")
        more.image = Self.menuSymbol("ellipsis.circle")
        more.submenu = makeMoreMenu()
        menu.addItem(more)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit \(Self.appName)",
                              action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        quit.image = Self.menuSymbol("power")
        menu.addItem(quit)
        return menu
    }

    private func makeMoreMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(menuItem("About", #selector(showAbout), symbol: "info.circle"))
        menu.addItem(linkItem("Support & Feedback", AppLinks.support, symbol: "envelope"))

        menu.addItem(.separator())

        menu.addItem(menuItem("Tips", #selector(showTips), symbol: "lightbulb"))
        menu.addItem(linkItem("FAQ", AppLinks.faq, symbol: "questionmark.circle"))
        menu.addItem(linkItem("Website", AppLinks.website, symbol: "globe"))

        menu.addItem(.separator())

        menu.addItem(linkItem("Rate App", AppLinks.rateApp, symbol: "star"))
        menu.addItem(menuItem("Share App", #selector(shareApp), symbol: "square.and.arrow.up"))
        menu.addItem(linkItem("More Apps by Me", AppLinks.moreApps, symbol: "square.grid.2x2"))

        return menu
    }

    /// Opens `url`, or shows the item greyed out when it has not been set.
    private func linkItem(_ title: String, _ url: URL?, symbol: String) -> NSMenuItem {
        let item = menuItem(title, #selector(openLink(_:)), symbol: symbol)
        item.representedObject = url
        if url == nil {
            item.isEnabled = false
            item.toolTip = "Set this URL in Utilities/AppLinks.swift"
        }
        return item
    }

    private func menuItem(_ title: String, _ action: Selector, symbol: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = Self.menuSymbol(symbol)
        return item
    }

    /// Menu-sized template symbol, so it tints with the highlight like the
    /// icons in the system's own menus.
    private static func menuSymbol(_ name: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else { return nil }
        image.isTemplate = true
        return image
    }

    // MARK: - Menu actions

    @objc func openSettings() {
        NSApp.activate(ignoringOtherApps: true)

        if settingsWindow == nil {
            let hosting = NSHostingView(rootView: RootWrapper(content: SettingsView()))

            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            installCenteredTitle("Settings", in: window)
            window.isReleasedWhenClosed = false
            window.contentView = hosting

            window.setContentSize(hosting.fittingSize)
            window.center()
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func openLink(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func showTips() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Tips"
        alert.informativeText = """
        • One click on the menu bar icon locks and unlocks your default mode.         Change that mode in Settings.
        • Right-click or two-finger tap the icon for Dashboard, Settings, More and Quit.
        • The dashboard window stays clickable while inputs are locked, so         Stop is always reachable.

        If the window is hidden, hold the pair for 3 seconds to unlock:
        • Keyboard mode — both Shift keys
        • Trackpad mode — both Option keys
        • Both mode — both Command keys

        Last resort: press Esc, Esc, Return, Return to quit the app.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func shareApp() {
        guard let button = statusItem?.button else { return }
        let item: Any = AppLinks.website
            ?? "\(Self.appName) — lock your Mac's keyboard and trackpad so small hands cannot cause chaos."
        let picker = NSSharingServicePicker(items: [item])
        picker.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Title bar

    /// Centres the window title and merges the bar into the content.
    ///
    /// The current macOS chrome left-aligns a plain titled window's title beside
    /// the traffic lights and AppKit exposes no alignment control, so the real
    /// title is hidden and a centred label is placed in the title bar instead.
    /// `titlebarSeparatorStyle = .none` alone still leaves the hairline —
    /// making the bar transparent is what actually removes it.
    private func installCenteredTitle(_ title: String, in window: NSWindow) {
        window.title = title
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none

        guard let titlebar = window.standardWindowButton(.closeButton)?.superview else { return }

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        label.textColor = .labelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        titlebar.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: titlebar.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: titlebar.centerYAnchor)
        ])
    }

    // MARK: - Windows

    @objc func showMainWindow() {
        if mainWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0,
                                    width: AppTheme.Window.idealWidth,
                                    height: AppTheme.Window.idealHeight),
                // Not `.resizable`: the layout is a fixed-size panel, and the
                // green button zooms by resizing, so locking the size is what
                // actually disables it rather than just greying the button.
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            installCenteredTitle(Self.appName, in: window)

            window.minSize = NSSize(width: AppTheme.Window.minWidth,
                                    height: AppTheme.Window.minHeight)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: landingRoot)

            // Zoom and full screen do nothing useful for a fixed-size panel.
            // The button stays visible — hiding a traffic light is worse — but
            // inert.
            window.collectionBehavior.insert(.fullScreenNone)
            window.standardWindowButton(.zoomButton)?.isEnabled = false
            window.delegate = self

            // Autosave first: restoring a saved frame overwrites the size, so
            // the content size has to be forced afterwards or a frame saved at
            // some other size locks the window at it.
            window.setFrameAutosaveName("DashboardWindow2")
            window.setContentSize(NSSize(width: AppTheme.Window.idealWidth,
                                         height: AppTheme.Window.idealHeight))
            if window.frame.origin == .zero { window.center() }
            mainWindow = window
        }

        applyAppearanceSettings()
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    private var landingRoot: some View {
        RootWrapper(
            content: LandingView(onAction: { [weak self] mode in
                self?.startBlocking(mode: mode)
            })
            .environment(blocker)
        )
    }

    func showOnboarding() {
        let view = RootWrapper(content: OnboardingView(onComplete: { [weak self] in
            guard let self else { return }
            self.applyVisibilitySettings()
            self.applyLoginItemSettings()
            self.applyAppearanceSettings()
            self.mainWindow?.contentView = NSHostingView(rootView: self.landingRoot)
            self.setMainWindowContentHeight(AppTheme.Window.idealHeight)
        }))

        mainWindow?.contentView = NSHostingView(rootView: view)
        setMainWindowContentHeight(AppTheme.Window.onboardingHeight)
    }

    /// Resizes from the bottom edge so the title bar stays put.
    private func setMainWindowContentHeight(_ height: CGFloat) {
        guard let window = mainWindow else { return }

        let content = NSRect(x: 0, y: 0, width: window.contentLayoutRect.width, height: height)
        let target = window.frameRect(forContentRect: content)

        var frame = window.frame
        frame.origin.y += frame.height - target.height
        frame.size.height = target.height
        window.setFrame(frame, display: true)
    }

    // MARK: - NSWindowDelegate

    /// Blocks zoom from every route. Disabling the green button only covers
    /// clicks on it — a double-click on the title bar and Window ▸ Zoom both
    /// still zoom the window otherwise.
    func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
        false
    }

    // MARK: - Blocking

    func startBlocking(mode: BlockingMode) {
        blocker.startBlocking(mode)
        // Keep the only route back on top of whatever is in front.
        mainWindow?.level = blocker.isBlocking ? .floating : .normal
        refreshStatusItem()
    }

    @objc func stopBlockingAction() {
        stopBlocking()
    }

    func stopBlocking() {
        blocker.stopBlocking()
        mainWindow?.level = .normal
        refreshStatusItem()
    }
}
