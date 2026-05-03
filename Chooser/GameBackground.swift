import SwiftUI

struct GameBackgroundView: View {
    let theme: AppTheme
    let appearance: AppearanceManager
    let colorScheme: ColorScheme

    var body: some View {
        ZStack {
            if appearance.visualStyle == .atmos {
                if colorScheme == .dark {
                    Color(hex: "161A24")
                    RadialGradient(
                        colors: [theme.primary.opacity(0.22), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 260
                    )
                    .blur(radius: 24)
                    RadialGradient(
                        colors: [(theme.paletteColors.last ?? theme.primary).opacity(0.14), .clear],
                        center: .bottomTrailing,
                        startRadius: 0,
                        endRadius: 220
                    )
                    .blur(radius: 20)
                } else {
                    Color.white
                    theme.primary.opacity(0.07)
                    LinearGradient(
                        stops: [
                            .init(color: theme.primary.opacity(0.16), location: 0),
                            .init(color: (theme.paletteColors.last ?? theme.primary).opacity(0.08), location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            } else {
                Color(hex: "0E0E10")
            }
        }
        .ignoresSafeArea()
    }
}
