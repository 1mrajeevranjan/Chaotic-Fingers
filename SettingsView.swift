import SwiftUI

struct SettingsView: View {
    @AppStorage("showInDock") private var showInDock = true
    @AppStorage("showInMenuBar") private var showInMenuBar = false
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("appAppearance") private var appAppearance: AppAppearance = .system

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Appearance", selection: $appAppearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.rawValue).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Visibility") {
                Toggle("Show in Dock", isOn: $showInDock)
                Toggle("Show in Menu Bar", isOn: $showInMenuBar)
                Toggle("Launch at Login", isOn: $launchAtLogin)
            }

            Section("About") {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: Bundle.main.bundlePath)])
                } label: {
                    Label("Show App in Finder", systemImage: "folder")
                }
                .buttonStyle(.borderless)
            }
        }
        .onChange(of: showInDock) { _ in
            (NSApp.delegate as? AppDelegate)?.applyVisibilitySettings()
        }
        .onChange(of: showInMenuBar) { _ in
            (NSApp.delegate as? AppDelegate)?.applyVisibilitySettings()
        }
        .onChange(of: launchAtLogin) { _ in
            (NSApp.delegate as? AppDelegate)?.applyLoginItemSettings()
        }
        .onChange(of: appAppearance) { _ in
            (NSApp.delegate as? AppDelegate)?.applyAppearanceSettings()
        }
        .padding(16)
        .frame(minWidth: 420, idealWidth: 480)
    }
}

#Preview {
    SettingsView()
}
