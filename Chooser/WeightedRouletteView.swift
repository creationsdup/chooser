import SwiftUI
import SwiftData

// MARK: - Model

struct WeightedOption: Identifiable {
    let id: UUID
    var name: String
    var weight: Double

    init(id: UUID = UUID(), name: String, weight: Double = 10) {
        self.id = id
        self.name = name
        self.weight = weight
    }
}

// MARK: - ViewModel

@Observable
final class WeightedRouletteViewModel {
    var options: [WeightedOption] = [
        WeightedOption(name: "Option 1", weight: 50),
        WeightedOption(name: "Option 2", weight: 30),
        WeightedOption(name: "Option 3", weight: 20),
    ]
    /// Sum of all option weights (intended %)
    var totalPercent: Double { options.reduce(0) { $0 + $1.weight } }
    var rotationAngle: Double = 0
    var isSpinning = false
    var result: WeightedOption? = nil
    var winnerColor: Color = Color(hex: "FF6B6B")

    // Only options with weight > 0 participate in the draw and appear on the wheel
    var activeOptions: [WeightedOption] {
        options.filter { $0.weight > 0 }
    }

    var totalWeight: Double {
        activeOptions.reduce(0) { $0 + $1.weight }
    }

    // Percentage contribution of an option (0…100)
    func percentage(for option: WeightedOption) -> Double {
        guard totalWeight > 0, option.weight > 0 else { return 0 }
        return option.weight / totalWeight * 100
    }

    // Index of an option in activeOptions — used for colour assignment
    func activeIndex(for id: UUID) -> Int? {
        activeOptions.firstIndex(where: { $0.id == id })
    }

    func addOption() {
        options.append(WeightedOption(name: "Option \(options.count + 1)", weight: 10))
    }

    // Remaining % available (100 − sum of others, clamped 0…100)
    func remainingPercent(excluding id: UUID) -> Double {
        let others = options.filter { $0.id != id }.reduce(0) { $0 + $1.weight }
        return max(0, 100 - others)
    }

    func updateName(for id: UUID, name: String) {
        guard let i = options.firstIndex(where: { $0.id == id }) else { return }
        options[i].name = name
    }

    func adjustWeight(for id: UUID, delta: Double) {
        guard let i = options.firstIndex(where: { $0.id == id }) else { return }
        options[i].weight = max(0, min(100, options[i].weight + delta))
        result = nil
    }

    func setWeight(for id: UUID, weight: Double) {
        guard let i = options.firstIndex(where: { $0.id == id }) else { return }
        options[i].weight = max(0, min(100, weight))
        result = nil
    }

    func removeOption(id: UUID) {
        options.removeAll { $0.id == id }
        result = nil
    }

    // MARK: Weighted spin

    func spin(palette: [Color], hapticsEnabled: Bool) {
        let active = activeOptions
        guard !isSpinning, active.count >= 2 else { return }
        isSpinning = true
        result = nil

        // --- True weighted random selection ---
        // 1. Sum all weights
        let total = totalWeight
        // 2. Draw a uniform random in [0, total)
        var r = Double.random(in: 0..<total)
        // 3. Walk the cumulative distribution until we cross the draw value
        var winner = active.last!
        for option in active {
            r -= option.weight
            if r < 0 {
                winner = option
                break
            }
        }

        // --- Compute the angle where the winner segment's centre sits (from the top, clockwise, degrees) ---
        // Segments are laid out starting from the 12-o'clock position (-π/2) going clockwise.
        var cumDeg = 0.0
        var winnerMidDeg = 0.0
        for option in active {
            let segDeg = option.weight / total * 360.0
            if option.id == winner.id {
                winnerMidDeg = cumDeg + segDeg / 2.0
                break
            }
            cumDeg += segDeg
        }

        // --- Map to a final rotation angle ---
        // After rotating by `rotationAngle` degrees, the 12-o'clock position on the wheel
        // is `rotationAngle` degrees ahead of its original spot.  We need
        //   (winnerMidDeg + targetAngle) ≡ 0 (mod 360)  →  targetAngle ≡ -winnerMidDeg (mod 360)
        let targetMod = (360.0 - winnerMidDeg).truncatingRemainder(dividingBy: 360.0)
        let currentMod = rotationAngle.truncatingRemainder(dividingBy: 360.0)
        var delta = targetMod - currentMod
        if delta <= 0 { delta += 360 }
        let extraSpins = Double(Int.random(in: 8...12)) * 360.0
        let targetAngle = rotationAngle + extraSpins + delta

        // Winner colour
        if let idx = active.firstIndex(where: { $0.id == winner.id }) {
            winnerColor = palette[idx % palette.count]
        }

        if hapticsEnabled { hapticImpact(.heavy) }

        withAnimation(.timingCurve(0.17, 0.67, 0.12, 1.0, duration: 4.0)) {
            rotationAngle = targetAngle
        }

        let capturedWinner = winner
        Task {
            try? await Task.sleep(for: .milliseconds(4150))
            result = capturedWinner
            isSpinning = false
            if hapticsEnabled { hapticSuccess() }
        }
    }

