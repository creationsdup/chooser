import SwiftUI

// MARK: - Accent Color

enum AppAccentColor: String, CaseIterable, Identifiable {
    case coral  = "coral"
    case blue   = "blue"
    case violet = "violet"
    case green  = "green"
    case orange = "orange"
    case rose   = "rose"

    var id: String { rawValue }
    var labelKey: String { "accent.\(rawValue)" }

    var color: Color {
        switch self {
        case .coral:  return Color(hex: "FF6B6B")
        case .blue:   return Color(hex: "3B82F6")
        case .violet: return Color(hex: "8B5CF6")
        case .green:  return Color(hex: "10B981")
        case .orange: return Color(hex: "F59E0B")
        case .rose:   return Color(hex: "EC4899")
        }
    }
}

// MARK: - Color Scheme Preference

enum AppColorScheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var id: String { rawValue }
    var labelKey: String { "scheme.\(rawValue)" }

    var resolved: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }
}

// MARK: - Visual Style

enum AppVisualStyle: String, CaseIterable, Identifiable {
    case classic  = "classic"
    case playful  = "playful"
    case minimal  = "minimal"
    case midnight = "midnight"

    var id: String { rawValue }
    var labelKey: String { "style.\(rawValue)" }
    var descKey: String  { "style.\(rawValue).desc" }

    var icon: String {
        switch self {
        case .classic:  return "square.grid.2x2.fill"
        case .playful:  return "sparkles"
        case .minimal:  return "rectangle"
        case .midnight: return "moon.stars.fill"
        }
    }
}

// MARK: - Appearance Manager

@Observable
final class AppearanceManager {

    var colorScheme: AppColorScheme = .system {
        didSet { UserDefaults.standard.set(colorScheme.rawValue, forKey: "appColorScheme") }
    }

    var accentColor: AppAccentColor = .coral {
        didSet { UserDefaults.standard.set(accentColor.rawValue, forKey: "appAccentColor") }
    }

    var visualStyle: AppVisualStyle = .classic {
        didSet { UserDefaults.standard.set(visualStyle.rawValue, forKey: "appVisualStyle") }
    }

    var animationsReduced: Bool = false {
        didSet { UserDefaults.standard.set(animationsReduced, forKey: "appAnimationsReduced") }
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: "appColorScheme"),
           let val = AppColorScheme(rawValue: raw) { colorScheme = val }
        if let raw = UserDefaults.standard.string(forKey: "appAccentColor"),
           let val = AppAccentColor(rawValue: raw) { accentColor = val }
        if let raw = UserDefaults.standard.string(forKey: "appVisualStyle"),
           let val = AppVisualStyle(rawValue: raw) { visualStyle = val }
        animationsReduced = UserDefaults.standard.bool(forKey: "appAnimationsReduced")
    }

    /// Resolved SwiftUI accent Color.
    var accent: Color { accentColor.color }

    /// Resolved ColorScheme for preferredColorScheme modifier.
    var resolvedScheme: ColorScheme? { colorScheme.resolved }

    /// Maps accent color to its corresponding AppTheme (for views using appTheme environment).
    var resolvedTheme: AppTheme {
        AppTheme.theme(for: accentColor.rawValue)
    }
}
