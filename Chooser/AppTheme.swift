import SwiftUI

// MARK: - App Theme
// One theme per accent color. Drives full-screen game view backgrounds
// and the spinning wheel center color. Accessed via the appTheme environment key.

struct AppTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let primary: Color
    let paletteColors: [Color]
    let backgroundColors: [Color]

    var gradient: LinearGradient {
        LinearGradient(
            colors: paletteColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Solid near-black background for all full-screen game views.
    /// No gradient — ensures consistent, readable contrast everywhere.
    var backgroundGradient: LinearGradient {
        let bg = Color(hex: "0E0E10")
        return LinearGradient(colors: [bg, bg], startPoint: .top, endPoint: .bottom)
    }

    var buttonGradient: LinearGradient {
        let c1 = paletteColors.count >= 2 ? paletteColors[paletteColors.count - 2] : primary
        let c2 = paletteColors.last ?? primary.opacity(0.75)
        return LinearGradient(colors: [c1, c2], startPoint: .leading, endPoint: .trailing)
    }

    // MARK: - Catalog (one per AppAccentColor)

    static let all: [AppTheme] = [coral, blue, violet, green, orange, rose]

    static func theme(for id: String) -> AppTheme {
        all.first { $0.id == id } ?? .coral
    }

    static let coral = AppTheme(
        id: "coral",
        name: "Coral",
        primary: Color(hex: "FF6B6B"),
        paletteColors: [Color(hex: "FF6B6B"), Color(hex: "FF8E53")],
        backgroundColors: [Color(hex: "120808"), Color(hex: "3D0E0E")]
    )

    static let blue = AppTheme(
        id: "blue",
        name: "Blue",
        primary: Color(hex: "3B82F6"),
        paletteColors: [Color(hex: "3B82F6"), Color(hex: "6366F1")],
        backgroundColors: [Color(hex: "050D1A"), Color(hex: "0D1B2A")]
    )

    static let violet = AppTheme(
        id: "violet",
        name: "Violet",
        primary: Color(hex: "8B5CF6"),
        paletteColors: [Color(hex: "8B5CF6"), Color(hex: "A855F7")],
        backgroundColors: [Color(hex: "0D0020"), Color(hex: "190038")]
    )

    static let green = AppTheme(
        id: "green",
        name: "Green",
        primary: Color(hex: "10B981"),
        paletteColors: [Color(hex: "10B981"), Color(hex: "059669")],
        backgroundColors: [Color(hex: "0B1E15"), Color(hex: "143322")]
    )

    static let orange = AppTheme(
        id: "orange",
        name: "Orange",
        primary: Color(hex: "F59E0B"),
        paletteColors: [Color(hex: "F59E0B"), Color(hex: "F97316")],
        backgroundColors: [Color(hex: "180800"), Color(hex: "2D1200")]
    )

    static let rose = AppTheme(
        id: "rose",
        name: "Rose",
        primary: Color(hex: "EC4899"),
        paletteColors: [Color(hex: "EC4899"), Color(hex: "F472B6")],
        backgroundColors: [Color(hex: "1A0B10"), Color(hex: "260F18")]
    )
}

// MARK: - Environment Key

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.coral
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
