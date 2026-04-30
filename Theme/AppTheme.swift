import SwiftUI

enum AppTheme {
    enum Colors {
        static let background = Color.primary.opacity(0.03)
        
        static let keyboardGradient = Gradient(colors: [Color(hex: "5CA4F0"), Color(hex: "8D7CF6")])
        static let trackpadGradient = Gradient(colors: [Color(hex: "FF8585"), Color(hex: "FFF08A")])
        static let bothGradient = Gradient(colors: [Color(hex: "4CCB85"), Color(hex: "2DD4BF")])
        
        static let activeGradient = Gradient(colors: [Color(hex: "FF5F6D"), Color(hex: "FF3131")]) // Red
        static let inactiveGradient = Gradient(colors: [Color(hex: "11998E"), Color(hex: "38EF7D")]) // Green
        
        static func accentColor(for mode: String) -> Color {
            switch mode {
            case "keyboard": return Color(hex: "5CA4F0")
            case "trackpad": return Color(hex: "FF8585")
            case "both": return Color(hex: "4CCB85")
            default: return .primary
            }
        }
    }
    
    enum Spacing {
        static let tiny: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }
    
    enum Radius {
        static let card: CGFloat = 16
        static let inner: CGFloat = 10
        static let button: CGFloat = 22
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
