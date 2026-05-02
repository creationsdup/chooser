import SwiftUI
import SwiftData

// MARK: - Picker Mode

enum PickerMode: String, CaseIterable, Identifiable {
    case fingerChooser
    case roulette
    case weightedRoulette
    case dice
    case randomDraw
    case coinFlip
    case numberRoulette
    case luckyArrow
    case ranking

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .fingerChooser:    return "mode.fingerChooser.title"
        case .roulette:         return "mode.roulette.title"
        case .dice:             return "mode.dice.title"
        case .randomDraw:       return "mode.randomDraw.title"
        case .coinFlip:         return "mode.coinFlip.title"
        case .numberRoulette:   return "mode.numberRoulette.title"
        case .luckyArrow:       return "mode.luckyArrow.title"
        case .weightedRoulette: return "mode.weightedRoulette.title"
        case .ranking:          return "mode.ranking.title"
        }
    }

    var subtitleKey: String {
        switch self {
        case .fingerChooser:    return "mode.fingerChooser.subtitle"
        case .roulette:         return "mode.roulette.subtitle"
        case .dice:             return "mode.dice.subtitle"
        case .randomDraw:       return "mode.randomDraw.subtitle"
        case .coinFlip:         return "mode.coinFlip.subtitle"
        case .numberRoulette:   return "mode.numberRoulette.subtitle"
        case .luckyArrow:       return "mode.luckyArrow.subtitle"
        case .weightedRoulette: return "mode.weightedRoulette.subtitle"
        case .ranking:          return "mode.ranking.subtitle"
        }
    }

    var systemImage: String {
        switch self {
        case .fingerChooser:    return "hand.point.up.left.fill"
        case .roulette:         return "circle.grid.cross.fill"
        case .dice:             return "die.face.5.fill"
        case .randomDraw:       return "ticket.fill"
        case .coinFlip:         return "circle.fill"
        case .numberRoulette:   return "number.circle.fill"
        case .luckyArrow:       return "arrow.up.circle.fill"
        case .weightedRoulette: return "chart.pie.fill"
        case .ranking:          return "list.number"
        }
    }

    /// Gradient palette unique to each mode — used only in Playful style and icon accents.
    var gradient: [Color] {
        switch self {
        case .fingerChooser:    return [Color(hex: "7B5FE3"), Color(hex: "A285FF")]
        case .roulette:         return [Color(hex: "E8556F"), Color(hex: "FF8094")]
        case .dice:             return [Color(hex: "2EA86A"), Color(hex: "5DD49B")]
        case .randomDraw:       return [Color(hex: "0EAFAA"), Color(hex: "3DD9D5")]
        case .coinFlip:         return [Color(hex: "E89A3A"), Color(hex: "FFC97A")]
        case .numberRoulette:   return [Color(hex: "5957D4"), Color(hex: "7977E8")]
        case .luckyArrow:       return [Color(hex: "FF2D55"), Color(hex: "FF7700")]
        case .weightedRoulette: return [Color(hex: "3A8DE8"), Color(hex: "62B0FF")]
        case .ranking:          return [Color(hex: "FBBF24"), Color(hex: "10B981")]
        }
    }

    var accentColor: Color { gradient[0] }
}

// MARK: - Home View

struct HomeView: View {
    @Environment(LanguageManager.self)    private var lm
    @Environment(AppearanceManager.self) private var appearance
    @Environment(\.verticalSizeClass)    private var verticalSizeClass
    @Environment(\.colorScheme)          private var colorScheme

    @State private var selectedMode: PickerMode? = nil

    private var isLandscape: Bool { verticalSizeClass == .compact }