    func resetOptions(count: Int) {
        let w = (100.0 / Double(count)).rounded()
        options = (1...count).map { _ in WeightedOption(name: "", weight: w) }
        result = nil
        rotationAngle = 0
    }

    func reset() {
        result = nil
    }
}

// MARK: - Main View

struct WeightedRouletteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(LanguageManager.self) private var lm
    @Environment(AppearanceManager.self) private var appearance
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("hapticsEnabled")   private var hapticsEnabled      = true
    @AppStorage("wheelColorStyle")  private var wheelColorStyleRaw  = WheelColorStyle.vivid.rawValue
    @AppStorage("pointerStyle")     private var pointerStyleRaw     = PointerStyle.pin.rawValue

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var isLandscape: Bool { verticalSizeClass == .compact }
    private var isAtmosLight: Bool { appearance.visualStyle == .atmos && colorScheme == .light }
    private var gameFg: Color { isAtmosLight ? Color(hex: "1A1A2E") : .white }

    private enum Phase { case setup, customize, wheel }

    @State private var viewModel = WeightedRouletteViewModel()
    @State private var showOptions = false
    @State private var showSaveSheet = false
    @State private var showLoadSheet = false
    @State private var phase: Phase = .setup
    @State private var selectedCount: Int = 4
    @State private var savedWheels: [SavedWheel] = []

    private var wheelColorStyle: WheelColorStyle {
        WheelColorStyle(rawValue: wheelColorStyleRaw) ?? .vivid
    }
    private var pointerStyle: PointerStyle {
        PointerStyle(rawValue: pointerStyleRaw) ?? .pin
    }

    private var wheelSize: CGFloat { isLandscape ? 220 : 280 }

    var body: some View {
        if phase == .setup {
            setupScreen
        } else if phase == .customize {
            customizeScreen
        } else {
            ZStack {
                GameBackgroundView(theme: theme, appearance: appearance, colorScheme: colorScheme)
                if isLandscape {
                    landscapeLayout
                } else {
                    portraitLayout
                }
            }
            .sheet(isPresented: $showOptions) {
                optionsSheet
                    .environment(\.appTheme, theme)
            }
            .sheet(isPresented: $showSaveSheet, onDismiss: { savedWheels = WheelStorage.load() }) {
                SaveWheelSheet(viewModel: viewModel)
                    .environment(\.appTheme, theme)
                    .environment(lm)
            }
        }
    }

    private var portraitLayout: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                topBar
                Spacer()
                if viewModel.activeOptions.count >= 2 {
                    wheelSection
                } else {
                    emptyWheel
                }
                Spacer()
            }
            if viewModel.activeOptions.count >= 2 {
                spinButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 34)
            }
        }
    }

    private var landscapeLayout: some View {
        VStack(spacing: 0) {
            topBar
            HStack(alignment: .center, spacing: 0) {
                // Left: wheel
                if viewModel.activeOptions.count >= 2 {
                    wheelSection.frame(maxWidth: .infinity)
                } else {
                    emptyWheel.frame(maxWidth: .infinity)
                }

                // Right: options button + spin button
                VStack(spacing: 12) {
                    Spacer()
                    Button { showOptions = true } label: {
                        Label(lm.t("weighted.options.title"), systemImage: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(gameFg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.06) : Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.pressable)
                    if viewModel.activeOptions.count >= 2 {
                        spinButton
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
                .frame(width: 260)
            }
        }
    }

    // MARK: Setup Screen

    private var setupScreen: some View {
        ZStack {
            GameBackgroundView(theme: theme, appearance: appearance, colorScheme: colorScheme)
            VStack(spacing: 0) {
                // Back button row
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

                // Scrollable content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 36) {
                        // Icon + Title
                        VStack(spacing: 10) {
                            Image(systemName: "chart.pie.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(gameFg.opacity(0.9))
                                .shadow(color: theme.primary.opacity(0.6), radius: 16, y: 6)

                            Text(lm.t("weighted.setup.title"))
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundStyle(gameFg)

                            Text(lm.t("weighted.setup.subtitle"))
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(gameFg.opacity(0.55))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 16)

                        // Count grid: 2–5 first row, 6–8 second row
                        VStack(spacing: 14) {
                            HStack(spacing: 14) {
                                ForEach(2...5, id: \.self) { n in countCell(n) }
                            }
                            HStack(spacing: 14) {
                                ForEach(6...8, id: \.self) { n in countCell(n) }
                            }
                        }

                        // Load saved wheel button
                        if !savedWheels.isEmpty {
                            Button { showLoadSheet = true } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "square.and.arrow.down.fill")
                                        .font(.system(size: 16))
                                    Text(lm.t("wheel.save.myWheels.button"))
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                }
                                .foregroundStyle(gameFg.opacity(0.85))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.06) : Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.10) : Color.white.opacity(0.15), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }

                // Continue button pinned at bottom
                Button {
                    viewModel.resetOptions(count: selectedCount)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        phase = .customize
                    }
                } label: {
                    Text(lm.t("weighted.setup.continue"))
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(theme.primary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: theme.primary.opacity(0.38), radius: 12, y: 6)
                }
                .buttonStyle(.pressable)
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
                .padding(.top, 10)
            }
        }
        .onAppear { savedWheels = WheelStorage.load() }
        .sheet(isPresented: $showLoadSheet) {
            LoadWheelSheet(onLoad: { wheel in
                loadSavedWheel(wheel)
            })
            .environment(\.appTheme, theme)
            .environment(lm)
        }
    }

    private func loadSavedWheel(_ wheel: SavedWheel) {
        viewModel.options = zip(wheel.optionNames, wheel.optionWeights).map { name, weight in
            WeightedOption(name: name, weight: weight)
        }
        viewModel.result = nil
        viewModel.rotationAngle = 0
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            phase = .wheel
        }
    }

    private func countCell(_ n: Int) -> some View {
        let isSelected = selectedCount == n
        let idleFill: Color = isAtmosLight ? Color(hex: "1A1A2E").opacity(0.06) : Color.white.opacity(0.1)
        let idleStroke: Color = isAtmosLight ? Color(hex: "1A1A2E").opacity(0.12) : Color.white.opacity(0.12)
        return Button { selectedCount = n } label: {
            Text("\(n)")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(isSelected ? .white : gameFg.opacity(0.45))
                .frame(width: 72, height: 72)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isSelected ? theme.primary.opacity(0.85) : idleFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isSelected ? theme.primary : idleStroke, lineWidth: isSelected ? 2 : 1)
                )
                .shadow(color: isSelected ? theme.primary.opacity(0.5) : .clear, radius: 8, y: 4)
                .scaleEffect(isSelected ? 1.06 : 1.0)
                .animation(.spring(response: 0.28, dampingFraction: 0.68), value: isSelected)
        }
        .buttonStyle(.pressableLight)
    }

    // MARK: Customize Screen

    private var customizeScreen: some View {
        ZStack {
            GameBackgroundView(theme: theme, appearance: appearance, colorScheme: colorScheme)
            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            phase = .setup
                        }
                    } label: {
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
                    Text(lm.t("weighted.customize.title"))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(gameFg)
                    Spacer()
                    // Balance the back button
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 10)

                // Options list
                ScrollView {
                    customizeOptionsSection
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                }

                // Validation message + "Voir la roue" button
                let allNamed = viewModel.options.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
                let canStart = viewModel.activeOptions.count >= 2 && allNamed

                if !allNamed {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 13))
                        Text(lm.t("weighted.customize.namesRequired"))
                            .font(.system(size: 13, design: .rounded))
                    }
                    .foregroundStyle(Color(hex: "FFE66D"))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        phase = .wheel
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                        Text(lm.t("weighted.customize.start"))
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(canStart ? .white : gameFg.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        canStart ? theme.primary : (isAtmosLight ? Color(hex: "1A1A2E").opacity(0.08) : Color.white.opacity(0.12)),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .shadow(color: canStart ? theme.primary.opacity(0.38) : .clear, radius: 12, y: 6)
                }
                .disabled(!canStart)
                .buttonStyle(.pressable)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: allNamed)
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
            }
        }
    }

    private var customizeOptionsSection: some View {
        let total = viewModel.totalPercent
        let isExact = abs(total - 100) < 0.5
        return VStack(spacing: 10) {
            ForEach(viewModel.options) { option in
                let idx = viewModel.activeIndex(for: option.id)
                let color = idx.map { wheelColorStyle.colors[$0 % wheelColorStyle.colors.count] } ?? Color.white.opacity(0.3)
                SimpleWeightedOptionRow(
                    option: option,
                    color: color,
                    onNameChange: { viewModel.updateName(for: option.id, name: $0) },
                    onSetWeight: { viewModel.setWeight(for: option.id, weight: $0) }
                )
            }

            // Total pill
            HStack(spacing: 5) {
                Image(systemName: isExact ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                Text(String(format: "Total : %.0f%%", total))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: total)
            }
            .foregroundStyle(isExact ? Color(hex: "4ECDC4") : Color(hex: "FFE66D"))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.top, 4)
        }
    }

    // MARK: Top Bar

    private var topBar: some View {
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
            Text(lm.t("mode.weightedRoulette.title"))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(gameFg)
            Spacer()
            HStack(spacing: 6) {
                Button { showSaveSheet = true } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 20))
                        .foregroundStyle(gameFg.opacity(0.7))
                }
                .buttonStyle(.pressableLight)
                Button { showOptions = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 20))
                        .foregroundStyle(gameFg.opacity(0.7))
                }
                .buttonStyle(.pressableLight)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    // MARK: Wheel Section

    private var wheelSection: some View {
        ZStack {
            // Ambient glow
            Circle()
                .fill(RadialGradient(
                    colors: [theme.primary.opacity(0.35), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: wheelSize * 0.65
                ))
                .frame(width: wheelSize * 1.3, height: wheelSize * 1.3)
                .blur(radius: 24)

            // Weighted wheel canvas
            WeightedWheelCanvas(
                options: viewModel.activeOptions,
                totalWeight: viewModel.totalWeight,
                centerColor: theme.primary,
                colorStyle: wheelColorStyle
            )
            .rotationEffect(.degrees(viewModel.rotationAngle))
            .frame(width: wheelSize, height: wheelSize)
            .shadow(color: .black.opacity(0.5), radius: 20, y: 10)

            // Pointer
            VStack(spacing: 0) {
                ZStack {
                    PointerShape(style: pointerStyle)
                        .fill(.black.opacity(0.2))
                        .frame(width: 26, height: 32)
                        .blur(radius: 5)
                        .offset(y: 5)
                    PointerShape(style: pointerStyle)
                        .fill(LinearGradient(
                            colors: [.white, Color(hex: "DDDDDD")],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(width: 24, height: 30)
                    PointerShape(style: pointerStyle)
                        .stroke(.white.opacity(0.6), lineWidth: 1)
                        .frame(width: 24, height: 30)
                }
                Circle()
                    .fill(.white)
                    .frame(width: 14, height: 14)
                    .shadow(color: .black.opacity(0.25), radius: 3)
                    .offset(y: -7)
                Spacer()
            }
            .frame(height: wheelSize)
            .offset(y: -20)

            // Result overlay
            if let result = viewModel.result {
                weightedResultCard(for: result)
                    .transition(.scale(scale: 0.65).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.72), value: viewModel.result != nil)
    }

    private var emptyWheel: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.pie")
                .font(.system(size: 56))
                .foregroundStyle(gameFg.opacity(0.25))
            Text(lm.t("weighted.empty"))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(gameFg.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(height: wheelSize)
    }

    // MARK: Options Sheet

    private var optionsSheet: some View {
        NavigationStack {
            ZStack {
                GameBackgroundView(theme: theme, appearance: appearance, colorScheme: colorScheme)
                ScrollView {
                    optionsSection
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                }
            }
            .navigationTitle(lm.t("weighted.options.title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(lm.t("button.ok")) { showOptions = false }
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.primary)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: Options Section

    private var optionsSection: some View {
        VStack(spacing: 0) {
            // Header: title + total indicator + add button
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.primary)
                    Text(lm.t("weighted.probabilities"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(gameFg.opacity(0.4))
                        .kerning(0.8)
                }

                Spacer()

                // Total badge
                let total = viewModel.totalPercent
                let isExact = abs(total - 100) < 0.5
                HStack(spacing: 3) {
                    Text(lm.t("weighted.total"))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(gameFg.opacity(0.35))
                    Text(String(format: "%.0f%%", total))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(isExact ? Color(hex: "4ECDC4") : Color(hex: "FFE66D"))
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: total)
                }

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        viewModel.addOption()
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(theme.primary)
                }
                .buttonStyle(.pressableLight)
            }
            .padding(.bottom, 12)

            // Rows
            if viewModel.options.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "plus.circle.dashed")
                        .font(.system(size: 36))
                        .foregroundStyle(gameFg.opacity(0.2))
                    Text(lm.t("weighted.options.empty"))
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(gameFg.opacity(0.35))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.options) { option in
                        let activeIdx = viewModel.activeIndex(for: option.id)
                        let color = activeIdx.map { wheelColorStyle.colors[$0 % wheelColorStyle.colors.count] } ?? .white.opacity(0.2)
                        let realPct = viewModel.percentage(for: option)

                        WeightedOptionRow(
                            option: option,
                            color: color,
                            realPercentage: realPct,
                            onNameChange: { viewModel.updateName(for: option.id, name: $0) },
                            onAdjustWeight: { viewModel.adjustWeight(for: option.id, delta: $0) },
                            onDelete: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    viewModel.removeOption(id: option.id)
                                }
                            }
                        )
                    }
                }
            }

            // Hint shown only when total ≠ 100
            if !viewModel.options.isEmpty && abs(viewModel.totalPercent - 100) > 0.5 {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 11))
                    Text(lm.t("weighted.disclaimer"))
                        .font(.system(size: 11, design: .rounded))
                }
                .foregroundStyle(Color(hex: "FFE66D").opacity(0.7))
                .padding(.top, 12)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: abs(viewModel.totalPercent - 100) > 0.5)
            }
        }
    }

    // MARK: Result Card

    private func weightedResultCard(for result: WeightedOption) -> some View {
        VStack(spacing: 14) {
            Text("🎉")
                .font(.system(size: 44))
            Text(result.name)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .shadow(color: .black.opacity(0.4), radius: 4)

            let pct = viewModel.percentage(for: result)
            Text(String(format: lm.t("weighted.probability"), pct))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))

            Button { viewModel.reset() } label: {
                Text(lm.t("button.again"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(viewModel.winnerColor.contrastingText)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(viewModel.winnerColor, in: Capsule())
                    .shadow(color: viewModel.winnerColor.opacity(0.45), radius: 6, y: 3)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 26)
        .padding(.horizontal, 30)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.black.opacity(0.78))
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(LinearGradient(
                        colors: [viewModel.winnerColor.opacity(0.35), viewModel.winnerColor.opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(viewModel.winnerColor.opacity(0.55), lineWidth: 1.5)
            }
        )
        .innerHighlight(cornerRadius: 26, intensity: 0.12)
        .shadow(color: viewModel.winnerColor.opacity(0.45), radius: 24, y: 10)
        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    }

    // MARK: Spin Button

    private var spinButton: some View {
        Button {
            viewModel.spin(palette: wheelColorStyle.colors, hapticsEnabled: hapticsEnabled)
        } label: {
            HStack(spacing: 10) {
                if viewModel.isSpinning {
                    ProgressView().tint(.white).scaleEffect(0.85)
                } else {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 20))
                }
                Text(viewModel.isSpinning ? lm.t("state.inProgress") : lm.t("roulette.spin"))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                viewModel.isSpinning ? theme.primary.opacity(0.50) : theme.primary,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .shadow(color: theme.primary.opacity(viewModel.isSpinning ? 0.12 : 0.38), radius: 12, y: 6)
        }
        .disabled(viewModel.isSpinning)
        .buttonStyle(.pressable)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isSpinning)
    }
}

