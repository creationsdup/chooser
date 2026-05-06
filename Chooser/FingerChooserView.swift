import SwiftUI
#if canImport(UIKit)
import UIKit

// MARK: - Pair color palette

private let pairColorPalette: [Color] = [
    Color(hex: "FF6B6B"), Color(hex: "4ECDC4"), Color(hex: "FFE66D"),
    Color(hex: "A855F7"), Color(hex: "3B82F6"), Color(hex: "10B981"),
    Color(hex: "EC4899"), Color(hex: "F59E0B")
]

// MARK: - Mode

enum FingerMode: String, CaseIterable, Identifiable {
    case classic, ranking, links
    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .classic: return "finger.mode.classic"
        case .ranking: return "finger.mode.ranking"
        case .links:   return "finger.mode.links"
        }
    }

    var descriptionKey: String {
        switch self {
        case .classic: return "finger.mode.classic.desc"
        case .ranking: return "finger.mode.ranking.desc"
        case .links:   return "finger.mode.links.desc"
        }
    }

    var waitingKey: String {
        switch self {
        case .classic: return "finger.waiting.classic"
        case .ranking: return "finger.waiting.ranking"
        case .links:   return "finger.waiting.links"
        }
    }

    var systemImage: String {
        switch self {
        case .classic: "hand.point.up.left.fill"
        case .ranking: "list.number"
        case .links:   "link.circle.fill"
        }
    }
}

// MARK: - Touch State

enum FingerChooserState: Equatable {
    case waiting
    case holding
    case countdown(Int)
    case selecting
    case selectedOne(Int)
    case selectedMultiple([Int])  // classic mode, multiple winners
    case ranked([Int: Int])   // fingerID -> rank (1 = winner)
    case linked([Int: Int])   // fingerID -> partnerID (-1 if odd-one-out)
}

// MARK: - Touch Point

struct TouchPoint: Identifiable {
    let id: Int
    let position: CGPoint
    // Classic
    var isSelected: Bool = false
    var isEliminated: Bool = false
    // Shared
    var isHighlighted: Bool = false
    // Ranking
    var rank: Int? = nil
    // Links
    var partnerIndex: Int? = nil
    var isSolo: Bool = false

    var color: Color {
        let palette: [Color] = [
            Color(hex: "A855F7"), Color(hex: "EC4899"), Color(hex: "3B82F6"),
            Color(hex: "10B981"), Color(hex: "F59E0B"), Color(hex: "EF4444"),
            Color(hex: "FFE66D"), Color(hex: "4ECDC4"), Color(hex: "FF6B6B"), Color(hex: "6366F1")
        ]
        return palette[id % palette.count]
    }

    var effectiveColor: Color {
        if let idx = partnerIndex { return pairColorPalette[idx % pairColorPalette.count] }
        if isSolo { return .gray.opacity(0.8) }
        return color
    }
}

// MARK: - UIKit Multi-touch View

final class MultiTouchUIView: UIView {
    var onTouchesChanged: (([Int: CGPoint]) -> Void)?

    private var activeTouches: [UITouch: Int] = [:]
    private var nextId = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return bounds.contains(point) ? self : nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where activeTouches[touch] == nil {
            activeTouches[touch] = nextId
            nextId += 1
        }
        report()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { report() }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach { activeTouches.removeValue(forKey: $0) }
        report()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach { activeTouches.removeValue(forKey: $0) }
        report()
    }

    private func report() {
        var positions: [Int: CGPoint] = [:]
        for (touch, id) in activeTouches { positions[id] = touch.location(in: self) }
        onTouchesChanged?(positions)
    }
}

struct MultiTouchRepresentable: UIViewRepresentable {
    let onTouchesChanged: ([Int: CGPoint]) -> Void
    func makeUIView(context: Context) -> MultiTouchUIView {
        let view = MultiTouchUIView()
        view.onTouchesChanged = onTouchesChanged
        return view
    }
    func updateUIView(_ uiView: MultiTouchUIView, context: Context) {
        uiView.onTouchesChanged = onTouchesChanged
    }
}

// MARK: - View Model

@Observable
final class FingerChooserViewModel {
    var mode: FingerMode? = nil
    var touchPositions: [Int: CGPoint] = [:]
    var state: FingerChooserState = .waiting
    var highlightedId: Int? = nil

