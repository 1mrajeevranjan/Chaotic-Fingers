import Foundation

/// Outbound destinations for the More menu.
///
/// Fill one in to enable its menu item. Anything left `nil` still appears in
/// the menu but stays disabled, so the app never ships a link that goes
/// nowhere.
enum AppLinks {
    /// Product page. Also what "Share App" hands to the share sheet.
    static let website: URL? = nil

    /// Frequently asked questions.
    static let faq: URL? = nil

    /// Support contact — a web form, or `mailto:you@example.com`.
    static let support: URL? = nil

    /// App Store listing, e.g. `macappstore://apps.apple.com/app/id123456789`.
    static let rateApp: URL? = nil

    /// Your other apps — a developer page or App Store profile.
    static let moreApps: URL? = nil
}