// MARK: - Simple Option Row (customize screen)

struct SimpleWeightedOptionRow: View {
    let option: WeightedOption
    let color: Color
    let onNameChange: (String) -> Void
    let onSetWeight: (Double) -> Void
    @Environment(LanguageManager.self) private var lm
    @Environment(AppearanceManager.self) private var appearance
    @Environment(\.colorScheme) private var colorScheme
    private var isAtmosLight: Bool { appearance.visualStyle == .atmos && colorScheme == .light }
    private var gameFg: Color { isAtmosLight ? Color(hex: "1A1A2E") : .white }
    @State private var localName: String

    init(option: WeightedOption, color: Color,
         onNameChange: @escaping (String) -> Void,
         onSetWeight: @escaping (Double) -> Void) {
        self.option = option
        self.color = color
        self.onNameChange = onNameChange
        self.onSetWeight = onSetWeight
        _localName = State(initialValue: option.name)
    }

    private var weightBinding: Binding<Double> {
        Binding(get: { option.weight }, set: { onSetWeight($0) })
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                    .shadow(color: color.opacity(0.5), radius: 3)

                TextField(lm.t("weighted.option.placeholder"), text: $localName)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(gameFg)
                    .tint(color)
                    .onChange(of: localName) { _, v in onNameChange(v) }

                Spacer(minLength: 8)

                Text(String(format: "%.0f%%", option.weight))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .frame(minWidth: 46, alignment: .trailing)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: option.weight)
            }

            Slider(value: weightBinding, in: 0...100, step: 1)
                .tint(color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.06) : Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.22), lineWidth: 1)
        )
    }
}

