import SwiftUI

struct StatusOverlayView: View {
    let mode: InputBlocker.BlockingMode
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Image(systemName: iconName)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Text(instruction)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                }
        }
        .shadow(radius: 10)
    }
    
    private var iconName: String {
        switch mode {
        case .keyboard: return "keyboard"
        case .trackpad: return "rectangle.and.hand.point.up.left"
        case .both: return "lock.shield"
        case .none: return "checkmark.circle"
        }
    }
    
    private var title: String {
        switch mode {
        case .keyboard: return "Keyboard Disabled"
        case .trackpad: return "Trackpad Disabled"
        case .both: return "All Input Disabled"
        case .none: return "Input Re-enabled"
        }
    }
    
    private var instruction: String {
        switch mode {
        case .keyboard: return "Double-tap Space + hold 3s to restore"
        case .trackpad: return "Double-click mouse + hold 3s to restore"
        case .both: return "Triple-press ESC to restore"
        case .none: return "System ready"
        }
    }
}
