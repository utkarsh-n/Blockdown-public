import SwiftUI

extension Color {
    /// App accent: red in light mode, aqua in dark mode.
    ///
    /// Defined in SharedAssets.xcassets (included in both the app and the
    /// widget extension) rather than as a programmatic dynamic UIColor —
    /// WidgetKit archives views for rendering, and asset-catalog colors are
    /// the only dynamic colors that survive that round trip.
    static let blockdownTheme = Color("BlockdownTheme")
}