// MARK: - Option Row

struct WeightedOptionRow: View {
    let option: WeightedOption
    let color: Color
    /// Real probability (weight / totalWeight * 100) — used for the progress bar
    let realPercentage: Double
    let onNameChange: (String) -> Void
    let onAdjustWeight: (Double) -> Void
    let onDelete: () -> Void
    @Environment(LanguageManager.self) private var lm
    @Environment(AppearanceManager.self) private var appearance
    @Environment(\.colorScheme) private var colorScheme
    private var isAtmosLight: Bool { appearance.visualStyle == .atmos && colorScheme == .light }
    private var gameFg: Color { isAtmosLight ? Color(hex: "1A1A2E") : .white }

    @State private var localName: String

    init(option: WeightedOption, color: Color, realPercentage: Double,
         onNameChange: @escaping (String) -> Void,
         onAdjustWeight: @escaping (Double) -> Void,
         onDelete: @escaping () -> Void) {
        self.option = option
        self.color = color
        self.realPercentage = realPercentage
        self.onNameChange = onNameChange
        self.onAdjustWeight = onAdjustWeight
        self.onDelete = onDelete
        _localName = State(initialValue: option.name)
    }

    var body: some View {
        VStack(spacing: 10) {
            // Row 1: colour dot + name field + delete
            HStack(spacing: 10) {
                Circle()
                    .fill(color)
                    .frame(width: 11, height: 11)
                    .shadow(color: color.opacity(0.6), radius: 3)

                TextField(lm.t("weighted.option.placeholder"), text: $localName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(gameFg)
                    .tint(color)
                    .onChange(of: localName) { _, newValue in
                        onNameChange(newValue)
                    }

                Spacer(minLength: 4)

                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(gameFg.opacity(0.25))
                }
                .buttonStyle(.pressableLight)
            }

            // Row 2: % stepper + progress bar
            HStack(spacing: 8) {
                // −5%
                stepButton(symbol: "minus", enabled: option.weight > 0) { onAdjustWeight(-5) }
                // −1%
                stepButton(symbol: "minus.circle", enabled: option.weight > 0) { onAdjustWeight(-1) }

                // Main % value
                HStack(spacing: 2) {
                    Text(percentLabel)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(option.weight > 0 ? gameFg : gameFg.opacity(0.3))
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: option.weight)
                    Text("%")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(option.weight > 0 ? color : .white.opacity(0.2))
                        .offset(y: 2)
                }
                .frame(minWidth: 58, alignment: .center)

                // +1%
                stepButton(symbol: "plus.circle", enabled: option.weight < 100) { onAdjustWeight(1) }
                // +5%
                stepButton(symbol: "plus", enabled: option.weight < 100) { onAdjustWeight(5) }

                Spacer(minLength: 8)

                // Progress bar (real probability width)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.08))
                        if realPercentage > 0 {
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [color.opacity(0.7), color],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .frame(width: max(4, geo.size.width * CGFloat(realPercentage / 100)))
                        }
                    }
                }
                .frame(height: 6)
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: realPercentage)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isAtmosLight ? Color(hex: "1A1A2E").opacity(option.weight > 0 ? 0.06 : 0.03) : Color.white.opacity(option.weight > 0 ? 0.08 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(option.weight > 0 ? color.opacity(0.25) : (isAtmosLight ? Color(hex: "1A1A2E").opacity(0.10) : Color.white.opacity(0.06)), lineWidth: 1)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: option.weight > 0)
    }

    /// Displayed value: the user-set % (integer)
    private var percentLabel: String {
        let w = option.weight
        return w == w.rounded() ? "\(Int(w))" : String(format: "%.1f", w)
    }

    private func stepButton(symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(enabled ? color : .white.opacity(0.15))
                .frame(width: 30, height: 30)
                .background(Circle().fill(enabled ? color.opacity(0.18) : .white.opacity(0.04)))
                .overlay(Circle().stroke(enabled ? color.opacity(0.35) : .clear, lineWidth: 1))
        }
        .buttonStyle(.pressableLight)
        .disabled(!enabled)
    }
}