    // Classic
    var winnerCount: Int = 1
    var selectedId: Int? = nil
    var selectedIds: [Int] = []
    var winnerPosition: CGPoint? = nil

    // Ranking — intermediate (populated during .selecting, finalized in .ranked)
    var assignedRanks: [Int: Int] = [:]

    private var countdownTask: Task<Void, Never>? = nil

    var touchPoints: [TouchPoint] {
        let sortedPairKeys: [Int]
        if case .linked(let pairs) = state {
            sortedPairKeys = Set(pairs.compactMap { k, v -> Int? in v == -1 ? nil : min(k, v) }).sorted()
        } else {
            sortedPairKeys = []
        }

        return touchPositions.map { id, position in
            var pt = TouchPoint(id: id, position: position)
            pt.isHighlighted = id == highlightedId

            switch state {
            case .selectedOne(let winnerId):
                pt.isSelected = id == winnerId
                pt.isEliminated = id != winnerId

            case .selectedMultiple(let winnerIds):
                pt.isSelected = winnerIds.contains(id)
                pt.isEliminated = !winnerIds.contains(id)

            case .selecting:
                pt.rank = assignedRanks[id]
                if assignedRanks[id] != nil { pt.isHighlighted = false }

            case .ranked:
                pt.rank = assignedRanks[id]

            case .linked(let pairs):
                guard let partnerId = pairs[id] else { break }
                if partnerId == -1 {
                    pt.isSolo = true
                } else {
                    let pairKey = min(id, partnerId)
                    pt.partnerIndex = sortedPairKeys.firstIndex(of: pairKey)
                }

            default: break
            }
            return pt
        }.sorted { $0.id < $1.id }
    }

    func onTouchesChanged(_ positions: [Int: CGPoint]) {
        if case .selectedOne = state { return }
        if case .selectedMultiple = state { return }
        if case .ranked = state { return }
        if case .linked = state { return }

        let previousCount = touchPositions.count
        touchPositions = positions

        switch state {
        case .waiting:
            if positions.count >= 2, mode != nil { state = .holding; startCountdown() }
        case .holding:
            if positions.count < 2 { cancelCountdown() }
            else if positions.count != previousCount { startCountdown() }
        case .countdown:
            if positions.count < 2 { cancelCountdown() }
            else if positions.count != previousCount { startCountdown() }
        case .selecting:
            if positions.count < 2 { cancelCountdown() }
            else if positions.count != previousCount { startCountdown() }
        default: break
        }
    }

    func cancelAll() { countdownTask?.cancel(); countdownTask = nil }

    func reset() {
        cancelAll()
        selectedId = nil
        selectedIds = []
        highlightedId = nil
        winnerPosition = nil
        assignedRanks = [:]
        touchPositions = [:]
        state = .waiting
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        selectedId = nil
        selectedIds = []
        highlightedId = nil
        winnerPosition = nil
        assignedRanks = [:]
        state = .waiting
    }

    private func startCountdown() {
        guard let mode else { return }
        countdownTask?.cancel()
        countdownTask = Task {
            for n in [3, 2, 1] {
                guard !Task.isCancelled else { return }
                state = .countdown(n)
                hapticImpact(.rigid)
                try? await Task.sleep(for: .milliseconds(650))
            }
            guard !Task.isCancelled else { return }
            switch mode {
            case .classic: await runClassicSelection()
            case .ranking: await runRankingSelection()
            case .links:   await runLinksSelection()
            }
        }
    }

    private func runClassicSelection() async {
        state = .selecting
        let ids = Array(touchPositions.keys)
        let totalTicks = 30
        var sequence: [Int] = []
        while sequence.count < totalTicks { sequence.append(contentsOf: ids.shuffled()) }
        sequence = Array(sequence.prefix(totalTicks))

        for i in 0..<totalTicks {
            guard !Task.isCancelled else { return }
            let t = Double(i) / Double(totalTicks - 1)
            let ms = UInt64(40 + 162 * t * t)
            highlightedId = sequence[i]
            hapticImpact(.soft)
            try? await Task.sleep(nanoseconds: ms * 1_000_000)
        }
        guard !Task.isCancelled else { return }
        highlightedId = nil
        try? await Task.sleep(for: .milliseconds(150))
        guard !Task.isCancelled else { return }

        let effectiveCount = min(winnerCount, touchPositions.count)
        let winners = Array(touchPositions.keys.shuffled().prefix(effectiveCount))
        guard !winners.isEmpty else { state = .waiting; return }

        winnerPosition = touchPositions[winners[0]]
        hapticImpact(.heavy)
        hapticSuccess()

        if effectiveCount == 1 {
            selectedId = winners[0]
            state = .selectedOne(winners[0])
        } else {
            selectedIds = winners
            state = .selectedMultiple(winners)
        }
    }

