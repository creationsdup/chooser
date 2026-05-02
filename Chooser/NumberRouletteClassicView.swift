import SwiftUI

// MARK: - Focus Fields

private enum ClassicField: Hashable { case min, max }

// MARK: - View Model

@Observable
final class NumberRouletteClassicViewModel {
    var minValue: Int = 1
    var maxValue: Int = 100
    var displayedNumber: Int = 50
    var result: Int? = nil
    var isSpinning = false

    var rangeIsValid: Bool { minValue < maxValue }

    func spin(hapticsEnabled: Bool) {
        guard !isSpinning, rangeIsValid else { return }
        isSpinning = true
        result = nil
        let target = Int.random(in: minValue...maxValue)

        if hapticsEnabled { hapticImpact(.heavy) }

        Task { @MainActor in
            let totalTicks = 38
            for tick in 0..<totalTicks {
                let progress = Double(tick) / Double(totalTicks)
                let interval = 40 + Int(progress * progress * 200)
                self.displayedNumber = Int.random(in: self.minValue...self.maxValue)
                try? await Task.sleep(for: .milliseconds(interval))
            }
            self.displayedNumber = target
            self.result = target
            self.isSpinning = false
            if hapticsEnabled { hapticSuccess() }
        }
    }

    func reset() { result = nil }
}

// MARK: - Classic View

struct NumberRouletteClassicView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(LanguageManager.self) private var lm
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var isLandscape: Bool { verticalSizeClass == .compact }

    @State private var viewModel = NumberRouletteClassicViewModel()
    @FocusState private var focusedField: ClassicField?
    @State private var showModePicker = false
    @State private var numberBounce: CGFloat = 1.0

    private var accent1: Color { theme.primary }
    private var accent2: Color { theme.paletteColors.last ?? theme.primary.opacity(0.75) }

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
        .onTapGesture { focusedField = nil }
        .fullScreenCover(isPresented: $showModePicker) {
            NumberModePickerSheet()
        }
    }

    private var portraitLayout: some View {
        VStack(spacing: 0) {
            topBar
            rangeSection
                .padding(.horizontal, 24)
                .padding(.top, 12)
            Spacer()
            numberDisplay
            Spacer()
            spinButton
                .padding(.horizontal, 30)
                .padding(.bottom, 44)
        }
        .ignoresSafeArea(.keyboard)
    }

    private var landscapeLayout: some View {
        VStack(spacing: 0) {
            topBar
            HStack(alignment: .center, spacing: 0) {
                // Left: number display (scaled to fit)
                GeometryReader { geo in
                    let scale = min(geo.size.width / 340.0, geo.size.height / 260.0) * 0.88
                    ZStack {
                        numberDisplay
                            .scaleEffect(scale)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .frame(maxWidth: .infinity)

                // Right: range + spin button
                VStack(spacing: 0) {
                    Spacer()
                    rangeSection
                        .padding(.horizontal, 20)
                    Spacer()
                    spinButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
                .frame(width: 280)
            }
        }
        .ignoresSafeArea(.keyboard)
    }

    // MARK: Top Bar

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
            Text(lm.t("numberroulette.classic.title"))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Button { showModePicker = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    // MARK: Range Section

    private var rangeSection: some View {
        HStack(spacing: 14) {
            ClassicRangePicker(
                label: lm.t("numberroulette.range.from"),
                value: $viewModel.minValue,
                color: accent1,
                focusState: $focusedField,
                fieldTag: ClassicField.min
            )
            .onChange(of: viewModel.minValue) { _, new in
                if new >= viewModel.maxValue { viewModel.maxValue = new + 1 }
                viewModel.reset()
            }

            Image(systemName: "arrow.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))

            ClassicRangePicker(
                label: lm.t("numberroulette.range.to"),
                value: $viewModel.maxValue,
                color: accent2,
                focusState: $focusedField,
                fieldTag: ClassicField.max
            )
            .onChange(of: viewModel.maxValue) { _, new in
                if new <= viewModel.minValue { viewModel.minValue = new - 1 }
                viewModel.reset()
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: Number Display

    private var numberDisplay: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accent1.opacity(0.4), .clear],
                        center: .center, startRadius: 0, endRadius: 160
                    )
                )
                .frame(width: 340, height: 340)
                .blur(radius: 30)

            Text("\(viewModel.displayedNumber)")
                .font(.system(size: 128, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: false))
                .animation(.easeOut(duration: 0.05), value: viewModel.displayedNumber)
                .blur(radius: viewModel.isSpinning ? 1.5 : 0)
                .shadow(color: accent1.opacity(0.6), radius: 20)
                .frame(minWidth: 240)
                .scaleEffect(numberBounce)
        }
        .onChange(of: viewModel.result) { _, newResult in
            guard newResult != nil else { return }
            withAnimation(.spring(response: 0.22, dampingFraction: 0.38)) {
                numberBounce = 1.14
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
                    numberBounce = 1.0
                }
            }
        }
    }

    // MARK: Spin Button

    private var spinButton: some View {
        Button {
            focusedField = nil
            viewModel.spin(hapticsEnabled: hapticsEnabled)
        } label: {
            HStack(spacing: 10) {
                if viewModel.isSpinning {
                    ProgressView().tint(.white).scaleEffect(0.85)
                } else {
                    Image(systemName: "shuffle.circle.fill").font(.system(size: 20))
                }
                Text(viewModel.isSpinning ? lm.t("numberroulette.spinning") : lm.t("dice.roll"))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                viewModel.isSpinning ? accent1.opacity(0.50) : accent1,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .shadow(color: accent1.opacity(viewModel.isSpinning ? 0.12 : 0.38), radius: 12, y: 6)
        }
        .disabled(viewModel.isSpinning || !viewModel.rangeIsValid)
        .buttonStyle(.pressable)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isSpinning)
    }
}

// MARK: - Classic Range Picker

private struct ClassicRangePicker<F: Hashable>: View {
    let label: String
    @Binding var value: Int
    let color: Color
    var focusState: FocusState<F?>.Binding
    var fieldTag: F
    @Environment(LanguageManager.self) private var lm

    @State private var editingText = ""

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))

            HStack(spacing: 0) {
                Button {
                    value = max(-99999, value - 1)
                    editingText = "\(value)"
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 36, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressableLight)

                TextField("", text: $editingText)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .focused(focusState, equals: fieldTag)
                    .frame(minWidth: 52)

                Button {
                    value = min(99999, value + 1)
                    editingText = "\(value)"
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 36, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressableLight)
            }
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(color.opacity(0.4), lineWidth: 1)
                }
            )
        }
        .frame(maxWidth: .infinity)
        .onAppear { editingText = "\(value)" }
        // Don't update the binding on every keystroke — defer to focus loss to
        // avoid re-rendering the parent view on each character typed.
        .onChange(of: value) { _, new in
            if focusState.wrappedValue != fieldTag { editingText = "\(new)" }
        }
        .onChange(of: focusState.wrappedValue) { _, newFocus in
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

// MARK: - Container

struct NumberRouletteContainerView: View {
    @AppStorage("numberRouletteStyle") private var style = "slot"

    var body: some View {
        Group {
            if style == "classic" {
                NumberRouletteClassicView()
            } else {
                NumberRouletteView()
            }
        }
        .id(style) // force full re-creation when mode changes
    }
}

// MARK: - Mode Picker Sheet

struct NumberModePickerSheet: View {
    @AppStorage("numberRouletteStyle") private var style = "slot"
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(LanguageManager.self) private var lm

    var body: some View {
        ZStack {
            theme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ────────────────────────────────────────────
                HStack {
                    Spacer()
                    Text(lm.t("numberroulette.mode.title"))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button { dismiss() } label: {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.18))
                                .frame(width: 40, height: 40)
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 4)

                Text(lm.t("numberroulette.mode.hint"))
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)

                ScrollView {
                    VStack(spacing: 16) {
                        ModeOptionCard(
                            title: lm.t("numberroulette.slot.title"),
                            description: lm.t("numberroulette.slot.desc"),
                            illustration: AnyView(SlotMiniIllustration()),
                            gradient: [Color(hex: "FF2D55"), Color(hex: "FF7700")],
                            isSelected: style == "slot"
                        ) {
                            style = "slot"
                            dismiss()
                        }

                        ModeOptionCard(
                            title: lm.t("numberroulette.classic.desc.title"),
                            description: lm.t("numberroulette.classic.desc"),
                            illustration: AnyView(NumberMiniIllustration()),
                            gradient: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                            isSelected: style == "classic"
                        ) {
                            style = "classic"
                            dismiss()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 48)
                }
            }
        }
    }
}