// MARK: - Weighted Wheel Canvas

/// A Canvas-based wheel where each segment's arc is proportional to its weight.
struct WeightedWheelCanvas: View {
    let options: [WeightedOption]   // Only active options (weight > 0)
    let totalWeight: Double
    var centerColor: Color = Color(hex: "FF6B6B")
    var colorStyle: WheelColorStyle = .vivid

    var body: some View {
        Canvas { context, size in
            guard !options.isEmpty, totalWeight > 0 else { return }

            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 4

            // Start from 12 o'clock (-π/2) and lay out segments clockwise
            var startRad = -Double.pi / 2

            for (i, option) in options.enumerated() {
                let fraction = option.weight / totalWeight
                let segRad   = 2 * Double.pi * fraction
                let endRad   = startRad + segRad
                let midRad   = startRad + segRad / 2

                let segColor = colorStyle.colors[i % colorStyle.colors.count]

                // --- Segment fill ---
                var path = Path()
                path.move(to: center)
                path.addArc(center: center, radius: radius,
                            startAngle: .radians(startRad),
                            endAngle: .radians(endRad),
                            clockwise: false)
                path.closeSubpath()
                context.fill(path, with: .color(segColor))

                // --- Leading-edge highlight (top 18% of arc) ---
                var highlight = Path()
                highlight.move(to: center)
                highlight.addArc(center: center, radius: radius,
                                 startAngle: .radians(startRad),
                                 endAngle: .radians(startRad + segRad * 0.18),
                                 clockwise: false)

                highlight.closeSubpath()
                context.fill(highlight, with: .color(.white.opacity(0.10)))

                // --- Divider line at segment start ---
                var line = Path()
                line.move(to: center)
                line.addLine(to: CGPoint(
                    x: center.x + radius * cos(startRad),
                    y: center.y + radius * sin(startRad)
                ))
                context.stroke(line, with: .color(.white.opacity(0.5)), lineWidth: 1.5)

                // --- Label (only when arc is wide enough to be legible) ---
                if segRad > 0.18 {
                    let labelR     = radius * 0.65
                    let labelPoint = CGPoint(
                        x: center.x + labelR * cos(midRad),
                        y: center.y + labelR * sin(midRad)
                    )
                    let text         = option.name
                    let availableArc = segRad * labelR
                    let fontSize     = max(7.0, min(14.0, availableArc / max(1.0, Double(text.count) * 0.72)))
                    let labelColor: Color = segColor.isLight ? Color(white: 0.12) : .white

                    context.drawLayer { ctx in
                        ctx.translateBy(x: labelPoint.x, y: labelPoint.y)
                        var angle = midRad
                        if cos(midRad) < 0 { angle += .pi } // flip text on left half
                        ctx.rotate(by: .radians(angle))
                        ctx.draw(
                            Text(text)
                                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                                .foregroundStyle(labelColor),
                            at: .zero,
                            anchor: .center
                        )
                    }
                }

                startRad = endRad
            }

            // --- Outer ring ---
            var outerRing = Path()
            outerRing.addEllipse(in: CGRect(
                x: center.x - radius - 1, y: center.y - radius - 1,
                width: (radius + 1) * 2, height: (radius + 1) * 2
            ))
            context.stroke(outerRing, with: .color(.white.opacity(0.55)), lineWidth: 3.5)

            // --- Inner shadow ring ---
            var innerRing = Path()
            innerRing.addEllipse(in: CGRect(
                x: center.x - radius + 2, y: center.y - radius + 2,
                width: (radius - 2) * 2, height: (radius - 2) * 2
            ))
            context.stroke(innerRing, with: .color(.black.opacity(0.12)), lineWidth: 2)

            // --- Centre hub ---
            let capR: CGFloat = 20
            var cap = Path()
            cap.addEllipse(in: CGRect(x: center.x - capR, y: center.y - capR,
                                      width: capR * 2, height: capR * 2))
            context.fill(cap, with: .color(.white))
            context.stroke(cap, with: .color(.black.opacity(0.1)), lineWidth: 2)

            var dot = Path()
            dot.addEllipse(in: CGRect(x: center.x - 7, y: center.y - 7, width: 14, height: 14))
            context.fill(dot, with: .color(centerColor))
        }
    }
}

