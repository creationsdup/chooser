import SwiftUI

// MARK: - Model

enum CoinSide: Equatable {
    case heads, tails

    var labelKey: String {
        switch self {
        case .heads: return "coinflip.heads"
        case .tails: return "coinflip.tails"
        }
    }

    var emoji: String {
        switch self {
        case .heads: return "😎"
        case .tails: return "🌟"
        }
    }
}

// MARK: - View Model

@Observable
final class CoinFlipViewModel {
    var spinAngle: Double = 0      // Y-axis spin for visual effect only
    var offsetY: CGFloat = 0
    var showingFront: Bool = true  // which face is actually displayed
    var isFlipping = false
    var result: CoinSide? = nil

    func flip(hapticsEnabled: Bool) {
        guard !isFlipping else { return }
        isFlipping = true
        result = nil

        let winner: CoinSide = Int.random(in: 0...1) == 0 ? .heads : .tails

        if hapticsEnabled { hapticImpact(.heavy) }

        // Phase 1 — throw up with a fast spin
        withAnimation(.easeOut(duration: 0.55)) {
            offsetY = -360
        }
        withAnimation(.linear(duration: 0.55)) {
            spinAngle += Double(Int.random(in: 3...5)) * 360
        }

        Task {
            // Coin is off-screen at the peak — swap face here, no one sees it
            try? await Task.sleep(for: .milliseconds(540))
            showingFront = winner == .heads

            // Phase 2 — fall back down with a slower spin
            withAnimation(.easeIn(duration: 0.8)) {
                offsetY = 0
            }
            withAnimation(.easeIn(duration: 0.8)) {
                spinAngle += Double(Int.random(in: 2...4)) * 360
            }

            try? await Task.sleep(for: .milliseconds(820))
            result = winner
            isFlipping = false
            if hapticsEnabled { hapticSuccess() }
        }
    }

    func reset() {
        result = nil
        showingFront = true
    }
}

// MARK: - View