// MARK: - Mode Option Card

private struct ModeOptionCard: View {
    let title: String
    let description: String
    let illustration: AnyView
    let gradient: [Color]
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // Illustration banner
                ZStack {
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    illustration
                }
                .frame(height: 100)

                // Text row
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(description)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 10)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(gradient[0])
                            .padding(.top, 2)
                    }
                }
                .padding(14)
                .background(.white.opacity(0.08))
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isSelected ? gradient[0] : Color.white.opacity(0.15),
                        lineWidth: isSelected ? 2.5 : 1
                    )
            )
            .shadow(
                color: isSelected ? gradient[0].opacity(0.3) : .black.opacity(0.07),
                radius: isSelected ? 12 : 4,
                y: 3
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Mini Illustrations

private struct SlotMiniIllustration: View {
    private let digits = [7, 3, 5, 2]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(.black.opacity(0.25))
                    .frame(width: 28, height: 38)
                    .overlay(
                        Text("\(digits[i])")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.black.opacity(0.22))
        )
    }
}

private struct NumberMiniIllustration: View {
    var body: some View {
        Text("42")
            .font(.system(size: 52, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .white.opacity(0.35), radius: 10)
    }
}

// MARK: - Preview

#Preview("Classic") {
    NumberRouletteClassicView()
}

#Preview("Container") {
    NumberRouletteContainerView()
}

#Preview("Mode Picker") {
    NumberModePickerSheet()
}
