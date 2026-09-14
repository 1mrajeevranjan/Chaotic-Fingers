import SwiftUI

struct OnboardingView: View {
    private enum Step {
        case permissions
        case settings
    }

    @State private var step: Step = .permissions
    @State private var isPermissionGranted = AppSetup.shared.checkAccessibilityPermission()

    @AppStorage("showInDock") private var showInDock = true
    @AppStorage("showInMenuBar") private var showInMenuBar = false
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("appAppearance") private var appAppearance: AppAppearance = .system

    var onComplete: () -> Void

    var body: some View {
        // Scrolls when the step is taller than the window, fills the viewport
        // when it is not — a plain ScrollView would strand every Spacer.
        FittingScrollView {
            switch step {
            case .permissions: permissionsStep
            case .settings:    settingsStep
            }
        }
        .frame(minWidth: AppTheme.Window.minWidth,
               idealWidth: AppTheme.Window.idealWidth,
               minHeight: AppTheme.Window.minHeight,
               idealHeight: AppTheme.Window.idealHeight)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            // Cancels with the view. The old version spun an uncancellable
            // `while true` loop that outlived onboarding entirely.
            while !Task.isCancelled {
                isPermissionGranted = AppSetup.shared.checkAccessibilityPermission()
                if isPermissionGranted && step == .permissions {
                    step = .settings
                    return
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    // MARK: - Step 1

    private var permissionsStep: some View {
        VStack(spacing: AppTheme.Spacing.section) {
            stepHeader(
                symbol: "hand.raised.fill",
                title: "Accessibility access",
                subtitle: "Chaotic Fingers needs Accessibility permission to intercept keyboard and trackpad events. Nothing is recorded or sent anywhere."
            )

            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                instructionRow(number: 1, text: "Open Privacy & Security ▸ Accessibility in System Settings.")
                instructionRow(number: 2, text: "Turn on the switch next to Chaotic Fingers.")
                instructionRow(number: 3, text: "Come back here — this screen advances on its own.")
            }
            .padding(AppTheme.Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .boxedPane()
            .padding(.horizontal, AppTheme.Spacing.section)

            Spacer(minLength: 0)

            VStack(spacing: AppTheme.Spacing.medium) {
                Button("Open System Settings") {
                    AppSetup.shared.requestAccessibilityPermission()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)

                Label(
                    isPermissionGranted ? "Access granted" : "Waiting for access…",
                    systemImage: isPermissionGranted ? "checkmark.circle.fill" : "clock"
                )
                .font(.caption)
                .foregroundStyle(isPermissionGranted ? Color.green : .secondary)

                Button("Continue without blocking") { step = .settings }
                    .buttonStyle(.link)
                    .controlSize(.small)
            }
            .padding(.bottom, AppTheme.Spacing.section)
        }
        .padding(.top, AppTheme.Spacing.section)
    }

    // MARK: - Step 2

    private var settingsStep: some View {
        VStack(spacing: AppTheme.Spacing.section) {
            stepHeader(
                symbol: "gearshape.fill",
                title: "How should it show up?",
                subtitle: "All of this can be changed later in Settings."
            )

            VStack(spacing: AppTheme.Spacing.large) {
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
                Divider()
                HStack(spacing: AppTheme.Spacing.medium) {
                    Text("Appearance").font(.callout)
                    Spacer(minLength: AppTheme.Spacing.medium)
                    Picker("Appearance", selection: $appAppearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.rawValue).tag(appearance)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.small)
                    .frame(width: 150)
                    .accessibilityLabel("Appearance")
                }
            }
            .padding(AppTheme.Spacing.large)
            .background(Color(nsColor: .controlBackgroundColor))
            .boxedPane()
            .padding(.horizontal, AppTheme.Spacing.section)

            Spacer(minLength: 0)

            Button("Finish Setup", action: onComplete)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .padding(.bottom, AppTheme.Spacing.section)
        }
        .padding(.top, AppTheme.Spacing.section)
    }

    // MARK: - Pieces

    private func stepHeader(symbol: String, title: String, subtitle: String) -> some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            Image(systemName: symbol)
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text(title)
                .font(.title2.weight(.semibold))

            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, AppTheme.Spacing.section)
        }
    }

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.medium) {
            Text("\(number)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .background(Color(nsColor: .separatorColor).opacity(0.5), in: Circle())

            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number). \(text)")
    }
}
