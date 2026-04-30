import SwiftUI

struct OnboardingView: View {
    @State private var step: OnboardingStep = .permissions
    @State private var isPermissionGranted = false
    
    // Settings
    @AppStorage("showInDock") private var showInDock = true
    @AppStorage("showInMenuBar") private var showInMenuBar = false
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("appAppearance") private var appAppearance: AppAppearance = .system
    
    var onComplete: () -> Void
    
    enum OnboardingStep {
        case permissions
        case settings
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if step == .permissions && !AppSetup.shared.checkAccessibilityPermission() {
                permissionsView
            } else {
                settingsView
            }
        }
        .frame(width: 450, height: 550)
        .background(VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow))
        .onAppear {
            checkStatus()
        }
    }
    
    private var permissionsView: some View {
        VStack(spacing: 24) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue.gradient)
                .padding(.top, 40)
            
            VStack(spacing: 8) {
                Text("Accessibility Required")
                    .font(.system(size: 24, weight: .bold))
                
                Text("Chaotic Fingers needs Accessibility permissions to intercept and block system input when requested.")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                if !isPermissionGranted {
                    Button(action: {
                        AppSetup.shared.requestAccessibilityPermission()
                    }) {
                        Text("Grant Permissions in Settings")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 40)
                }
                
                Button(action: {
                    if AppSetup.shared.checkAccessibilityPermission() {
                        step = .settings
                    }
                }) {
                    Text(isPermissionGranted ? "Continue" : "I've granted permissions")
                        .font(.headline)
                        .foregroundStyle(isPermissionGranted ? .primary : .secondary)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40)
            }
        }
    }
    
    private var settingsView: some View {
        VStack(spacing: 24) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue.gradient)
                .padding(.top, 40)
            
            VStack(spacing: 8) {
                Text("App Settings")
                    .font(.system(size: 24, weight: .bold))
                
                Text("Configure how you want to interact with Chaotic Fingers.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 20) {
                Toggle(isOn: $showInDock) {
                    VStack(alignment: .leading) {
                        Text("Show in Dock")
                            .font(.headline)
                        Text("Keep the app icon visible in your Dock.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
                
                Toggle(isOn: $showInMenuBar) {
                    VStack(alignment: .leading) {
                        Text("Show in Menu Bar")
                            .font(.headline)
                        Text("Quick access from the system menu bar.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
                
                Toggle(isOn: $launchAtLogin) {
                    VStack(alignment: .leading) {
                        Text("Launch at Login")
                            .font(.headline)
                        Text("Start Chaotic Fingers automatically when you log in.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
                
                HStack {
                    Text("Appearance")
                        .font(.headline)
                    Spacer()
                    Picker("", selection: $appAppearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.rawValue).tag(appearance)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }
                .padding(.top, 10)
                
                Button(action: {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: Bundle.main.bundlePath)])
                }) {
                    HStack {
                        Image(systemName: "folder.fill")
                        Text("Show App in Finder")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
            .padding(.horizontal, 60)
            .padding(.top, 10)
            
            Spacer()
            
            Button(action: {
                // Apply settings
                AppSetup.shared.setDockIconVisibility(showInDock)
                // Note: MenuBar and LaunchAtLogin will be handled by the App struct observers
                onComplete()
            }) {
                Text("Finish Setup")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
    
    private func checkStatus() {
        Task {
            while true {
                let granted = await AppSetup.shared.checkAccessibilityPermission()
                if granted {
                    isPermissionGranted = true
                    // We don't break here so we can auto-update the UI if they return
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