// MARK: - Load Wheel Sheet

struct LoadWheelSheet: View {
    let onLoad: (SavedWheel) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(LanguageManager.self) private var lm
    @Environment(AppearanceManager.self) private var appearance
    @Environment(\.colorScheme) private var colorScheme
    private var isAtmosLight: Bool { appearance.visualStyle == .atmos && colorScheme == .light }
    private var gameFg: Color { isAtmosLight ? Color(hex: "1A1A2E") : .white }

    @State private var wheels: [SavedWheel] = []

    var body: some View {
        NavigationStack {
            ZStack {
                GameBackgroundView(theme: theme, appearance: appearance, colorScheme: colorScheme)
                Group {
                    if wheels.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 44))
                                .foregroundStyle(gameFg.opacity(0.2))
                            Text(lm.t("wheel.load.empty"))
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(gameFg.opacity(0.35))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(wheels) { wheel in
                                    Button {
                                        onLoad(wheel)
                                        dismiss()
                                    } label: {
                                        HStack(spacing: 14) {
                                            Image(systemName: "chart.pie.fill")
                                                .font(.system(size: 15))
                                                .foregroundStyle(theme.primary)
                                                .frame(width: 36, height: 36)
                                                .background(Circle().fill(theme.primary.opacity(0.15)))

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(wheel.name)
                                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                    .foregroundStyle(gameFg)
                                                Text("\(wheel.optionNames.count) options")
                                                    .font(.system(size: 12, design: .rounded))
                                                    .foregroundStyle(gameFg.opacity(0.4))
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(gameFg.opacity(0.25))
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 13)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.05) : Color.white.opacity(0.08))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(theme.primary.opacity(0.18), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.pressable)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            WheelStorage.delete(id: wheel.id)
                                            wheels = WheelStorage.load()
                                        } label: {
                                            Label(lm.t("button.delete"), systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                        }
                    }
                }
            }
            .navigationTitle(lm.t("wheel.save.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lm.t("button.cancel")) { dismiss() }
                        .foregroundStyle(gameFg.opacity(0.7))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .onAppear { wheels = WheelStorage.load() }
    }
}

