import SwiftUI

struct LandingView: View {
    @Environment(InputBlocker.self) private var blocker
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appAppearance") private var appAppearance: AppAppearance = .system
    @State private var selectedMode: InputBlocker.BlockingMode = .keyboard
    var onAction: (InputBlocker.BlockingMode) -> Void

    // Pure SwiftUI background colors – resolved via @Environment(\.colorScheme),
    // NOT via NSColor wrappers which lag behind preferredColorScheme changes.
    private var bgColor: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    private var cardBgColor: Color {
        Color(nsColor: .controlBackgroundColor)
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
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedMode)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: blocker.isBlocking)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Picker("Mode", selection: $selectedMode) {
                    Text("Keyboard").tag(InputBlocker.BlockingMode.keyboard)
                    Text("Trackpad").tag(InputBlocker.BlockingMode.trackpad)
                    Text("Both").tag(InputBlocker.BlockingMode.both)
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
                .disabled(blocker.isBlocking)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(blocker.isBlocking ? "Stop" : "Start") {
                    if blocker.isBlocking {
                        blocker.stopBlocking()
                    } else {
                        onAction(selectedMode)
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .windowToolbarStyle(.unified)
        .frame(minWidth: 420, idealWidth: 480, maxWidth: 800, minHeight: 420, idealHeight: 560, maxHeight: 900)
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
