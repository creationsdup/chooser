import SwiftUI

// MARK: - Dice Types

enum DiceType: Int, CaseIterable, Identifiable {
    case d4 = 4, d6 = 6, d8 = 8, d10 = 10, d12 = 12, d20 = 20
    var id: Int { rawValue }
    var label: String { "D\(rawValue)" }
}

// MARK: - Die State

struct DieState: Identifiable {
    let id: Int
    var value: Int = 1
    /// Orthographic rotation around X axis (no perspective distortion)
    var rotX: Double = 0
    /// Orthographic rotation around Y axis (no perspective distortion)
    var rotY: Double = 0
    var scale: Double = 1.0
    var isRolling: Bool = false
    /// Hides dots/value during roll, fades in on settle
    var resultVisible: Bool = true
}

// MARK: - View Model

@Observable
final class DiceViewModel {
    var dice: [DieState] = [DieState(id: 0)]
    var diceType: DiceType = .d6
    var isRolling = false
    var total: Int? = nil

    var diceCount: Int { dice.count }

    func addDie() {
        guard dice.count < 6 else { return }
        dice.append(DieState(id: dice.count))
        total = nil
    }

    func removeDie() {
        guard dice.count > 1 else { return }
        dice.removeLast()
        total = nil
    }

    func roll(hapticsEnabled: Bool) {
        guard !isRolling else { return }
        isRolling = true
        total = nil

        if hapticsEnabled { hapticImpact(.heavy) }

        let count = dice.count
        let results = (0..<count).map { _ in Int.random(in: 1...diceType.rawValue) }

        // ── Phase 0: synchronous reset — no animation ──────────────────────
        for i in dice.indices {
            dice[i].rotX = 0
            dice[i].rotY = 0
            dice[i].scale = 1.0
            dice[i].isRolling = true
            dice[i].resultVisible = false
        }

        // ── Phase 1 & 2: animate from next run loop ─────────────────────────
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            for i in 0..<count {
                guard i < self.dice.count else { break }
                let delay = Double(i) * 0.09

                let spinsX = Double(Int.random(in: 4...6))
                let spinsY = Double(Int.random(in: 4...6))

                // Phase 1: brief lift on launch
                withAnimation(.easeOut(duration: 0.14).delay(delay)) {
                    self.dice[i].scale = 1.12
                }
                // Phase 2: tumble + natural deceleration
                // Always land at a multiple of 360° so the face is fully visible (not edge-on)
                withAnimation(.easeOut(duration: 1.0).delay(delay + 0.10)) {
                    self.dice[i].rotX = spinsX * 360
                    self.dice[i].rotY = spinsY * 360
                    self.dice[i].scale = 1.0
                }
            }
        }

        // ── Phase 3: reveal result ───────────────────────────────────────────
        let revealDelay = 1.25 + Double(count - 1) * 0.09
        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(Int(revealDelay * 1000)))
            for i in 0..<count {
                guard i < self.dice.count else { break }
                self.dice[i].value = results[i]
                self.dice[i].isRolling = false
                self.dice[i].resultVisible = true
            }
            total = results.reduce(0, +)
            isRolling = false
            if hapticsEnabled { hapticSuccess() }
        }
    }
}

// MARK: - Main View

