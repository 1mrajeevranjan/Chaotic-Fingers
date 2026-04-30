import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"
    case system = "System Default"
    var id: String { self.rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}