    private func runRankingSelection() async {
        guard !Task.isCancelled else { return }
        assignedRanks = [:]
        let shuffled = touchPositions.keys.shuffled()
        for (index, id) in shuffled.enumerated() {
            assignedRanks[id] = index + 1
        }
        if let winnerId = shuffled.first {
            winnerPosition = touchPositions[winnerId]
        }
        hapticImpact(.heavy)
        hapticSuccess()
        state = .ranked(assignedRanks)
    }

    private func runLinksSelection() async {
        state = .selecting
        let ids = Array(touchPositions.keys)

        let flashTicks = 22
        for i in 0..<flashTicks {
            guard !Task.isCancelled else { return }
            highlightedId = ids[i % ids.count]
            hapticImpact(.soft)
            let ms = UInt64(18 + UInt64(i) * 7)
            try? await Task.sleep(nanoseconds: ms * 1_000_000)
        }
        guard !Task.isCancelled else { return }
        highlightedId = nil
        try? await Task.sleep(for: .milliseconds(120))
        guard !Task.isCancelled else { return }

        var shuffled = ids.shuffled()
        var pairs: [Int: Int] = [:]
        while shuffled.count >= 2 {
            let a = shuffled.removeFirst()
            let b = shuffled.removeFirst()
            pairs[a] = b
            pairs[b] = a
        }
        if let solo = shuffled.first { pairs[solo] = -1 }

        state = .linked(pairs)
        hapticImpact(.heavy)
        hapticSuccess()
    }
}

// MARK: - Confetti Burst

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let offsetX: CGFloat
    let offsetY: CGFloat
    let rotation: Double
    let color: Color
    let isRound: Bool
}

struct ConfettiBurstView: View {
    let color: Color
    @State private var particles: [ConfettiParticle] = []
    @State private var animating = false
    private let particleCount = 14

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                Group {
                    if p.isRound {
                        Circle().fill(p.color).frame(width: 10, height: 10)
                    } else {
                        RoundedRectangle(cornerRadius: 2).fill(p.color).frame(width: 8, height: 14)
                    }
                }
                .rotationEffect(.degrees(animating ? p.rotation + 360 : p.rotation))
                .offset(x: animating ? p.offsetX : 0, y: animating ? p.offsetY : 0)
                .opacity(animating ? 0 : 1)
            }
        }
        .onAppear {
            let colors: [Color] = [color, .white, Color(hex: "FFE66D"), Color(hex: "4ECDC4"), Color(hex: "FF6B6B")]
            particles = (0..<particleCount).map { i in
                let angle = (Double(i) / Double(particleCount)) * 2 * .pi + Double.random(in: -0.3...0.3)
                let dist = CGFloat.random(in: 80...145)
                return ConfettiParticle(
                    offsetX: cos(angle) * dist,
                    offsetY: sin(angle) * dist,
                    rotation: Double.random(in: 0...360),
                    color: colors.randomElement() ?? .white,
                    isRound: Bool.random()
                )
            }
            withAnimation(.easeOut(duration: 1.1)) { animating = true }
        }
    }
}

// MARK: - Links Connection Lines

struct LinksConnectionView: View {
    let pairs: [Int: Int]
    let positions: [Int: CGPoint]

    private var sortedPairKeys: [Int] {
        Set(pairs.compactMap { k, v -> Int? in v == -1 ? nil : min(k, v) }).sorted()
    }