struct DiceRollView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(LanguageManager.self) private var lm
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var isLandscape: Bool { verticalSizeClass == .compact }
    @State private var viewModel = DiceViewModel()

    var body: some View {
        ZStack {
            theme.backgroundGradient
            .ignoresSafeArea()

            if isLandscape {
                landscapeLayout
            } else {
                portraitLayout
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.total)
    }

    private var portraitLayout: some View {
        VStack(spacing: 0) {
            topBar
            diceControls
            Spacer()
            diceGrid
            Spacer()
            totalDisplay
            rollButton
        }
    }

    private var landscapeLayout: some View {
        VStack(spacing: 0) {
            topBar
            HStack(alignment: .center, spacing: 0) {
                diceGrid
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                VStack(spacing: 12) {
                    diceControls
                    Spacer()
                    totalDisplay
                    rollButton
                        .padding(.bottom, 16)
                }
                .padding(.horizontal, 16)
                .frame(width: 240)
            }
        }
    }

    // MARK: Sub-views

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            Spacer()
            Text(lm.t("mode.dice.title"))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            // balance
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }

    private var diceControls: some View {
        HStack(spacing: 20) {
            Button { viewModel.removeDie() } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(viewModel.diceCount <= 1 ? .white.opacity(0.25) : .white.opacity(0.8))
            }
            .disabled(viewModel.diceCount <= 1)

            Text("\(viewModel.diceCount) \(lm.t(viewModel.diceCount > 1 ? "dice.dice" : "dice.die"))")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(minWidth: 80)

            Button { viewModel.addDie() } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(viewModel.diceCount >= 6 ? .white.opacity(0.25) : .white.opacity(0.8))
            }
            .disabled(viewModel.diceCount >= 6)
        }
    }

    private var diceGrid: some View {
        let rows = diceRows(viewModel.dice)
        let spacing = diceSpacing(count: viewModel.diceCount)
        return VStack(spacing: spacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: spacing) {
                    ForEach(row) { die in
                        DieView(die: die, diceType: .d6)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: viewModel.diceCount)
    }

    private func diceRows(_ dice: [DieState]) -> [[DieState]] {
        switch dice.count {
        case 1:  return [dice]
        case 2:  return [dice]
        case 3:  return [[dice[0], dice[1]], [dice[2]]]
        case 4:  return [[dice[0], dice[1]], [dice[2], dice[3]]]
        case 5:  return [[dice[0], dice[1], dice[2]], [dice[3], dice[4]]]
        default: return [[dice[0], dice[1], dice[2]], [dice[3], dice[4], dice[5]]]
        }
    }

    private func diceSpacing(count: Int) -> CGFloat {
        switch count {
        case 1:  return 0
        case 2:  return 40
        case 3:  return 30
        case 4:  return 28
        case 5:  return 22
        default: return 18
        }
    }

    @ViewBuilder
    private var totalDisplay: some View {
        if let total = viewModel.total, viewModel.diceCount > 1 {
            VStack(spacing: 4) {
                Text(lm.t("dice.total"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(hex: "A1A1AA"))
                Text("\(total)")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .transition(.scale.combined(with: .opacity))
            .padding(.bottom, 8)
        }
    }

    private var rollButton: some View {
        Button { viewModel.roll(hapticsEnabled: hapticsEnabled) } label: {
            Label(
                viewModel.isRolling ? lm.t("dice.rolling") : lm.t("dice.roll"),
                systemImage: viewModel.isRolling ? "hourglass" : "die.face.5.fill"
            )
            .font(.system(size: 20, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(theme.primary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: theme.primary.opacity(0.38), radius: 12, y: 6)
        }
        .disabled(viewModel.isRolling)
        .buttonStyle(.pressable)
        .padding(.horizontal, isLandscape ? 0 : 30)
        .padding(.bottom, isLandscape ? 0 : 44)
    }
}

// MARK: - Die View

struct DieView: View {
    let die: DieState
    let diceType: DiceType

    var body: some View {
        ZStack {
            if diceType == .d6 {
                D6FaceView(value: die.value, resultVisible: die.resultVisible)
            } else {
                PolygonDieView(
                    value: die.value,
                    sides: diceType.rawValue,
                    color: dieColor,
                    resultVisible: die.resultVisible
                )
            }
        }
        .frame(width: 100, height: 100)
        .scaleEffect(die.scale)
        // perspective: 0 = orthographic projection → uniform compression, no asymmetric distortion
        .rotation3DEffect(.degrees(die.rotX), axis: (x: 1, y: 0, z: 0), perspective: 0)
        .rotation3DEffect(.degrees(die.rotY), axis: (x: 0, y: 1, z: 0), perspective: 0)
        .shadow(
            color: dieColor.opacity(die.isRolling ? 0.65 : 0.4),
            radius: die.isRolling ? 18 : 8,
            y: die.isRolling ? 14 : 4
        )
        .animation(.easeOut(duration: 0.3), value: die.isRolling)
    }

    private var dieColor: Color {
        switch diceType {
        case .d4:  return Color(hex: "4ECDC4")
        case .d6:  return Color(hex: "10B981")
        case .d8:  return Color(hex: "3B82F6")
        case .d10: return Color(hex: "A855F7")
        case .d12: return Color(hex: "EC4899")
        case .d20: return Color(hex: "F59E0B")
        }
    }
}

// MARK: - D6 Face

struct D6FaceView: View {
    let value: Int
    let resultVisible: Bool

    private static let dotLayout: [Int: [(Double, Double)]] = [
        1: [(0.5, 0.5)],
        2: [(0.25, 0.75), (0.75, 0.25)],
        3: [(0.25, 0.75), (0.5, 0.5), (0.75, 0.25)],
        4: [(0.25, 0.25), (0.75, 0.25), (0.25, 0.75), (0.75, 0.75)],
        5: [(0.25, 0.25), (0.75, 0.25), (0.5, 0.5), (0.25, 0.75), (0.75, 0.75)],
        6: [(0.25, 0.2), (0.75, 0.2), (0.25, 0.5), (0.75, 0.5), (0.25, 0.8), (0.75, 0.8)]
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: "F0FFF4"), .white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.black.opacity(0.08), lineWidth: 1.5)

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let dots = Self.dotLayout[value] ?? []
                ForEach(Array(dots.enumerated()), id: \.0) { _, pos in
                    Circle()
                        .fill(Color(hex: "1A3A2A"))
                        .frame(width: 14, height: 14)
                        .position(x: pos.0 * w, y: pos.1 * h)
                }
            }
            .opacity(resultVisible ? 1 : 0)
            .animation(.easeIn(duration: 0.2), value: resultVisible)
        }
    }
}

// MARK: - Polygon Die Face

struct PolygonDieView: View {
    let value: Int
    let sides: Int
    let color: Color
    let resultVisible: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [color, color.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            // Die type label — always visible as an identifier
            Text("D\(sides)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .offset(y: -15)

            Text("\(value)")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .opacity(resultVisible ? 1 : 0)
                .animation(.easeIn(duration: 0.2), value: resultVisible)
        }
    }
}

#Preview {
    DiceRollView()
}