    private let twoColumns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
    private let threeColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            if isLandscape {
                LazyVGrid(columns: threeColumns, spacing: 12) {
                    ForEach(PickerMode.allCases) { mode in
                        modeButton(mode, isFeatured: false)
                    }
                }
                .padding(14)
            } else {
                VStack(spacing: 14) {
                    // Featured hero card — full width
                    modeButton(.fingerChooser, isFeatured: true)

                    // 2-column grid for the rest
                    LazyVGrid(columns: twoColumns, spacing: 14) {
                        ForEach(PickerMode.allCases.dropFirst()) { mode in
                            modeButton(mode, isFeatured: false)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle(lm.t("home.title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(
            (appearance.visualStyle == .atmos && colorScheme == .dark) ? .dark : nil,
            for: .navigationBar
        )
        .background {
            if appearance.visualStyle == .atmos {
                ZStack {
                    if colorScheme == .dark {
                        Color(hex: "0B0D14")
                        RadialGradient(
                            colors: [Color(hex: "9B7CFF").opacity(0.35), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 160
                        )
                        .frame(width: 320, height: 320)
                        .blur(radius: 20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .offset(x: -40, y: -60)
                        RadialGradient(
                            colors: [Color(hex: "FFB85C").opacity(0.22), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 140
                        )
                        .frame(width: 280, height: 280)
                        .blur(radius: 20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .offset(x: 50, y: 30)
                    } else {
                        Color.white
                    }
                }
                .ignoresSafeArea()
            } else {
                Color(.systemGroupedBackground)
            }
        }
        .fullScreenCover(item: $selectedMode) { mode in
            pickerDestination(mode)
                .environment(lm)
                .environment(appearance)
                .environment(\.appTheme, appearance.resolvedTheme)
        }
    }

    private func modeButton(_ mode: PickerMode, isFeatured: Bool) -> some View {
        Button { selectedMode = mode } label: {
            PickerModeCard(
                mode: mode,
                title: lm.t(mode.titleKey),
                subtitle: lm.t(mode.subtitleKey),
                isFeatured: isFeatured,
                visualStyle: appearance.visualStyle
            )
        }
        .buttonStyle(.pressableCard)
    }

    @ViewBuilder
    private func pickerDestination(_ mode: PickerMode) -> some View {
        switch mode {
        case .fingerChooser:    FingerChooserView()
        case .roulette:         RouletteView()
        case .dice:             DiceRollView()
        case .randomDraw:       RandomDrawView()
        case .coinFlip:         CoinFlipView()
        case .numberRoulette:   NumberRouletteContainerView()
        case .luckyArrow:       LuckyArrowView()
        case .weightedRoulette: WeightedRouletteView()
        case .ranking:          RankingView()
        }
    }
}

// MARK: - Card

struct PickerModeCard: View {
    let mode: PickerMode
    let title: String
    let subtitle: String
    let isFeatured: Bool
    let visualStyle: AppVisualStyle

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        switch visualStyle {
        case .atmos:
            atmosCard
        case .playful:
            playfulCard
        }
    }

    // ── Playful ────────────────────────────────────────────────────────────
    // Solid-color card — vibrant without contrast issues.
    // Text color adapts automatically (black on light accents, white on dark).
    private var playfulCard: some View {
        ZStack(alignment: .bottomLeading) {
            mode.accentColor  // solid — no gradient

            // Decorative oversized icon
            Image(systemName: mode.systemImage)
                .font(.system(size: isFeatured ? 100 : 68))
                .foregroundStyle(mode.accentColor.contrastingText.opacity(0.09))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(isFeatured ? 14 : 8)
                .offset(x: 10, y: -6)

            VStack(alignment: .leading, spacing: 5) {
                Image(systemName: mode.systemImage)
                    .font(.system(size: isFeatured ? 32 : 26, weight: .semibold))
                    .foregroundStyle(mode.accentColor.contrastingText)
                Text(title)
                    .font(.system(size: isFeatured ? 21 : 16, weight: .bold, design: .rounded))
                    .foregroundStyle(mode.accentColor.contrastingText)
                Text(subtitle)
                    .font(.system(size: isFeatured ? 13 : 11, design: .rounded))
                    .foregroundStyle(mode.accentColor.contrastingText.opacity(0.72))
                    .lineLimit(2)
            }
            .padding(isFeatured ? 20 : 14)
        }
        .aspectRatio(isFeatured ? 2.2 : 1.15, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: mode.accentColor.opacity(0.30), radius: 10, x: 0, y: 5)
    }

    // ── Atmos Vibrant Dark ─────────────────────────────────────────────────────
    @ViewBuilder
    private var atmosCard: some View {
        if isFeatured {
            atmosFeaturedCard
        } else {
            atmosTileCard
        }
    }

    private var isDark: Bool { colorScheme == .dark }

    private var atmosFeaturedCard: some View {
        ZStack(alignment: .bottomLeading) {
            // Background
            if isDark {
                Color(hex: "161A24")
                LinearGradient(
                    stops: [
                        .init(color: mode.gradient[0].opacity(0.19), location: 0),
                        .init(color: mode.gradient[1].opacity(0.09), location: 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color.white
                LinearGradient(
                    stops: [
                        .init(color: mode.gradient[0].opacity(0.10), location: 0),
                        .init(color: mode.gradient[1].opacity(0.05), location: 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            // Glow bottom-right
            Circle()
                .fill(mode.gradient[0].opacity(isDark ? 0.15 : 0.08))
                .frame(width: 140, height: 140)
                .blur(radius: 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: 40, y: 40)

            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    LinearGradient(colors: mode.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: mode.systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .shadow(color: mode.gradient[0].opacity(0.33), radius: 7, x: 0, y: 3)

                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14.5, weight: .black, design: .rounded))
                        .foregroundStyle(isDark ? .white : Color(hex: "1A1A2E"))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11.5, design: .rounded))
                        .foregroundStyle(isDark ? .white.opacity(0.6) : Color(hex: "1A1A2E").opacity(0.50))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, minHeight: 130)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(mode.gradient[0].opacity(isDark ? 0.20 : 0.22), lineWidth: 1)
        )
        .shadow(color: mode.gradient[0].opacity(isDark ? 0.33 : 0.15), radius: isDark ? 20 : 10, x: 0, y: isDark ? 8 : 4)
    }

    private var atmosTileCard: some View {
        ZStack(alignment: .bottomLeading) {
            // Background
            if isDark {
                Color(hex: "161A24")
            } else {
                Color.white
            }

            LinearGradient(
                stops: [
                    .init(color: mode.gradient[0].opacity(isDark ? 0.19 : 0.10), location: 0),
                    .init(color: mode.gradient[1].opacity(isDark ? 0.09 : 0.05), location: 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(mode.gradient[0].opacity(isDark ? 0.15 : 0.08))
                .frame(width: 90, height: 90)
                .blur(radius: 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: 30, y: 30)

            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    LinearGradient(colors: mode.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: mode.systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .shadow(color: mode.gradient[0].opacity(0.33), radius: 7, x: 0, y: 3)

                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14.5, weight: .black, design: .rounded))
                        .foregroundStyle(isDark ? .white : Color(hex: "1A1A2E"))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11.5, design: .rounded))
                        .foregroundStyle(isDark ? .white.opacity(0.6) : Color(hex: "1A1A2E").opacity(0.50))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
        }
        .aspectRatio(1.05, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(mode.gradient[0].opacity(isDark ? 0.20 : 0.22), lineWidth: 1)
        )
    }

}

#Preview {
    NavigationStack {
        HomeView()
    }
    .modelContainer(for: ChoiceList.self, inMemory: true)
    .environment(LanguageManager())
    .environment(AppearanceManager())
}
