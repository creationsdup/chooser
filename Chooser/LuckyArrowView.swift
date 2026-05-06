import SwiftUI

// MARK: - Sub-mode

private enum ArrowSubMode: CaseIterable {
    case arrow, bottle

    var labelKey: String {
        switch self {
        case .arrow:  return "arrow.submode.arrow"
        case .bottle: return "arrow.submode.bottle"
        }
    }
}

// MARK: - View Model

@Observable
final class LuckyArrowViewModel {
    var rotation: Double = 0
    var isSpinning = false
    var hasResult = false

    func spin(hapticsEnabled: Bool) {
        guard !isSpinning else { return }
        isSpinning = true
        hasResult = false

        if hapticsEnabled { hapticImpact(.heavy) }

        // Fixed 8 full turns + uniform random stop — consistent speed every spin
        let targetRotation = rotation + 8 * 360 + Double.random(in: 0..<360)
        rotation = targetRotation

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5.15))
            self.isSpinning = false
            self.hasResult = true
            // Normalize to keep value small, no visual change
            self.rotation = self.rotation.truncatingRemainder(dividingBy: 360)
            if hapticsEnabled { hapticSuccess() }
        }
    }
}

// MARK: - Arrow Shape (points upward at rotation 0)

private struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let length: CGFloat = min(rect.width, rect.height) * 0.43
        let headWidth: CGFloat = 28
        let headHeight: CGFloat = 40
        let bodyWidth: CGFloat = 12
        let tailY = cy + length * 0.30

        var path = Path()
        path.move(to: CGPoint(x: cx, y: cy - length))                            // tip
        path.addLine(to: CGPoint(x: cx + headWidth / 2, y: cy - length + headHeight)) // right shoulder
        path.addLine(to: CGPoint(x: cx + bodyWidth / 2, y: cy - length + headHeight)) // right body top
        path.addLine(to: CGPoint(x: cx + bodyWidth / 2, y: tailY))               // right body bottom
        // Tail notch
        path.addLine(to: CGPoint(x: cx + headWidth / 2.5, y: tailY + 10))
        path.addLine(to: CGPoint(x: cx, y: tailY + 2))
        path.addLine(to: CGPoint(x: cx - headWidth / 2.5, y: tailY + 10))
        path.addLine(to: CGPoint(x: cx - bodyWidth / 2, y: tailY))               // left body bottom
        path.addLine(to: CGPoint(x: cx - bodyWidth / 2, y: cy - length + headHeight)) // left body top
        path.addLine(to: CGPoint(x: cx - headWidth / 2, y: cy - length + headHeight)) // left shoulder
        path.closeSubpath()
        return path
    }
}

// MARK: - Bottle Shape (horizontal, mouth pointing right at rotation 0)

