import SwiftUI

// MARK: - View Model

@Observable
final class NumberRouletteViewModel {
    var minValue: Int = 1
    var maxValue: Int = 9999
    var isSpinning = false
    var spinTrigger: Int = 0
    var targetDigits: [Int] = [0, 0, 0, 0]

    var rangeIsValid: Bool { minValue < maxValue }

    func spin(hapticsEnabled: Bool) {
        guard !isSpinning, rangeIsValid else { return }
        isSpinning = true

        let target = Int.random(in: minValue...maxValue)
        let s = String(format: "%04d", min(target, 9999))
        targetDigits = s.compactMap { $0.wholeNumberValue }

        if hapticsEnabled { hapticImpact(.heavy) }
        spinTrigger += 1

        // All 4 reels finish within ~3.8s (last reel delay 0.75 + animation ~3.0)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4.2))
            self.isSpinning = false
            if hapticsEnabled { hapticSuccess() }
        }
    }

    func reset() {
        isSpinning = false
        spinTrigger = 0
        targetDigits = [0, 0, 0, 0]
    }
}

// MARK: - Focus Fields

private enum NumberField: Hashable { case min, max }

// MARK: - Main Screen

struct NumberRouletteView: View {
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

    @State private var viewModel = NumberRouletteViewModel()
    @FocusState private var focusedField: NumberField?
    @State private var leverPulled = false
    @State private var showModePicker = false

    var body: some View {
        ZStack {
            GameBackgroundView(theme: theme, appearance: appearance, colorScheme: colorScheme)

            if isLandscape {
                landscapeLayout
            } else {
                portraitLayout
            }
        }
        .onTapGesture { focusedField = nil }
        .fullScreenCover(isPresented: $showModePicker) {
            NumberModePickerSheet()
                .preferredColorScheme(appearance.resolvedScheme)
        }
    }

    private var portraitLayout: some View {
        VStack(spacing: 0) {
            headerBar
                .padding(.top, 8)
            Spacer().frame(height: 28)
            rangeRow
                .padding(.horizontal, 36)
            Spacer()
            machineRow
            Spacer()
            startButton
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
        }
    }