    var body: some View {
        Canvas { ctx, _ in
            var drawn = Set<Int>()
            for (id, partnerId) in pairs {
                guard partnerId != -1, !drawn.contains(id) else { continue }
                guard let pos1 = positions[id], let pos2 = positions[partnerId] else { continue }
                let pairKey = min(id, partnerId)
                let pairIndex = sortedPairKeys.firstIndex(of: pairKey) ?? 0
                let color = pairColorPalette[pairIndex % pairColorPalette.count]
                var p = Path()
                p.move(to: pos1)
                p.addLine(to: pos2)
                ctx.stroke(p, with: .color(color.opacity(0.85)),
                           style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [14, 9]))
                drawn.insert(id)
                drawn.insert(partnerId)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Mode Illustrations

struct ModeIllustrationView: View {
    let mode: FingerMode

    var body: some View {
        switch mode {
        case .classic: classicIllustration
        case .ranking: rankingIllustration
        case .links:   linksIllustration
        }
    }

    private var classicIllustration: some View {
        ZStack {
            ForEach(0..<5) { i in
                let angle = Double(i) * (2 * .pi / 5) - .pi / 2
                let r: CGFloat = 30
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 18, height: 18)
                    .offset(x: cos(angle) * r, y: sin(angle) * r)
            }
            Circle()
                .fill(LinearGradient(
                    colors: [Color(hex: "FFE66D"), Color(hex: "FF6B6B")],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 34, height: 34)
                .shadow(color: Color(hex: "FFE66D").opacity(0.7), radius: 10)
            Image(systemName: "crown.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 80, height: 80)
    }

    private var rankingIllustration: some View {
        HStack(alignment: .bottom, spacing: 6) {
            rankCircle(rank: 2, size: 26, color: Color(hex: "C0C0C0"))
            rankCircle(rank: 1, size: 34, color: Color(hex: "FFE66D"))
            rankCircle(rank: 3, size: 22, color: Color(hex: "CD7F32"))
        }
        .frame(width: 80, height: 80)
    }

    private func rankCircle(rank: Int, size: CGFloat, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.85))
                .frame(width: size, height: size)
                .shadow(color: color.opacity(0.6), radius: 6)
            Text("\(rank)")
                .font(.system(size: size * 0.42, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var linksIllustration: some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let positions: [CGPoint] = [
                CGPoint(x: cx - 26, y: cy - 16),
                CGPoint(x: cx + 26, y: cy - 16),
                CGPoint(x: cx - 26, y: cy + 16),
                CGPoint(x: cx + 26, y: cy + 16)
            ]
            let pairColors: [Color] = [Color(hex: "FF6B6B"), Color(hex: "4ECDC4")]
            let pairDefs: [(Int, Int)] = [(0, 1), (2, 3)]

            for (i, (a, b)) in pairDefs.enumerated() {
                var line = Path()
                line.move(to: positions[a])
                line.addLine(to: positions[b])
                ctx.stroke(line, with: .color(pairColors[i].opacity(0.55)),
                           style: StrokeStyle(lineWidth: 2.5, dash: [6, 4]))
            }

            for (i, pos) in positions.enumerated() {
                let col = pairColors[i / 2]
                ctx.fill(
                    Path(ellipseIn: CGRect(x: pos.x - 11, y: pos.y - 11, width: 22, height: 22)),
                    with: .color(col)
                )
                ctx.fill(
                    Path(ellipseIn: CGRect(x: pos.x - 11, y: pos.y - 11, width: 22, height: 22)),
                    with: .color(Color.white.opacity(0.25))
                )
            }
        }
        .frame(width: 80, height: 80)
    }
}

// MARK: - Mode Settings Sheet

struct ModeCard: View {
    let mode: FingerMode
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(LanguageManager.self) private var lm

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ModeIllustrationView(mode: mode)
                    .frame(width: 72, height: 72)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isSelected
                                  ? Color(hex: "A855F7").opacity(0.15)
                                  : Color.secondary.opacity(0.07))
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(lm.t(mode.titleKey))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(lm.t(mode.descriptionKey))
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color(hex: "A855F7"))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected
                          ? Color(hex: "A855F7").opacity(0.07)
                          : Color.secondary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(isSelected
                                    ? Color(hex: "A855F7").opacity(0.5)
                                    : .clear,
                                    lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct ModeSettingsSheet: View {
    @Binding var selectedMode: FingerMode
    @Environment(LanguageManager.self) private var lm

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 4)
                .padding(.top, 12)

            Text(lm.t("finger.mode.section"))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .padding(.top, 18)
                .padding(.bottom, 4)

            Text(lm.t("finger.mode.subtitle"))
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.bottom, 20)

            VStack(spacing: 12) {
                ForEach(FingerMode.allCases) { mode in
                    ModeCard(mode: mode, isSelected: selectedMode == mode) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedMode = mode
                        }
                        hapticImpact(.medium)
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - Touch Circle

struct TouchCircleView: View {
    let point: TouchPoint
    @State private var pulsing = false
    @State private var elimScale: CGFloat = 1.0
    @State private var elimOpacity: Double = 1.0

    private var circleColor: Color { point.effectiveColor }

    private var shadowColor: Color {
        if point.isSelected { return circleColor }
        if point.isHighlighted { return .white.opacity(0.6) }
        if point.rank == 1 { return Color(hex: "FFE66D").opacity(0.7) }
        if point.rank != nil { return circleColor.opacity(0.4) }
        if point.partnerIndex != nil { return circleColor.opacity(0.5) }
        return .clear
    }

    var body: some View {
        ZStack {
            // Spotlight ring (roulette highlight)
            if point.isHighlighted && !point.isSelected {
                Circle()
                    .stroke(.white, lineWidth: 3)
                    .frame(width: 118, height: 118)
                    .shadow(color: .white.opacity(0.8), radius: 14)
            }

            // Main circle
            Circle()
                .fill(
                    point.isEliminated
                        ? AnyShapeStyle(.white.opacity(0.15))
                        : AnyShapeStyle(LinearGradient(
                            colors: [circleColor, circleColor.opacity(0.7)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                )
                .frame(width: point.isSelected ? 112 : 90,
                       height: point.isSelected ? 112 : 90)
                .overlay { Circle().stroke(.white.opacity(0.35), lineWidth: 2.5) }
                .shadow(color: shadowColor, radius: point.isSelected ? 24 : 16)
                .scaleEffect(elimScale)
                .opacity(elimOpacity)

            // Rank number (ranking mode)
            if let rank = point.rank {
                VStack(spacing: 1) {
                    if rank == 1 {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(hex: "FFE66D"))
                    }
                    Text("\(rank)")
                        .font(.system(size: rank == 1 ? 28 : 24, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                .transition(.scale(scale: 0.2).combined(with: .opacity))
            }

            // Odd-one-out indicator (links mode)
            if point.isSolo {
                Image(systemName: "questionmark")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            // Pulsing halo (classic winner)
            if point.isSelected {
                Circle()
                    .fill(circleColor.opacity(0.22))
                    .frame(width: pulsing ? 210 : 140, height: pulsing ? 210 : 140)
                    .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulsing)

                Circle()
                    .stroke(circleColor, lineWidth: 2.5)
                    .frame(width: pulsing ? 165 : 115, height: pulsing ? 165 : 115)
                    .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulsing)
            }
        }
        .frame(width: 210, height: 210)
        .scaleEffect(point.isHighlighted && !point.isSelected ? 1.12 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.55), value: point.rank)
        .onAppear { if point.isSelected { pulsing = true } }
        .onChange(of: point.isSelected) { _, selected in pulsing = selected }
        .onChange(of: point.isEliminated) { _, eliminated in
            if eliminated {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) { elimScale = 1.2 }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.12)) {
                    elimScale = 0.45
                    elimOpacity = 0.25
                }
            } else {
                elimScale = 1.0
                elimOpacity = 1.0
            }
        }
    }
}

// MARK: - Countdown Frame

private struct CountdownFrameView: View {
    let positions: [CGPoint]
    let countStep: Int

    @State private var pulsing = false
    private let padding: CGFloat = 92

    var body: some View {
        EmptyView()
    }
}

// MARK: - Main View

struct FingerChooserView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(LanguageManager.self) private var lm
    @Environment(AppearanceManager.self) private var appearance
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var isLandscape: Bool { verticalSizeClass == .compact }
    private var isAtmosLight: Bool { appearance.visualStyle == .atmos && colorScheme == .light }
    private var gameFg: Color { isAtmosLight ? Color(hex: "1A1A2E") : .white }
    @State private var viewModel = FingerChooserViewModel()
    @State private var flashOpacity: Double = 0
    @State private var showModeSelection = true

    var body: some View {
        ZStack {
            GameBackgroundView(theme: theme, appearance: appearance, colorScheme: colorScheme)

            // Background countdown number
            if case .countdown(let n) = viewModel.state {
                Text("\(n)")
                    .font(.system(size: 380, weight: .black, design: .rounded))
                    .foregroundStyle(gameFg.opacity(0.06))
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .id("bg_countdown_\(n)")
            }

            MultiTouchRepresentable { positions in
                viewModel.onTouchesChanged(positions)
            }
            .ignoresSafeArea()

            // Links connection lines (rendered below circles)
            if case .linked(let pairs) = viewModel.state {
                LinksConnectionView(pairs: pairs, positions: viewModel.touchPositions)
            }

            // Touch circles
            ZStack {
                ForEach(viewModel.touchPoints) { point in
                    TouchCircleView(point: point)
                        .position(point.position)
                        .transition(.scale(scale: 0.1).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: point.isSelected)
                        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: point.isHighlighted)
                }
            }
            .ignoresSafeArea()
            .animation(.spring(response: 0.4, dampingFraction: 0.55), value: viewModel.touchPoints.count)
            .allowsHitTesting(false)

            // Countdown bounding frame
            if case .countdown(let n) = viewModel.state {
                CountdownFrameView(positions: Array(viewModel.touchPositions.values), countStep: n)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // Confetti burst (classic winner + ranking rank-1)
            if let pos = viewModel.winnerPosition,
               let cid = viewModel.mode == .some(.classic)
                   ? (viewModel.selectedId ?? viewModel.selectedIds.first)
                   : viewModel.assignedRanks.first(where: { $0.value == 1 })?.key {
                ZStack {
                    ConfettiBurstView(color: TouchPoint(id: cid, position: pos).color)
                        .position(pos)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            // Screen flash on countdown tick
            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // UI overlay
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    Button { dismiss() } label: {
                        ZStack {
                            Circle()
                                .fill(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.08) : Color.white.opacity(0.18))
                                .frame(width: 40, height: 40)
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(gameFg)
                        }
                    }
                    .accessibilityLabel(lm.t("button.back"))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

                Spacer()

                stateOverlay
                    .padding(.bottom, isLandscape ? 20 : 70)
            }

            // Mode selection — always on top, covers everything
            if showModeSelection {
                modeSelectionOverlay
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .scale(scale: 0.96).combined(with: .opacity)
                    ))
                    .zIndex(1)
            }
        }
        .onChange(of: viewModel.mode) { _, _ in
            viewModel.reset()
        }
        .onChange(of: stateKey) { _, newKey in
            guard newKey.starts(with: "countdown") else { return }
            flashOpacity = 0.14
            Task {
                try? await Task.sleep(for: .milliseconds(60))
                withAnimation(.easeOut(duration: 0.5)) { flashOpacity = 0 }
            }
        }
        .onDisappear { viewModel.cancelAll() }
    }

    private var stateKey: String {
        switch viewModel.state {
        case .waiting:            return "waiting"
        case .holding:            return "holding"
        case .countdown(let n):   return "countdown\(n)"
        case .selecting:          return "selecting"
        case .selectedOne(let n): return "selectedOne\(n)"
        case .selectedMultiple(let ids): return "selectedMultiple\(ids.sorted())"
        case .ranked:             return "ranked"
        case .linked:             return "linked"
        }
    }

    @ViewBuilder
    private var stateOverlay: some View {
        ZStack {
            switch viewModel.state {
            case .waiting:
                if !showModeSelection {
                    VStack(spacing: 14) {
                        Image(systemName: "hand.point.up.left.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(gameFg.opacity(0.45))
                        Text(waitingText)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(gameFg.opacity(0.82))
                            .multilineTextAlignment(.center)
                        modeBadge
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }

            case .holding:
                Text(String(format: lm.t("finger.detected"), viewModel.touchPositions.count, viewModel.touchPositions.count == 1 ? "" : "s", viewModel.touchPositions.count == 1 ? "" : "s"))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(gameFg)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.08) : Color.white.opacity(0.12), in: Capsule())
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))

            case .countdown, .selecting:
                EmptyView()

            case .selectedOne, .selectedMultiple, .ranked, .linked:
                resetButton
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: stateKey)
    }