// MARK: - Save Wheel Sheet

struct SaveWheelSheet: View {
    let viewModel: WeightedRouletteViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(LanguageManager.self) private var lm
    @Environment(AppearanceManager.self) private var appearance
    @Environment(\.colorScheme) private var colorScheme
    private var isAtmosLight: Bool { appearance.visualStyle == .atmos && colorScheme == .light }
    private var gameFg: Color { isAtmosLight ? Color(hex: "1A1A2E") : .white }

    @State private var wheelName: String = ""
    @State private var savedWheels: [SavedWheel] = []
    @State private var showSavedConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                GameBackgroundView(theme: theme, appearance: appearance, colorScheme: colorScheme)
                ScrollView {
                    VStack(spacing: 20) {
                        // Save current wheel
                        VStack(spacing: 12) {
                            TextField(lm.t("wheel.save.namePlaceholder"), text: $wheelName)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(gameFg)
                                .tint(theme.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.06) : Color.white.opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.10) : Color.white.opacity(0.15), lineWidth: 1)
                                )

                            Button {
                                saveCurrentWheel()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.down.fill")
                                        .font(.system(size: 16))
                                    Text(lm.t("wheel.save.action"))
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    wheelName.trimmingCharacters(in: .whitespaces).isEmpty
                                        ? theme.primary.opacity(0.35)
                                        : theme.primary,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                )
                            }
                            .disabled(wheelName.trimmingCharacters(in: .whitespaces).isEmpty)
                            .buttonStyle(.pressable)
                        }

                        // Confirmation flash
                        if showSavedConfirmation {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                Text(lm.t("wheel.save.saved"))
                            }
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(hex: "4ECDC4"))
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }

                        // Saved wheels list
                        if !savedWheels.isEmpty {
                            VStack(spacing: 0) {
                                HStack {
                                    Text(lm.t("wheel.save.myWheels"))
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(gameFg.opacity(0.4))
                                        .kerning(0.8)
                                    Spacer()
                                }
                                .padding(.bottom, 10)

                                VStack(spacing: 8) {
                                    ForEach(savedWheels) { wheel in
                                        savedWheelRow(wheel)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle(lm.t("wheel.save.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(lm.t("button.ok")) { dismiss() }
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.primary)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .onAppear { savedWheels = WheelStorage.load() }
    }

    private func savedWheelRow(_ wheel: SavedWheel) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(wheel.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(gameFg)
                Text("\(wheel.optionNames.count) options")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(gameFg.opacity(0.4))
            }
            Spacer()
            // Load button
            Button {
                loadWheel(wheel)
            } label: {
                Text(lm.t("wheel.save.load"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(theme.primary.opacity(0.15))
                    )
            }
            .buttonStyle(.pressableLight)
            // Delete button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    WheelStorage.delete(id: wheel.id)
                    savedWheels = WheelStorage.load()
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(gameFg.opacity(0.3))
            }
            .buttonStyle(.pressableLight)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.05) : Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.08) : Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func saveCurrentWheel() {
        let trimmed = wheelName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let wheel = SavedWheel(
            name: trimmed,
            optionNames: viewModel.options.map(\.name),
            optionWeights: viewModel.options.map(\.weight)
        )
        WheelStorage.add(wheel)
        savedWheels = WheelStorage.load()
        wheelName = ""
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showSavedConfirmation = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { showSavedConfirmation = false }
        }
    }

    private func loadWheel(_ wheel: SavedWheel) {
        viewModel.options = zip(wheel.optionNames, wheel.optionWeights).map { name, weight in
            WeightedOption(name: name, weight: weight)
        }
        viewModel.result = nil
        viewModel.rotationAngle = 0
        dismiss()
    }
}

#Preview {
    WeightedRouletteView()
        .modelContainer(for: ChoiceList.self, inMemory: true)
        .environment(\.appTheme, .coral)
}
