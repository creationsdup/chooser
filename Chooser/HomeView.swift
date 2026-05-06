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

    /// Darker variants ensuring WCAG contrast on light (white) backgrounds.
    var lightGradient: [Color] {
        switch self {
        case .ranking:          return [Color(hex: "D97706"), Color(hex: "059669")]
        case .coinFlip:         return [Color(hex: "B45309"), Color(hex: "D97706")]
        case .randomDraw:       return [Color(hex: "0891B2"), Color(hex: "0E7490")]
        default:                return gradient
        }
    }
}

// MARK: - Home View

struct HomeView: View {
    @Environment(LanguageManager.self)    private var lm
    @Environment(AppearanceManager.self) private var appearance
    @Environment(\.verticalSizeClass)    private var verticalSizeClass
    @Environment(\.colorScheme)          private var colorScheme
    @Query private var lists: [ChoiceList]

    @AppStorage("lastUsedMode")              private var lastUsedModeRaw = PickerMode.roulette.rawValue
    @AppStorage("lastList_roulette")         private var lastListRoulette = ""
    @AppStorage("lastList_randomDraw")       private var lastListRandomDraw = ""
    @AppStorage("lastList_weightedRoulette") private var lastListWeightedRoulette = ""
    @AppStorage("lastList_ranking")          private var lastListRanking = ""

    @State private var selectedMode: PickerMode? = nil

    private var isLandscape: Bool { verticalSizeClass == .compact }

    private var heroMode: PickerMode {
        PickerMode(rawValue: lastUsedModeRaw) ?? .roulette
    }

    private func lastListInfo(for mode: PickerMode) -> (emoji: String, name: String)? {
        let name: String
        switch mode {
        case .roulette:         name = lastListRoulette
        case .randomDraw:       name = lastListRandomDraw
        case .weightedRoulette: name = lastListWeightedRoulette
        case .ranking:          name = lastListRanking
        default: return nil
        }
        guard !name.isEmpty, let list = lists.first(where: { $0.name == name }) else { return nil }
        return (list.emoji, list.name)
    }

    private func preselectedList(for mode: PickerMode) -> ChoiceList? {
        let name: String
        switch mode {
        case .roulette:         name = lastListRoulette
        case .randomDraw:       name = lastListRandomDraw
        case .weightedRoulette: name = lastListWeightedRoulette
        case .ranking:          name = lastListRanking
        default: return nil
        }
        return lists.first(where: { $0.name == name })
    }

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
                    modeButton(heroMode, isFeatured: true)

                    LazyVGrid(columns: twoColumns, spacing: 14) {
                        ForEach(PickerMode.allCases.filter { $0 != heroMode }) { mode in
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
                Color(colorScheme == .dark ? UIColor.systemGroupedBackground : UIColor.systemBackground)
                    .ignoresSafeArea()
            }
        }
        .fullScreenCover(item: $selectedMode) { mode in
            pickerDestination(mode)
                .environment(lm)
                .environment(appearance)
                .environment(\.appTheme, appearance.resolvedTheme)
                .preferredColorScheme(appearance.resolvedScheme)
        }
    }

    private func modeButton(_ mode: PickerMode, isFeatured: Bool) -> some View {
        Button {
            lastUsedModeRaw = mode.rawValue
            selectedMode = mode
        } label: {
            PickerModeCard(
                mode: mode,
                title: lm.t(mode.titleKey),
                subtitle: lm.t(mode.subtitleKey),
                isFeatured: isFeatured,
                visualStyle: appearance.visualStyle,
                lastListInfo: lastListInfo(for: mode)
            )
        }
        .buttonStyle(.pressableCard)
    }

    @ViewBuilder
    private func pickerDestination(_ mode: PickerMode) -> some View {
        switch mode {
        case .fingerChooser:    FingerChooserView()
        case .roulette:         RouletteView(preselectedList: preselectedList(for: .roulette))
        case .dice:             DiceRollView()
        case .randomDraw:       RandomDrawView(preselectedList: preselectedList(for: .randomDraw))
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
    var lastListInfo: (emoji: String, name: String)? = nil

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
                // Pastel light — fond blanc + teinte pastel de la couleur du mode
                Color.white
                mode.gradient[0].opacity(0.10)
                LinearGradient(
                    stops: [
                        .init(color: mode.gradient[0].opacity(0.22), location: 0),
                        .init(color: mode.gradient[1].opacity(0.12), location: 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            // Decorative oversized icon
            Image(systemName: mode.systemImage)
                .font(.system(size: 100))
                .foregroundStyle(mode.gradient[0].opacity(isDark ? 0.12 : 0.18))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(14)
                .offset(x: 10, y: -6)

            VStack(alignment: .leading, spacing: 5) {
                Image(systemName: mode.systemImage)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isDark ? mode.gradient : mode.lightGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(title)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(isDark ? .white : Color(hex: "1A1A2E"))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(isDark ? .white.opacity(0.6) : Color(hex: "1A1A2E").opacity(0.45))
                    .lineLimit(2)
            }
            .padding(20)

        }
        .aspectRatio(2.2, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(mode.gradient[0].opacity(isDark ? 0.20 : 0.18), lineWidth: 1)
        )
        .shadow(
            color: mode.gradient[0].opacity(isDark ? 0.33 : 0.10),
            radius: isDark ? 20 : 8,
            x: 0, y: isDark ? 8 : 3
        )
    }

    private var atmosTileCard: some View {
        ZStack(alignment: .bottomLeading) {
            if isDark {
                Color(hex: "161A24")
            } else {
                Color.white
                mode.gradient[0].opacity(0.10)
            }

            LinearGradient(
                stops: [
                    .init(color: mode.gradient[0].opacity(isDark ? 0.19 : 0.22), location: 0),
                    .init(color: mode.gradient[1].opacity(isDark ? 0.09 : 0.12), location: 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Decorative oversized icon
            Image(systemName: mode.systemImage)
                .font(.system(size: 68))
                .foregroundStyle(mode.gradient[0].opacity(isDark ? 0.12 : 0.18))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(8)
                .offset(x: 10, y: -6)

            VStack(alignment: .leading, spacing: 5) {
                Image(systemName: mode.systemImage)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isDark ? mode.gradient : mode.lightGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(isDark ? .white : Color(hex: "1A1A2E"))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(isDark ? .white.opacity(0.6) : Color(hex: "1A1A2E").opacity(0.45))
                    .lineLimit(2)
            }
            .padding(14)

        }
        .aspectRatio(1.15, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(mode.gradient[0].opacity(isDark ? 0.20 : 0.18), lineWidth: 1)
        )
        .shadow(
            color: mode.gradient[0].opacity(isDark ? 0.25 : 0.10),
            radius: isDark ? 12 : 6,
            x: 0, y: isDark ? 5 : 2
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