struct CoinFlipView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(LanguageManager.self) private var lm
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var isLandscape: Bool { verticalSizeClass == .compact }
    @State private var viewModel = CoinFlipViewModel()
    // Gentle idle float — makes the coin feel alive when nothing is happening
    @State private var idleFloat: CGFloat = 0

    // Shadow shrinks and fades as the coin rises
    private var shadowProgress: CGFloat {
        max(0.1, 1.0 + viewModel.offsetY / 360.0)
    }

    private func doFlip() {
        guard !viewModel.isFlipping else { return }
        if viewModel.result != nil {
            viewModel.reset()
        } else {
            viewModel.flip(hapticsEnabled: hapticsEnabled)
        }
    }

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
    }

    // MARK: - Portrait Layout

    private var portraitLayout: some View {
        ZStack {
            // Background hint — visible only when idle
            VStack {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 22, weight: .bold))
                    Text(lm.t("coinflip.hint"))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(theme.primary.opacity(0.55))
                .padding(.bottom, 60)
            }
            .opacity(viewModel.isFlipping || viewModel.result != nil ? 0 : 1)
            .animation(.easeInOut(duration: 0.3), value: viewModel.isFlipping || viewModel.result != nil)

            VStack(spacing: 0) {
                topBar.padding(.bottom, 30)
                Spacer()
                resultDisplay(fontSize: 44).frame(height: 90)
                coinSection(height: 300)
                Spacer()
                Spacer()
            }
        }
    }

    // MARK: - Landscape Layout

    private var landscapeLayout: some View {
        VStack(spacing: 0) {
            topBar.padding(.bottom, 8)
            HStack(alignment: .center, spacing: 0) {
                // Left: coin
                coinSection(height: 220)
                    .frame(maxWidth: .infinity)

                // Right: result + hint
                VStack(spacing: 16) {
                    Spacer()
                    resultDisplay(fontSize: 32)
                    if !viewModel.isFlipping && viewModel.result == nil {
                        VStack(spacing: 6) {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 18, weight: .bold))
                            Text(lm.t("coinflip.hint"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(theme.primary.opacity(0.55))
                    }
                    Spacer()
                }
                .frame(width: 200)
            }
        }
    }

    // MARK: - Shared Sub-views

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
            Text(lm.t("mode.coinFlip.title"))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private func resultDisplay(fontSize: CGFloat) -> some View {
        Group {
            if let result = viewModel.result {
                VStack(spacing: 12) {
                    Text(result.emoji)
                        .font(.system(size: fontSize * 0.9))
                    Text(lm.t(result.labelKey))
                        .font(.system(size: fontSize, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Color.clear
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.result != nil)
    }

    private func coinSection(height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Circle()
                .fill(theme.primary.opacity(0.15))
                .frame(width: height * 0.87, height: height * 0.87)
                .blur(radius: 20)
                .opacity(shadowProgress)

            Ellipse()
                .fill(.black.opacity(0.35 * shadowProgress))
                .frame(width: 160 * shadowProgress, height: 18 * shadowProgress)
                .blur(radius: 8)
                .offset(y: height * 0.37)

            coinView
                .rotation3DEffect(.degrees(viewModel.spinAngle), axis: (0, 1, 0), perspective: 0.3)
                .offset(y: viewModel.offsetY + (!viewModel.isFlipping && viewModel.result == nil ? idleFloat : 0))
                .scaleEffect((isLandscape ? 0.72 : 1.0) * (0.85 + 0.15 * shadowProgress))
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            let isSwipeUp = value.translation.height < -40
                                && abs(value.translation.height) > abs(value.translation.width)
                            if isSwipeUp { doFlip() }
                        }
                )
                .onTapGesture { doFlip() }
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 2.4).repeatForever(autoreverses: true)
                    ) { idleFloat = -9 }
                }
        }
        .frame(height: height)
    }

    private var coinView: some View {
        ZStack {
            // ── FACE side ─────────────────────────────────────────────────
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "FFD700"), Color(hex: "FFA500"), Color(hex: "FF8C00")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 200, height: 200)
                .overlay {
                    // Rim
                    Circle()
                        .stroke(Color(hex: "FFE55C").opacity(0.6), lineWidth: 6)
                        .padding(6)
                }
                .overlay {
                    ZStack {
                        // Sun rays
                        ForEach(0..<12, id: \.self) { i in
                            Capsule()
                                .fill(Color(hex: "FF8C00").opacity(0.35))
                                .frame(width: 3, height: 28)
                                .offset(y: -66)
                                .rotationEffect(.degrees(Double(i) * 30))
                        }
                        // Crown
                        Image(systemName: "crown.fill")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "7A4500"), Color(hex: "4A2800")],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .offset(y: -12)
                        // FACE label
                        Text(lm.t("coinflip.heads"))
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .tracking(5)
                            .foregroundStyle(Color(hex: "7A4500").opacity(0.9))
                            .offset(y: 46)
                        // Three dots ornament
                        HStack(spacing: 6) {
                            ForEach(0..<3) { _ in
                                Circle()
                                    .fill(Color(hex: "7A4500").opacity(0.5))
                                    .frame(width: 5, height: 5)
                            }
                        }
                        .offset(y: 64)
                    }
                }
                .shadow(color: Color(hex: "F59E0B").opacity(0.6), radius: 16)
                .opacity(viewModel.showingFront ? 1 : 0)

            // ── PILE side ─────────────────────────────────────────────────
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "D4AF37"), Color(hex: "B8860B"), Color(hex: "A0740A")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 200, height: 200)
                .overlay {
                    // Rim
                    Circle()
                        .stroke(Color(hex: "C8A830").opacity(0.6), lineWidth: 6)
                        .padding(6)
                }
                .overlay {
                    ZStack {
                        // Outer concentric ring
                        Circle()
                            .stroke(Color(hex: "8B6200").opacity(0.3), lineWidth: 1.5)
                            .frame(width: 130, height: 130)
                        // Shield
                        Image(systemName: "shield.fill")
                            .font(.system(size: 62))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "6B4400"), Color(hex: "3A2200")],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .offset(y: -4)
                        // Star on shield
                        Image(systemName: "star.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color(hex: "D4AF37").opacity(0.9))
                            .offset(y: -8)
                        // PILE label
                        Text(lm.t("coinflip.tails"))
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .tracking(5)
                            .foregroundStyle(Color(hex: "6B4400").opacity(0.9))
                            .offset(y: 46)
                        // Line ornament
                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(Color(hex: "6B4400").opacity(0.4))
                                .frame(width: 18, height: 1)
                            Circle()
                                .fill(Color(hex: "6B4400").opacity(0.5))
                                .frame(width: 4, height: 4)
                            Rectangle()
                                .fill(Color(hex: "6B4400").opacity(0.4))
                                .frame(width: 18, height: 1)
                        }
                        .offset(y: 64)
                    }
                }
                .rotation3DEffect(.degrees(180), axis: (0, 1, 0))
                .opacity(viewModel.showingFront ? 0 : 1)
        }
    }
}

#Preview {
    CoinFlipView()
}
