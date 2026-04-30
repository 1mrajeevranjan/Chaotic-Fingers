import SwiftUI

struct LandingView: View {
    @Environment(InputBlocker.self) private var blocker
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appAppearance") private var appAppearance: AppAppearance = .system
    @State private var selectedMode: InputBlocker.BlockingMode = .keyboard
    @State private var showingSettings = false
    var onAction: (InputBlocker.BlockingMode) -> Void

    // Pure SwiftUI background colors – resolved via @Environment(\.colorScheme),
    // NOT via NSColor wrappers which lag behind preferredColorScheme changes.
    private var bgColor: Color {
        colorScheme == .dark
            ? Color(red: 0.13, green: 0.13, blue: 0.14)   // dark system-like
            : Color(red: 0.94, green: 0.94, blue: 0.96)   // light system-like
    }

    private var cardBgColor: Color {
        colorScheme == .dark
            ? Color(red: 0.18, green: 0.18, blue: 0.20)
            : Color(red: 1.0,  green: 1.0,  blue: 1.0)
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── TOP SECTION ──────────────────────────────────────────────────
            ZStack {
                bgColor

                if let image = backgroundImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .opacity(0.12)
                        .grayscale(1.0)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }

                VStack(spacing: 8) {
                    HStack {
                        Spacer()
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary)
                                .padding(16)
                        }
                        .buttonStyle(.plain)
                    }

                    if let appIcon = NSApp.applicationIconImage {
                        Image(nsImage: appIcon)
                            .resizable()
                            .frame(width: 80, height: 80)
                            .shadow(color: Color.primary.opacity(0.15), radius: 10, x: 0, y: 5)
                            .padding(.top, -10)
                    }

                    VStack(spacing: 2) {
                        Text("Chaotic Fingers")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.primary)

                        Text("Safeguard your inputs when your li'l one is around")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 4)
                }
            }
            .frame(height: 250)

            Divider().opacity(0.5)

            // ── BOTTOM SECTION ───────────────────────────────────────────────
            VStack(spacing: 0) {
                // Mode Tabs
                HStack(spacing: 0) {
                    ModeTabButton(mode: .keyboard, label: "Keyboard",
                                  isSelected: selectedMode == .keyboard,
                                  cardBg: cardBgColor) { selectedMode = .keyboard }
                    Divider().frame(height: 14)
                    ModeTabButton(mode: .trackpad, label: "Trackpad",
                                  isSelected: selectedMode == .trackpad,
                                  cardBg: cardBgColor) { selectedMode = .trackpad }
                    Divider().frame(height: 14)
                    ModeTabButton(mode: .both, label: "Both",
                                  isSelected: selectedMode == .both,
                                  cardBg: cardBgColor) { selectedMode = .both }
                }
                .padding(4)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .disabled(blocker.isBlocking)

                Spacer()

                // Info Card
                HStack(spacing: 16) {
                    Image(systemName: modeIcon)
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.secondary)
                        .frame(width: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(modeTitle)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)
                        Text(modeDescription)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(18)
                .background(cardBgColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: Color.primary.opacity(0.04), radius: 4, x: 0, y: 2)
                .padding(.horizontal, 24)

                Spacer()

                // Action Button
                VStack(spacing: 8) {
                    Button(action: {
                        if blocker.isBlocking {
                            blocker.stopBlocking()
                        } else {
                            onAction(selectedMode)
                        }
                    }) {
                        Text(blocker.isBlocking ? "Stop" : "Start")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(blocker.isBlocking ? Color.red : Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)

                    if blocker.isBlocking {
                        Text(gestureInstruction)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    } else {
                        Color.clear.frame(height: 14)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(bgColor)
        }
        .frame(width: 450, height: 550)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedMode)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: blocker.isBlocking)
        .sheet(isPresented: $showingSettings) {
            RootWrapper(content: OnboardingView(onComplete: {
                showingSettings = false
                if let delegate = NSApp.delegate as? AppDelegate {
                    delegate.applyVisibilitySettings()
                    delegate.applyLoginItemSettings()
                }
            }))
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private var backgroundImage: NSImage? {
        let name: String
        switch selectedMode {
        case .keyboard: name = "keyboard_bg"
        case .trackpad: name = "trackpad_bg"
        case .both:     name = "both_bg"
        case .none:     return nil
        }
        if let path = Bundle.module.path(forResource: name, ofType: "png") {
            return NSImage(contentsOfFile: path)
        }
        return nil
    }

    private var modeIcon: String {
        switch selectedMode {
        case .keyboard: return "keyboard"
        case .trackpad: return "hand.tap"
        case .both:     return "plus.square.on.square"
        case .none:     return ""
        }
    }

    private var modeTitle: String {
        switch selectedMode {
        case .keyboard: return "Secure your keyboard"
        case .trackpad: return "Secure your trackpad"
        case .both:     return "Secure both inputs"
        case .none:     return ""
        }
    }

    private var modeDescription: String {
        let target = selectedMode == .both ? "inputs"
                   : (selectedMode == .keyboard ? "keyboard" : "trackpad")
        return "The app temporarily disables your \(target) until you press the stop button or use the gesture."
    }

    private var gestureInstruction: String {
        switch selectedMode {
        case .keyboard: return "Hold L + R Shift for 3s to stop"
        case .trackpad: return "Hold L + R Option for 3s to stop"
        case .both:     return "Hold L + R Command for 3s to stop"
        case .none:     return ""
        }
    }
}

// ── ModeTabButton ─────────────────────────────────────────────────────────────

struct ModeTabButton: View {
    let mode: InputBlocker.BlockingMode
    let label: String
    let isSelected: Bool
    let cardBg: Color          // passed from parent so it uses the same resolved color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? cardBg : Color.primary.opacity(0.001))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: isSelected ? Color.primary.opacity(0.1) : .clear,
                        radius: 2, x: 0, y: 1)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
