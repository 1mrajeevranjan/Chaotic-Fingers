import SwiftUI

/// Layout tokens. Spacing sits on the 8pt grid macOS controls are laid out on;
/// radii follow the native scale (8 for panes and rows, 12 for cards).
enum AppTheme {
    enum Spacing {
        static let tiny: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 20
        static let section: CGFloat = 28
    }

    enum Radius {
        static let chip: CGFloat = 6
        static let pane: CGFloat = 8
        static let card: CGFloat = 12
    }

    /// Window content bounds. The main window is resizable but stays legible.
    enum Window {
        static let minWidth: CGFloat = 420
        static let idealWidth: CGFloat = 480
        static let minHeight: CGFloat = 430
        static let idealHeight: CGFloat = 480
        /// Onboarding carries more content than the dashboard; the window grows
        /// to fit it so neither step has to scroll.
        static let onboardingHeight: CGFloat = 620
    }
}

/// `NSVisualEffectView` bridge. SwiftUI's built-in materials do not expose the
/// window-background vibrancy used by native utility windows.
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .windowBackground
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

/// Native bordered-box pane: hairline separator border, continuous corners.
/// The border thickens under Increase Contrast, where a hairline separator is
/// exactly the thing the setting exists to fix.
struct BoxedPane: ViewModifier {
    let radius: CGFloat
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        contrast == .increased ? Color.primary.opacity(0.55) : Color(nsColor: .separatorColor),
                        lineWidth: contrast == .increased ? 1.5 : 1
                    )
            )
    }
}

/// ScrollView whose content fills the viewport when it fits, so `Spacer`s still
/// distribute — a plain ScrollView gives content unbounded height, collapsing
/// every Spacer and packing everything against the top.
struct FittingScrollView<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
        }
    }
}

extension View {
    func boxedPane(radius: CGFloat = AppTheme.Radius.pane) -> some View {
        modifier(BoxedPane(radius: radius))
    }

    /// SwiftUI only sets the pointing-hand cursor for `Button`/`Link`.
    func pointerOnHover() -> some View {
        onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

/// The canonical settings row: title left, secondary caption beneath it,
/// switch hard right at System Settings scale.
struct SubtitleToggle: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: AppTheme.Spacing.medium)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                // NSSwitch strands its knob mid-transition when isOn flips
                // during the implicit animation; redraw outright instead.
                .animation(nil, value: isOn)
                .accessibilityLabel(title)
        }
    }
}
