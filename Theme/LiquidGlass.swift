import SwiftUI

struct PhotorealisticGlass: ViewModifier {
    var radius: CGFloat
    var padding: CGFloat
    
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.2 : 0.5),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 10, x: 0, y: 5)
    }
}

extension View {
    func liquidGlass(radius: CGFloat = AppTheme.Radius.card, padding: CGFloat = AppTheme.Spacing.medium) -> some View {
        // In macOS 26, we use the native glassEffect if available, otherwise fallback to our custom photorealistic glass
        if #available(macOS 26.0, *) {
            return self
                .padding(padding)
                .glassEffect(.regular, in: .rect(cornerRadius: radius))
        } else {
            return self.modifier(PhotorealisticGlass(radius: radius, padding: padding))
        }
    }
}