private struct BottleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let s = rect.width / 200.0

        // x offsets from center
        let capCX: CGFloat  = -78 * s  // center of the round cap (left end)
        let bodyRX: CGFloat =  20 * s  // shoulder start
        let neckSX: CGFloat =  42 * s  // neck start
        let lipSX: CGFloat  =  66 * s  // lip start
        let mouthX: CGFloat =  80 * s  // mouth end (rightmost)

        let bodyR: CGFloat = 18 * s
        let neckR: CGFloat =  8 * s
        let lipR: CGFloat  = 11 * s

        var path = Path()

        // Upper outline
        path.move(to: CGPoint(x: cx + capCX, y: cy - bodyR))
        path.addLine(to: CGPoint(x: cx + bodyRX, y: cy - bodyR))
        // Upper shoulder curve (body → neck)
        path.addCurve(
            to: CGPoint(x: cx + neckSX, y: cy - neckR),
            control1: CGPoint(x: cx + bodyRX + 14 * s, y: cy - bodyR),
            control2: CGPoint(x: cx + neckSX - 4 * s,  y: cy - neckR)
        )
        path.addLine(to: CGPoint(x: cx + lipSX, y: cy - neckR))
        // Mouth lip upper (neck → rounded mouth tip)
        path.addCurve(
            to: CGPoint(x: cx + mouthX, y: cy),
            control1: CGPoint(x: cx + lipSX + 6 * s, y: cy - neckR),
            control2: CGPoint(x: cx + mouthX, y: cy - lipR)
        )

        // Lower outline (mirror)
        path.addCurve(
            to: CGPoint(x: cx + lipSX, y: cy + neckR),
            control1: CGPoint(x: cx + mouthX, y: cy + lipR),
            control2: CGPoint(x: cx + lipSX + 6 * s, y: cy + neckR)
        )
        path.addLine(to: CGPoint(x: cx + neckSX, y: cy + neckR))
        // Lower shoulder curve (neck → body)
        path.addCurve(
            to: CGPoint(x: cx + bodyRX, y: cy + bodyR),
            control1: CGPoint(x: cx + neckSX - 4 * s,  y: cy + neckR),
            control2: CGPoint(x: cx + bodyRX + 14 * s, y: cy + bodyR)
        )
        path.addLine(to: CGPoint(x: cx + capCX, y: cy + bodyR))

        // Round cap on the left (bottom of bottle)
        path.addArc(
            center: CGPoint(x: cx + capCX, y: cy),
            radius: bodyR,
            startAngle: .degrees(90),
            endAngle: .degrees(270),
            clockwise: false
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - Main View

struct LuckyArrowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(LanguageManager.self) private var lm
    @Environment(AppearanceManager.self) private var appearance
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var isLandscape: Bool { verticalSizeClass == .compact }
    private var isAtmosLight: Bool { appearance.visualStyle == .atmos && colorScheme == .light }
    private var gameFg: Color { isAtmosLight ? Color(hex: "1A1A2E") : .white }

    @State private var viewModel = LuckyArrowViewModel()
    @State private var subMode: ArrowSubMode = .arrow
    // Breathing glow — pulses softly when idle to make the disc feel alive
    @State private var glowOpacity: Double = 0.14

    var body: some View {
        ZStack {
            GameBackgroundView(theme: theme, appearance: appearance, colorScheme: colorScheme)

            if isLandscape {
                landscapeLayout
            } else {
                portraitLayout
            }
        }
        .onAppear {
            guard !appearance.animationsReduced else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                glowOpacity = 0.32
            }
        }
    }

    private var portraitLayout: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.top, 8)
            subModePicker
            Spacer()
            spinnerContent
            Spacer()
            spinButton
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var landscapeLayout: some View {
        VStack(spacing: 0) {
            topBar.padding(.top, 4)
            subModePicker.padding(.bottom, 4)
            HStack(alignment: .center, spacing: 0) {
                // Left: spinner disc, scaled to fit available space
                GeometryReader { geo in
                    let scale = min(geo.size.width, geo.size.height) / 400.0 * 0.92
                    ZStack {
                        spinnerContent
                            .scaleEffect(scale)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .frame(maxWidth: .infinity)

                // Right: spin button
                VStack {
                    Spacer()
                    spinButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
                .frame(width: 240)
            }
        }
    }

    // MARK: Sub-mode Picker

    private var subModePicker: some View {
        HStack(spacing: 4) {
            ForEach(ArrowSubMode.allCases, id: \.self) { mode in
                Button {
                    guard !viewModel.isSpinning else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        subMode = mode
                        viewModel.rotation = 0
                        viewModel.hasResult = false
                    }
                } label: {
                    Text(lm.t(mode.labelKey))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(subMode == mode ? theme.primary : gameFg.opacity(0.75))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 22)
                        .background(
                            Capsule()
                                .fill(subMode == mode ? .white : .clear)
                        )
                }
                .buttonStyle(.plain)
                .opacity(viewModel.isSpinning ? 0.45 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: viewModel.isSpinning)
            }
        }
        .padding(4)
        .background(Capsule().fill(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.08) : Color.white.opacity(0.15)))
        .padding(.horizontal, 48)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    // MARK: Top Bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                ZStack {
                    Circle()
                        .fill(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.08) : Color.white.opacity(0.22))
                        .frame(width: 42, height: 42)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(gameFg)
                }
            }
            .accessibilityLabel(lm.t("button.back"))
            .padding(.leading, 20)

            Spacer()

            Text(lm.t("mode.luckyArrow.title"))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(gameFg)
                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)

            Spacer()

            Color.clear.frame(width: 42, height: 42)
                .padding(.trailing, 20)
        }
        .padding(.vertical, 6)
    }

    // MARK: Spinner Content

    @ViewBuilder
    private var spinnerContent: some View {
        switch subMode {
        case .arrow:  arrowDisc
        case .bottle: bottleDisc
        }
    }

    // MARK: Arrow Disc

    private var arrowDisc: some View {
        ZStack {
            // Breathing glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [theme.primary.opacity(glowOpacity), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .blur(radius: 30)

            // Outer ring
            Circle()
                .stroke(.white.opacity(0.18), lineWidth: 1.5)
                .frame(width: 302, height: 302)

            // Main soft disc
            Circle()
                .fill(.white.opacity(0.16))
                .frame(width: 286, height: 286)

            // Tick marks
            ForEach(0..<12, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.white.opacity(i % 3 == 0 ? 0.6 : 0.28))
                    .frame(width: 2, height: i % 3 == 0 ? 14 : 8)
                    .offset(y: -130)
                    .rotationEffect(.degrees(Double(i) * 30))
            }

            // Arrow
            ArrowShape()
                .fill(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.88)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.22), radius: 8, y: 4)
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(viewModel.rotation))
                .animation(viewModel.isSpinning ? .timingCurve(0.15, 0.85, 0.25, 1.0, duration: 5.0) : .none, value: viewModel.rotation)

            // Center pin
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.95), theme.primary],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: 12
                    )
                )
                .frame(width: 24, height: 24)
                .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
        }
    }

    // MARK: Bottle Disc

    private var bottleDisc: some View {
        ZStack {
            // Breathing glow (pink/party vibe)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "FF2D78").opacity(glowOpacity), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .blur(radius: 30)

            // Bottle (rotates around its center)
            ZStack {
                // Soft drop shadow layer
                BottleShape()
                    .fill(.black.opacity(0.30))
                    .blur(radius: 10)
                    .offset(y: 8)

                // Body — deep wine-bottle green
                BottleShape()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "2E7D45"), Color(hex: "0A2E14")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Inner edge shading — gives the bottle volume
                BottleShape()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.28)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Primary glass highlight — bright vertical stripe near top-left
                BottleShape()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.55), .white.opacity(0.0)],
                            startPoint: UnitPoint(x: 0.15, y: 0.0),
                            endPoint: UnitPoint(x: 0.45, y: 0.55)
                        )
                    )

                // Secondary specular — thin bright line at very top
                BottleShape()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.30), .clear],
                            startPoint: .top,
                            endPoint: UnitPoint(x: 0.5, y: 0.22)
                        )
                    )

                // Dark rim outline
                BottleShape()
                    .stroke(Color(hex: "061A0B"), lineWidth: 2)

                // Light inner rim highlight
                BottleShape()
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
            .frame(width: 260, height: 74)
            .rotationEffect(.degrees(viewModel.rotation))
            .animation(viewModel.isSpinning ? .timingCurve(0.15, 0.85, 0.25, 1.0, duration: 5.0) : .none, value: viewModel.rotation)

            // Center pin
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.95), Color(hex: "FF2D78")],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: 12
                    )
                )
                .frame(width: 24, height: 24)
                .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
        }
    }

    // MARK: Spin Button

    private var spinButton: some View {
        Button {
            viewModel.spin(hapticsEnabled: hapticsEnabled)
        } label: {
            HStack(spacing: 10) {
                if viewModel.isSpinning {
                    ProgressView().tint(theme.primary).scaleEffect(0.85)
                } else {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(theme.primary)
                }
                Text(viewModel.isSpinning
                     ? lm.t("arrow.spinning")
                     : (subMode == .bottle ? lm.t("bottle.spin.button") : lm.t("button.start")))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(theme.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(.white, in: Capsule())
            .shadow(color: .black.opacity(0.20), radius: 12, y: 6)
        }
        .disabled(viewModel.isSpinning)
        .buttonStyle(.pressable)
        .opacity(viewModel.isSpinning ? 0.65 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.65), value: viewModel.isSpinning)
    }
}

// MARK: - Preview

#Preview {
    LuckyArrowView()
}
