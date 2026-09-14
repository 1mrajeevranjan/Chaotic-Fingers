import SwiftUI
import ChaoticFingersCore

/// Live blocking status. Both the title and the escape-hatch instruction are
/// derived from `BlockingMode` so the copy cannot drift from what the gesture
/// detector actually accepts.
struct StatusOverlayView: View {
    let mode: BlockingMode

    var body: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            Image(systemName: iconName)
                .font(.callout)
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            Text(title)
                .font(.callout.weight(.semibold))

            Text(instruction)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.Spacing.medium)
        .padding(.vertical, AppTheme.Spacing.small)
        .background(tint.opacity(0.10))
        .boxedPane(radius: AppTheme.Radius.chip)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(instruction)")
    }

    private var tint: Color {
        mode == .none ? .green : .orange
    }

    private var iconName: String {
        switch mode {
        case .keyboard: return "keyboard"
        case .trackpad: return "rectangle.and.hand.point.up.left"
        case .both:     return "lock.shield"
        case .none:     return "checkmark.circle"
        }
    }

    private var title: String {
        switch mode {
        case .keyboard: return "Keyboard locked"
        case .trackpad: return "Trackpad locked"
        case .both:     return "Keyboard and trackpad locked"
        case .none:     return "Inputs active"
        }
    }

    private var instruction: String {
        switch mode.releaseGesture {
        case .shiftHold:   return "Hold both Shift keys for 3s"
        case .optionHold:  return "Hold both Option keys for 3s"
        case .commandHold: return "Hold both Command keys for 3s"
        case .forceQuit, .none: return "Nothing is blocked"
        }
    }
}
