import SwiftUI
import ChaoticFingersCore

struct SettingsView: View {
    @AppStorage("showInDock") private var showInDock = true
    @AppStorage("showInMenuBar") private var showInMenuBar = false
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("appAppearance") private var appAppearance: AppAppearance = .system
    @AppStorage("defaultBlockingMode") private var defaultBlockingMode: BlockingMode = .keyboard

    private var delegate: AppDelegate? { AppDelegate.shared }

    // Hand-built sections rather than `Form(.formStyle: .grouped)`: a grouped
    // Form wraps itself in a ScrollView with no definite ideal height, so the
    // Settings window cannot size itself to the content and always shows a
    // scrollbar. A plain VStack has a real intrinsic height.
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
            SettingsSection("Menu Bar") {
                Text("Default mode").font(.callout)

                FilledSegmentedPicker(
                    options: BlockingMode.selectable.map { ($0, $0.shortTitle) },
                    selection: $defaultBlockingMode,
                    accessibilityLabel: "Default mode"
                )
                .frame(height: 24)

                Divider()

                Text("One click on the menu bar icon starts and stops this mode. Right-click or two-finger tap it for Dashboard, Settings, More and Quit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SettingsSection("Appearance") {
                FilledSegmentedPicker(
                    options: AppAppearance.allCases.map { ($0, $0.rawValue) },
                    selection: $appAppearance,
                    accessibilityLabel: "Appearance"
                )
                .frame(height: 24)
            }

            SettingsSection("Visibility") {
                SubtitleToggle(title: "Show in Dock",
                               subtitle: "Keep the app icon visible in your Dock.",
                               isOn: $showInDock)
                Divider()
                SubtitleToggle(title: "Show in Menu Bar",
                               subtitle: "Quick access from the system menu bar.",
                               isOn: $showInMenuBar)
                Divider()
                SubtitleToggle(title: "Launch at Login",
                               subtitle: "Start Chaotic Fingers automatically when you log in.",
                               isOn: $launchAtLogin)
            }

            SettingsSection("Recovery gestures") {
                gestureRow("Keyboard mode", "Hold both Shift keys for 3 seconds")
                Divider()
                gestureRow("Trackpad mode", "Hold both Option keys for 3 seconds")
                Divider()
                gestureRow("Both mode", "Hold both Command keys for 3 seconds")
                Divider()
                gestureRow("Force quit", "Esc, Esc, Return, Return")
            }

            HStack {
                Spacer(minLength: 0)
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting(
                        [URL(fileURLWithPath: Bundle.main.bundlePath)]
                    )
                } label: {
                    Label("Show App in Finder", systemImage: "folder")
                }
                .controlSize(.small)
            }
        }
        .padding(AppTheme.Spacing.large)
        .frame(width: 500)
        .onChange(of: showInDock) { _, isOn in delegate?.applyVisibilitySettings(showInDock: isOn) }
        .onChange(of: showInMenuBar) { _, isOn in delegate?.applyVisibilitySettings(showInMenuBar: isOn) }
        .onChange(of: launchAtLogin) { _, isOn in delegate?.applyLoginItemSettings(isOn) }
        .onChange(of: appAppearance) { _, appearance in delegate?.applyAppearanceSettings(appearance) }
        .onChange(of: defaultBlockingMode) { _, _ in
            // One run loop turn later, so the tooltip reads the committed value.
            DispatchQueue.main.async { delegate?.refreshStatusItem() }
        }
    }

    private func gestureRow(_ title: String, _ shortcut: String) -> some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Text(title).font(.callout)
            Spacer(minLength: AppTheme.Spacing.medium)
            Text(shortcut)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Titled group box matching the shape of a macOS System Settings section.
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            Text(title)
                .font(.callout.weight(.semibold))

            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                content
            }
            .padding(AppTheme.Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .boxedPane()
        }
    }
}