    private var landscapeLayout: some View {
        VStack(spacing: 0) {
            headerBar.padding(.top, 4)
            HStack(alignment: .center, spacing: 0) {
                // Left: slot machine
                machineRow
                    .frame(maxWidth: .infinity)

                // Right: range + button
                VStack(spacing: 0) {
                    Spacer()
                    rangeRow
                        .padding(.horizontal, 20)
                    Spacer()
                    startButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
                .frame(width: 280)
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
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
            .padding(.leading, 20)

            Spacer()

            Text(lm.t("mode.numberRoulette.title"))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(gameFg)
                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)

            Spacer()

            Button { showModePicker = true } label: {
                ZStack {
                    Circle()
                        .fill(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.08) : Color.white.opacity(0.22))
                        .frame(width: 42, height: 42)
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(gameFg)
                }
            }
            .padding(.trailing, 20)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Range Row

    private var rangeRow: some View {
        HStack(spacing: 16) {
            BoundTextField(
                value: $viewModel.minValue,
                focusState: $focusedField,
                fieldTag: NumberField.min
            )
            .onChange(of: viewModel.minValue) { _, new in
                if new >= viewModel.maxValue { viewModel.maxValue = new + 1 }
            }

            Text("–")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(gameFg)

            BoundTextField(
                value: $viewModel.maxValue,
                focusState: $focusedField,
                fieldTag: NumberField.max
            )
            .onChange(of: viewModel.maxValue) { _, new in
                if new <= viewModel.minValue { viewModel.minValue = new - 1 }
            }
        }
    }

    // MARK: - Machine Row

    private var machineRow: some View {
        HStack(alignment: .center, spacing: -14) {
            Spacer(minLength: 0)

            SlotMachineView(
                targetDigits: viewModel.targetDigits,
                spinTrigger: viewModel.spinTrigger,
                numberColor: theme.primary,
                numberColorEnd: theme.paletteColors.last ?? theme.primary.opacity(0.75)
            )

            LeverView(isPulled: leverPulled)
                .offset(y: 6)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button {
            focusedField = nil
            guard !viewModel.isSpinning, viewModel.rangeIsValid else { return }
            // Animate the lever pull before spinning
            leverPulled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { leverPulled = false }
            viewModel.spin(hapticsEnabled: hapticsEnabled)
        } label: {
            Text(viewModel.isSpinning ? lm.t("state.inProgress") : lm.t("button.start"))
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(theme.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(.white, in: Capsule())
                .shadow(color: .black.opacity(0.20), radius: 12, y: 6)
        }
        .disabled(viewModel.isSpinning || !viewModel.rangeIsValid)
        .buttonStyle(.pressable)
        .opacity((viewModel.isSpinning || !viewModel.rangeIsValid) ? 0.65 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: viewModel.isSpinning)
    }
}

// MARK: - Slot Machine Body

struct SlotMachineView: View {
    let targetDigits: [Int]   // always 4 elements
    let spinTrigger: Int
    var numberColor: Color = Color(hex: "FF2D55")
    var numberColorEnd: Color = Color(hex: "FF6600")

    private let reelW:   CGFloat = 62
    private let reelH:   CGFloat = 84
    private let reelGap: CGFloat = 7
    private let padH:    CGFloat = 14   // horizontal padding inside frame
    private let padV:    CGFloat = 12   // vertical padding inside frame

    private var frameW: CGFloat { 4 * reelW + 3 * reelGap + 2 * padH }
    private var frameH: CGFloat { reelH + 2 * padV }

    var body: some View {
        ZStack {
            // ── Outer metallic shell ──────────────────────────────────
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "E8E8EA"),
                            Color(hex: "9E9EA2"),
                            Color(hex: "D2D2D6"),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.32), radius: 16, y: 8)

            // ── Inner dark cavity ─────────────────────────────────────
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: "2E0E0E"))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

            // ── Reels ─────────────────────────────────────────────────
            HStack(spacing: reelGap) {
                ForEach(0..<4, id: \.self) { i in
                    DigitReelView(
                        targetDigit: targetDigits[i],
                        spinTrigger: spinTrigger,
                        delay: Double(i) * 0.25,
                        numberColor: numberColor,
                        numberColorEnd: numberColorEnd
                    )
                    .frame(width: reelW, height: reelH)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(Color(hex: "1A0808"), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.45), radius: 5, y: 3)
                }
            }

            // ── Top sheen ─────────────────────────────────────────────
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.50), .clear],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.42)
                    )
                )
                .allowsHitTesting(false)

            // ── Bottom depth ──────────────────────────────────────────
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.18)],
                        startPoint: UnitPoint(x: 0.5, y: 0.65),
                        endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)
        }
        .frame(width: frameW, height: frameH)
    }
}

// MARK: - Digit Reel

struct DigitReelView: View {
    let targetDigit: Int
    let spinTrigger: Int
    let delay: Double
    var numberColor: Color = Color(hex: "FF2D55")
    var numberColorEnd: Color = Color(hex: "FF6600")

    // Height of each digit cell — must match SlotMachineView.reelH
    private let cellH: CGFloat = 84

    @State private var stripOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Reel background
            Color(hex: "F7F5F0")

            // Vertical strip of 50 digits (0–9 × 5 repetitions) scrolled by offset
            GeometryReader { geo in
                VStack(spacing: 0) {
                    ForEach(0..<50, id: \.self) { i in
                        Text("\(i % 10)")
                            .font(.system(size: 46, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [numberColor, numberColorEnd],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: geo.size.width, height: cellH)
                    }
                }
                .offset(y: stripOffset)
            }
            .clipped()

            // Top shadow — depth illusion
            LinearGradient(
                colors: [.black.opacity(0.22), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.38)
            )
            .allowsHitTesting(false)

            // Bottom shadow
            LinearGradient(
                colors: [.clear, .black.opacity(0.22)],
                startPoint: UnitPoint(x: 0.5, y: 0.62),
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .onChange(of: spinTrigger) { _, newTrigger in
            guard newTrigger > 0 else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                await spinToTarget()
            }
        }
    }

