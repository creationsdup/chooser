import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Shared input mode

enum ItemInputMode: String, CaseIterable, Identifiable {
    case savedList   = "savedList"
    case directEntry = "directEntry"
    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .savedList:   return "draw.inputMode.savedList"
        case .directEntry: return "draw.inputMode.direct"
        }
    }
}

// MARK: - Color hex initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3:
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (255, 255, 255)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    // WCAG relative luminance — returns true when the color is perceptually light
    var isLight: Bool {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (0.2126 * r + 0.7152 * g + 0.0722 * b) > 0.55
        #else
        return false
        #endif
    }

    // Returns dark or white depending on which has better contrast against this color
    var contrastingText: Color {
        isLight ? Color(red: 0.1, green: 0.1, blue: 0.1) : .white
    }
}

// MARK: - Haptics (platform-agnostic API)

enum HapticStyle {
    case light, medium, heavy, rigid, soft
}

func hapticImpact(_ style: HapticStyle = .medium) {
#if canImport(UIKit)
    let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle
    switch style {
    case .light:  feedbackStyle = .light
    case .medium: feedbackStyle = .medium
    case .heavy:  feedbackStyle = .heavy
    case .rigid:  feedbackStyle = .rigid
    case .soft:   feedbackStyle = .soft
    }
    UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
#endif
}

func hapticSuccess() {
#if canImport(UIKit)
    UINotificationFeedbackGenerator().notificationOccurred(.success)
#endif
}

func hapticError() {
#if canImport(UIKit)
    UINotificationFeedbackGenerator().notificationOccurred(.error)
#endif
}

// MARK: - PressableButtonStyle
// Micro-interaction: subtle spring scale + brightness dip on press.
// Use on every CTA button for a consistent premium tactile feel.

struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    var brightness: Double = -0.04

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .brightness(configuration.isPressed ? brightness : 0)
            .animation(
                .spring(response: 0.22, dampingFraction: 0.58),
                value: configuration.isPressed
            )
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    /// Standard CTA press (scale 0.96)
    static var pressable: PressableButtonStyle { .init() }
    /// Slightly heavier press for large cards (scale 0.97)
    static var pressableCard: PressableButtonStyle { .init(scale: 0.97, brightness: -0.03) }
    /// Very light press for small icon buttons
    static var pressableLight: PressableButtonStyle { .init(scale: 0.93, brightness: -0.05) }
}

// MARK: - Inner Highlight Modifier
// Adds a subtle top-edge light sheen to any rounded surface — creates depth
// without being visible at first glance.

struct InnerHighlightModifier: ViewModifier {
    var cornerRadius: CGFloat
    var intensity: Double = 0.09

    func body(content: Content) -> some View {
        content.overlay(
            LinearGradient(
                colors: [.white.opacity(intensity), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.45)
            )
            .allowsHitTesting(false)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        )
    }
}

extension View {
    func innerHighlight(cornerRadius: CGFloat, intensity: Double = 0.09) -> some View {
        modifier(InnerHighlightModifier(cornerRadius: cornerRadius, intensity: intensity))
    }
}
