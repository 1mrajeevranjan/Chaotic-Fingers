import SwiftUI
import ChaoticFingersCore

struct LandingView: View {
    @Environment(InputBlocker.self) private var blocker
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @AppStorage("defaultBlockingMode") private var defaultBlockingMode: BlockingMode = .keyboard
    @State private var selectedMode: BlockingMode = .keyboard
    @State private var hasSeededMode = false

    var onAction: (BlockingMode) -> Void

    /// While blocking, the UI always describes what is actually blocked rather
    /// than whatever the (disabled) picker happens to show.
    private var displayedMode: BlockingMode {
        blocker.isBlocking ? blocker.currentMode : selectedMode
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            controls
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: displayedMode)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: blocker.isBlocking)
        .frame(minWidth: AppTheme.Window.minWidth,
               idealWidth: AppTheme.Window.idealWidth,
               minHeight: AppTheme.Window.minHeight,
               idealHeight: AppTheme.Window.idealHeight)
        .onAppear {
            // Opens on the mode the menu bar click uses, without binding the
            // picker to the setting — a one-off choice here must not silently
            // rewrite the default.
            guard !hasSeededMode else { return }
            hasSeededMode = true
            if !blocker.isBlocking { selectedMode = defaultBlockingMode }
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            // `.windowBackground`, not `.headerView`: the header sits directly
            // under the title bar with no separator, so a darker material would
            // leave a visible step exactly where the hairline used to be.
            if reduceTransparency {
                Color(nsColor: .windowBackgroundColor)
            } else {
                VisualEffectView(material: .windowBackground)
            }

            if let image = Self.backgroundImage(for: displayedMode) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .grayscale(1)
                    .opacity(0.10)
                    .clipped()
                    .accessibilityHidden(true)
            }

            VStack(spacing: AppTheme.Spacing.tiny + 2) {
                if let appIcon = NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 56, height: 56)
                        .shadow(color: .black.opacity(0.16), radius: 6, y: 3)
                        .accessibilityHidden(true)
                }

                Text("Chaotic Fingers")
                    .font(.title3.weight(.semibold))

                Text("Safeguard your inputs when your li'l one is around")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.large)
            }
            .padding(.vertical, AppTheme.Spacing.medium)
        }
        .frame(height: 150)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
            FilledSegmentedPicker(
                options: BlockingMode.selectable.map { ($0, $0.shortTitle) },
                selection: $selectedMode,
                isEnabled: !blocker.isBlocking,
                accessibilityLabel: "Blocking mode"
            )
            .frame(height: 24)

            modeCard

            if blocker.permissionDenied {
                permissionWarning
            } else if blocker.isBlocking {
                StatusOverlayView(mode: blocker.currentMode)
            }

            Spacer(minLength: AppTheme.Spacing.small)

            Button {
                toggleBlocking()
            } label: {
                // The stretch has to happen on the label: applying it to the
                // Button only widens the frame and centres the control in it.
                Text(blocker.isBlocking ? "Stop Blocking" : "Start Blocking")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(blocker.isBlocking ? .red : .accentColor)
            .keyboardShortcut(blocker.isBlocking ? .cancelAction : .defaultAction)
            .accessibilityHint(blocker.isBlocking
                               ? "Re-enables the inputs you locked."
                               : "Locks the selected inputs until you stop or use the recovery gesture.")
        }
        .padding(AppTheme.Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .contextMenu {
            Button(blocker.isBlocking ? "Stop Blocking" : "Start Blocking") {
                toggleBlocking()
            }
            Divider()
            ForEach(BlockingMode.selectable, id: \.rawValue) { mode in
                Button(mode.shortTitle) { selectedMode = mode }
                    .disabled(blocker.isBlocking)
            }
        }
    }

    private func toggleBlocking() {
        if blocker.isBlocking {
            blocker.stopBlocking()
        } else {
            onAction(selectedMode)
        }
    }

    private var modeCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.medium) {
                Image(systemName: modeIcon)
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(.secondary)
                    .frame(width: 34)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(modeTitle)
                        .font(.callout.weight(.semibold))
                    Text(modeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Divider()

            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                effectRow("nosign", blockedSummary, .secondary)
                effectRow("checkmark.circle", passthroughSummary, .green)
                effectRow("hand.raised", unlockSummary, .orange)
            }
        }
        .padding(AppTheme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .boxedPane()
    }

    private func effectRow(_ symbol: String, _ text: String, _ tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.small) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(tint)
                .frame(width: 14)
                .accessibilityHidden(true)
            Text(text)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }

    private var permissionWarning: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.medium) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Accessibility access required")
                    .font(.callout.weight(.semibold))
                Text("macOS blocked the input tap, so nothing was locked. Grant Chaotic Fingers access under Privacy & Security, then try again.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Open System Settings") {
                    AppSetup.shared.requestAccessibilityPermission()
                    blocker.clearPermissionWarning()
                }
                .controlSize(.small)
            }

            Spacer(minLength: 0)
        }
        .padding(AppTheme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.10))
        .boxedPane()
    }

    // MARK: - Copy

    private var modeIcon: String {
        switch displayedMode {
        case .keyboard: return "keyboard"
        case .trackpad: return "hand.tap"
        case .both:     return "lock.shield"
        case .none:     return "questionmark.circle"
        }
    }

    private var modeTitle: String {
        switch displayedMode {
        case .keyboard: return "Secure your keyboard"
        case .trackpad: return "Secure your trackpad"
        case .both:     return "Secure both inputs"
        case .none:     return "Nothing selected"
        }
    }

    private var modeDescription: String {
        switch displayedMode {
        case .keyboard:
            return "Lock the keyboard so keystrokes cannot reach any app."
        case .trackpad:
            return "Lock the trackpad and mouse so the pointer cannot reach any app."
        case .both:
            return "Lock the keyboard and the pointer together — a full input freeze."
        case .none:
            return "Pick a mode to get started."
        }
    }

    private var blockedSummary: String {
        switch displayedMode {
        case .keyboard: return "Key presses are swallowed everywhere."
        case .trackpad: return "Pointer, clicks and scrolling are swallowed."
        case .both:     return "Keys, pointer, clicks and scrolling are swallowed."
        case .none:     return "Nothing is blocked."
        }
    }

    private var passthroughSummary: String {
        switch displayedMode {
        case .keyboard: return "The pointer still works, so this window stays clickable."
        case .trackpad: return "Typing still works, and this window stays clickable."
        case .both:     return "This window stays clickable so you can stop."
        case .none:     return "Everything works."
        }
    }

    private var unlockSummary: String {
        switch displayedMode.releaseGesture {
        case .shiftHold:   return "Hold both Shift keys for 3 seconds to unlock."
        case .optionHold:  return "Hold both Option keys for 3 seconds to unlock."
        case .commandHold: return "Hold both Command keys for 3 seconds to unlock."
        case .forceQuit, .none: return "No recovery gesture needed."
        }
    }

    // MARK: - Resources

    /// Loaded once per mode — `body` re-runs on every hover and animation
    /// frame, and decoding a PNG off disk each time is not free.
    private static var imageCache: [BlockingMode: NSImage] = [:]

    private static func backgroundImage(for mode: BlockingMode) -> NSImage? {
        if let cached = imageCache[mode] { return cached }

        let name: String
        switch mode {
        case .keyboard: name = "keyboard_bg"
        case .trackpad: name = "trackpad_bg"
        case .both:     name = "both_bg"
        case .none:     return nil
        }

        guard let path = Bundle.module.path(forResource: name, ofType: "png"),
              let image = NSImage(contentsOfFile: path) else { return nil }

        imageCache[mode] = image
        return image
    }
}