    private var waitingText: String {
        guard let mode = viewModel.mode else { return "" }
        return lm.t(mode.waitingKey)
    }

    private var modeSelectionOverlay: some View {
        ZStack {
            GameBackgroundView(theme: theme, appearance: appearance, colorScheme: colorScheme)

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button { dismiss() } label: {
                        ZStack {
                            Circle()
                                .fill(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.08) : Color.white.opacity(0.18))
                                .frame(width: 40, height: 40)
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(gameFg)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Title
                VStack(spacing: 6) {
                    Text(lm.t("finger.mode.section"))
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(gameFg)
                    Text(lm.t("finger.mode.subtitle"))
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(gameFg.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .padding(.bottom, 32)

                // Mode cards
                VStack(spacing: 14) {
                    ForEach(FingerMode.allCases) { mode in
                        let isSelected = viewModel.mode == .some(mode)
                        Button {
                            hapticImpact(.medium)
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                viewModel.mode = mode
                                viewModel.reset()
                            }
                            if mode != .classic {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.9).delay(0.08)) {
                                    showModeSelection = false
                                }
                            }
                        } label: {
                            HStack(alignment: .center, spacing: 18) {
                                ModeIllustrationView(mode: mode)
                                    .frame(width: 80, height: 80)
                                    .padding(.leading, 10)

                                VStack(alignment: .center, spacing: 6) {
                                    Text(lm.t(mode.titleKey))
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundStyle(gameFg)
                                        .multilineTextAlignment(.center)
                                    Text(lm.t(mode.descriptionKey))
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundStyle(gameFg.opacity(0.6))
                                        .lineSpacing(3)
                                        .multilineTextAlignment(.center)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)

                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(theme.primary)
                                        .frame(width: 22)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(isSelected ? theme.primary.opacity(0.15) : (isAtmosLight ? Color(hex: "1A1A2E").opacity(0.06) : Color.white.opacity(0.07)))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .stroke(isSelected ? theme.primary.opacity(0.5) : (isAtmosLight ? Color(hex: "1A1A2E").opacity(0.10) : Color.white.opacity(0.09)), lineWidth: 1.5)
                                    )
                            )
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.horizontal, 20)

                // Winner count picker + start button — shown when classic is selected
                if viewModel.mode == .some(.classic) {
                    VStack(spacing: 16) {
                        VStack(spacing: 10) {
                            Text(lm.t("finger.winners.title"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(gameFg.opacity(0.55))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 10) {
                                ForEach(1...4, id: \.self) { n in
                                    let isCountSelected = viewModel.winnerCount == n
                                    Button {
                                        hapticImpact(.light)
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            viewModel.winnerCount = n
                                        }
                                    } label: {
                                        Text("\(n)")
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundStyle(isCountSelected ? theme.primary : gameFg.opacity(0.5))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .fill(isCountSelected ? theme.primary.opacity(0.20) : (isAtmosLight ? Color(hex: "1A1A2E").opacity(0.05) : Color.white.opacity(0.06)))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                            .stroke(isCountSelected ? theme.primary.opacity(0.6) : (isAtmosLight ? Color(hex: "1A1A2E").opacity(0.10) : Color.white.opacity(0.08)), lineWidth: 1.5)
                                                    )
                                            )
                                    }
                                    .buttonStyle(PressableButtonStyle())
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCountSelected)
                                }
                            }
                        }

                        Button {
                            hapticImpact(.medium)
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                                showModeSelection = false
                            }
                        } label: {
                            Text(lm.t("finger.start"))
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(theme.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .shadow(color: theme.primary.opacity(0.3), radius: 10, y: 4)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()
            }
        }
    }

    private var modeBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: viewModel.mode?.systemImage ?? "hand.point.up.left.fill")
                .font(.system(size: 13, weight: .semibold))
            Text(lm.t(viewModel.mode?.titleKey ?? "finger.mode.classic"))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(gameFg.opacity(0.6))
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.08) : Color.white.opacity(0.10), in: Capsule())
    }

    private var resetButton: some View {
        Button { viewModel.reset() } label: {
            Image(systemName: "arrow.counterclockwise.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(gameFg.opacity(0.85))
                .shadow(color: Color(hex: "A855F7").opacity(0.8), radius: 20)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.85)))
    }
}

#else

// MARK: - Non-UIKit stub

struct FingerChooserView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var lm

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.point.up.left")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text(lm.t("finger.unsupported"))
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
            Button(lm.t("button.back")) { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding(40)
    }
}

#endif

#Preview {
    FingerChooserView()
}
