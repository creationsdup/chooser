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
        case .fingerChooser:    return [Color(hex: "A855F7"), Color(hex: "EC4899")]
        case .roulette:         return [Color(hex: "FF6B6B"), Color(hex: "FF8E53")]
        case .dice:             return [Color(hex: "10B981"), Color(hex: "059669")]
        case .randomDraw:       return [Color(hex: "4ECDC4"), Color(hex: "2563EB")]
        case .coinFlip:         return [Color(hex: "F59E0B"), Color(hex: "D97706")]
        case .numberRoulette:   return [Color(hex: "6366F1"), Color(hex: "8B5CF6")]
        case .luckyArrow:       return [Color(hex: "FF2D55"), Color(hex: "FF7700")]
        case .weightedRoulette: return [Color(hex: "0EA5E9"), Color(hex: "6366F1")]
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
        .background(Color(.systemGroupedBackground))
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

    var body: some View {
        switch visualStyle {
        case .playful:
            playfulCard
        case .minimal:
            minimalCard
        case .midnight:
            midnightCard
        case .classic:
            classicCard
        }
    }

    // ── Classic ────────────────────────────────────────────────────────────
    // White/adaptive card with a colored icon strip at the top.
    private var classicCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            iconStrip(height: isFeatured ? 110 : 76, iconSize: isFeatured ? 30 : 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: isFeatured ? 16 : 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: isFeatured ? 12 : 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
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

    // ── Minimal ─────────────────────────────────────────────────────────────
    // Ultra-clean: white background, tiny colored icon dot, precise spacing.
    private var minimalCard: some View {
        HStack(alignment: isFeatured ? .center : .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(mode.accentColor.opacity(0.12))
                    .frame(width: isFeatured ? 48 : 38, height: isFeatured ? 48 : 38)
                Image(systemName: mode.systemImage)
                    .font(.system(size: isFeatured ? 20 : 16, weight: .semibold))
                    .foregroundStyle(mode.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: isFeatured ? 17 : 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: isFeatured ? 13 : 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(isFeatured ? 2 : 3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(isFeatured ? 16 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
        )
    }

    // ── Midnight ────────────────────────────────────────────────────────────
    // Dark card, solid accent-colored icon area — premium, no gradient.
    private var midnightCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .center) {
                // Solid accent-tinted icon zone
                Rectangle()
                    .fill(mode.accentColor.opacity(0.18))
                    .frame(height: isFeatured ? 110 : 76)

                Image(systemName: mode.systemImage)
                    .font(.system(size: isFeatured ? 30 : 24, weight: .semibold))
                    .foregroundStyle(mode.accentColor)
            }
            .frame(maxWidth: .infinity)
            .clipShape(.rect(
                topLeadingRadius: 18,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 18
            ))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: isFeatured ? 16 : 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: isFeatured ? 12 : 11, design: .rounded))
                    .foregroundStyle(Color(hex: "A1A1AA"))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .background(Color(hex: "141418"))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(mode.accentColor.opacity(0.20), lineWidth: 1)
        )
        .shadow(color: mode.accentColor.opacity(0.15), radius: 10, x: 0, y: 4)
    }

    // MARK: - Shared: icon strip

    private func iconStrip(height: CGFloat, iconSize: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Solid accent color — no gradient
            mode.accentColor
                .frame(height: height)

            // Decorative large icon
            Image(systemName: mode.systemImage)
                .font(.system(size: height * 0.75))
                .foregroundStyle(.white.opacity(0.09))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(10)

            // Main icon
            Image(systemName: mode.systemImage)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.white)
                .padding(12)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        }
        .clipShape(
            .rect(
                topLeadingRadius: 18,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 18
            )
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