    // Single smooth animation: fast start → sharp deceleration → lands on target
    @MainActor
    private func spinToTarget() async {
        // Normalize to same visible digit in repetition 0 — snap is invisible because
        // the digit shown before and after normalization is identical.
        let currentIndex = max(0, Int((-stripOffset / cellH).rounded()))
        let currentDigit = currentIndex % 10
        let normalizedOffset = -CGFloat(currentDigit) * cellH
        stripOffset = normalizedOffset

        // Per-reel stagger delay
        try? await Task.sleep(for: .seconds(delay))

        // Scroll forward 3 full rotations + however many steps reach the target.
        // Maximum totalSteps = 39, max |finalOffset| = 4800 — fits within 50-item strip.
        let stepsForward = (targetDigit - currentDigit + 10) % 10
        let totalSteps = 30 + stepsForward
        let finalOffset = normalizedOffset - CGFloat(totalSteps) * cellH

        // Cubic bezier: very fast scroll that brakes hard at the end
        withAnimation(.timingCurve(0.12, 0.85, 0.25, 1.0, duration: 3.0)) {
            stripOffset = finalOffset
        }
    }
}

// MARK: - Lever

struct LeverView: View {
    let isPulled: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Rotating part: ball + pole ────────────────────────────
            VStack(spacing: 0) {
                // ── Ball handle ───────────────────────────────────────
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: "FF7090"), Color(hex: "E8002A")],
                                center: UnitPoint(x: 0.35, y: 0.28),
                                startRadius: 0,
                                endRadius: 15
                            )
                        )
                        .frame(width: 30, height: 30)
                        .shadow(color: .black.opacity(0.32), radius: 5, y: 3)

                    // Specular highlight
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.55), .clear],
                                center: UnitPoint(x: 0.35, y: 0.28),
                                startRadius: 0,
                                endRadius: 9
                            )
                        )
                        .frame(width: 30, height: 30)
                }

                // ── Pole ──────────────────────────────────────────────
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "E2E2E2"),
                                Color(hex: "989898"),
                                Color(hex: "DEDEDE"),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 12, height: 68)
                    .shadow(color: .black.opacity(0.22), radius: 3, y: 2)
            }
            .rotationEffect(.degrees(isPulled ? 28 : 0), anchor: .bottom)
            .animation(.spring(response: 0.24, dampingFraction: 0.52), value: isPulled)

            // ── Pivot pin — the mount screw on the machine wall ───────
            ZStack {
                Circle()
                    .fill(Color(hex: "3A3A3C"))
                    .frame(width: 20, height: 20)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "A0A0A8"), Color(hex: "4A4A52")],
                            center: UnitPoint(x: 0.35, y: 0.28),
                            startRadius: 0,
                            endRadius: 10
                        )
                    )
                    .frame(width: 14, height: 14)
            }
            .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
        }
    }
}

// MARK: - Bound Text Field

struct BoundTextField<F: Hashable>: View {
    @Binding var value: Int
    var focusState: FocusState<F?>.Binding
    var fieldTag: F
    @Environment(LanguageManager.self) private var lm
    @Environment(AppearanceManager.self) private var appearance
    @Environment(\.colorScheme) private var colorScheme
    private var isAtmosLight: Bool { appearance.visualStyle == .atmos && colorScheme == .light }
    private var gameFg: Color { isAtmosLight ? Color(hex: "1A1A2E") : .white }

    @State private var editingText = ""

    var body: some View {
        TextField("", text: $editingText)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(gameFg)
            .multilineTextAlignment(.center)
            .keyboardType(.numberPad)
            .focused(focusState, equals: fieldTag)
            .frame(minWidth: 90)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.08) : Color.white.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.35) : Color.white.opacity(0.55), lineWidth: 1.5)
                    )
            )
            .onAppear { editingText = "\(value)" }
            .onChange(of: value) { _, new in
                if focusState.wrappedValue != fieldTag { editingText = "\(new)" }
            }
            .onChange(of: focusState.wrappedValue) { _, newFocus in
                // On focus loss: commit the typed text then normalize display.
                // Deferring to focus-loss (instead of every keystroke) avoids
                // re-rendering the parent view on each character typed.
                if newFocus != fieldTag {
                    if let parsed = Int(editingText) { value = parsed }
                    editingText = "\(value)"
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if focusState.wrappedValue == fieldTag {
                        Spacer()
                        Button(lm.t("button.done")) { focusState.wrappedValue = nil }
                            .fontWeight(.semibold)
                    }
                }
            }
    }
}

// MARK: - Preview

#Preview {
    NumberRouletteView()
}
