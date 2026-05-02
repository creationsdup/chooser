import SwiftUI
import SwiftData

// MARK: - Frame Style

enum WheelFrameStyle: String, CaseIterable, Identifiable {
    case none    = "Aucun"
    case simple  = "Simple"
    case thick   = "Épais"
    case glow    = "Lumineux"
    case casino  = "Casino"
    case premium = "Premium"

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .none:    return "wheelframe.none"
        case .simple:  return "wheelframe.simple"
        case .thick:   return "wheelframe.thick"
        case .glow:    return "wheelframe.glow"
        case .casino:  return "wheelframe.casino"
        case .premium: return "wheelframe.premium"
        }
    }

    var icon: String {
        switch self {
        case .none:    return "circle.dashed"
        case .simple:  return "circle"
        case .thick:   return "circle.fill"
        case .glow:    return "sparkle"
        case .casino:  return "star.circle.fill"
        case .premium: return "crown.fill"
        }
    }
}

// MARK: - View Model

@Observable
final class RouletteViewModel {
    var rotationAngle: Double = 0
    var isSpinning = false
    var result: String? = nil
    var winnerColor: Color = Color(hex: "FF6B6B")

    // Input
    var inputMode: ItemInputMode = .savedList
    var directEntries: [String] = []

    private var spinTask: Task<Void, Never>? = nil

    func spin(items: [String], palette: [Color], hapticsEnabled: Bool) {
        guard !isSpinning, items.count >= 2 else { return }
        isSpinning = true
        result = nil

        let count = items.count
        let segmentAngle = 360.0 / Double(count)
        let winnerIndex = Int.random(in: 0..<count)
        let winnerCenter = Double(winnerIndex) * segmentAngle + segmentAngle / 2.0
        let targetMod = (360.0 - winnerCenter).truncatingRemainder(dividingBy: 360.0)
        let currentMod = rotationAngle.truncatingRemainder(dividingBy: 360.0)
        var delta = targetMod - currentMod
        if delta <= 0 { delta += 360 }
        let extraSpins = Double(Int.random(in: 8...12)) * 360.0
        let targetAngle = rotationAngle + extraSpins + delta

        winnerColor = palette[winnerIndex % palette.count]
        if hapticsEnabled { hapticImpact(.heavy) }

        withAnimation(.timingCurve(0.17, 0.67, 0.12, 1.0, duration: 4.0)) {
            rotationAngle = targetAngle
        }
        let winner = items[winnerIndex]
        spinTask = Task {
            try? await Task.sleep(for: .milliseconds(4150))
            guard !Task.isCancelled else { return }
            result = winner
            isSpinning = false
            if hapticsEnabled { hapticSuccess() }
        }
    }

    func cancelSpin() {
        spinTask?.cancel()
        spinTask = nil
        isSpinning = false
    }

    func reset() {
        result = nil
    }

    func addDirectEntry(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let lines = trimmed
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        directEntries.append(contentsOf: lines)
    }

    func removeDirectEntry(at index: Int) {
        guard directEntries.indices.contains(index) else { return }
        directEntries.remove(at: index)
        reset()
    }
}

// MARK: - Roulette View

struct RouletteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(LanguageManager.self) private var lm
    @Query private var lists: [ChoiceList]
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    @AppStorage("wheelFrameStyle")  private var wheelFrameStyleRaw  = WheelFrameStyle.simple.rawValue
    @AppStorage("wheelColorStyle")  private var wheelColorStyleRaw  = WheelColorStyle.vivid.rawValue
    @AppStorage("pointerStyle")     private var pointerStyleRaw     = PointerStyle.pin.rawValue

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var isLandscape: Bool { verticalSizeClass == .compact }

    @State private var viewModel = RouletteViewModel()
    @State private var selectedList: ChoiceList? = nil
    @State private var showListPicker = false
    @State private var showDirectEntryEditor = false
    @State private var showCustomization = false
    @State private var newEntryText = ""
    @State private var expandedListIDs: Set<PersistentIdentifier> = []

    private var frameStyle: WheelFrameStyle {
        WheelFrameStyle(rawValue: wheelFrameStyleRaw) ?? .simple
    }
    private var wheelColorStyle: WheelColorStyle {
        WheelColorStyle(rawValue: wheelColorStyleRaw) ?? .vivid
    }
    private var pointerStyle: PointerStyle {
        PointerStyle(rawValue: pointerStyleRaw) ?? .pin
    }

    private var wheelSize: CGFloat { 300 }

    private var segments: [String] {
        switch viewModel.inputMode {
        case .savedList:
            return selectedList?.items.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? []
        case .directEntry:
            return viewModel.directEntries
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
        .onAppear { if selectedList == nil { selectedList = lists.first } }
        .onChange(of: lists.count) { _, _ in if selectedList == nil { selectedList = lists.first } }
        .onDisappear { viewModel.cancelSpin() }
        .sheet(isPresented: $showListPicker) { listPickerSheet }
        .sheet(isPresented: $showDirectEntryEditor) { directEntryEditorSheet }
        .sheet(isPresented: $showCustomization) {
            RouletteCustomizationView()
                .environment(\.appTheme, theme)
        }
    }

    // MARK: - Portrait Layout

    private var portraitLayout: some View {
        VStack(spacing: 0) {
            topBar
            inputModeSelector
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            sourceRow
                .padding(.horizontal, 20)
                .padding(.bottom, 4)

            Spacer()

            if segments.count < 2 {
                emptyState
            } else {
                wheelSection(size: wheelSize)
                    .padding(.horizontal, 16)
            }

            Spacer()

            if segments.count >= 2 {
                spinButton
                    .padding(.horizontal, 30)
                    .padding(.bottom, 44)
            }
        }
    }

    // MARK: - Landscape Layout

    private var landscapeLayout: some View {
        VStack(spacing: 0) {
            topBar
            GeometryReader { proxy in
                HStack(alignment: .center, spacing: 0) {
                    // Left: wheel or empty state
                    let rightColumnWidth: CGFloat = 260
                    let leftWidth = proxy.size.width - rightColumnWidth
                    // 56pt = pointer overshoot (20) + 36pt breathing room top+bottom
                    let dynamicSize = max(180, min(leftWidth - 48, proxy.size.height - 56))

                    if segments.count < 2 {
                        emptyState.frame(maxWidth: .infinity)
                    } else {
                        wheelSection(size: dynamicSize)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                    }

                    // Right column: controls
                    VStack(spacing: 10) {
                        inputModeSelector
                        sourceRow
                        Spacer()
                        if segments.count >= 2 {
                            spinButton
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                    .frame(width: rightColumnWidth)
                }
            }
        }
    }

    // MARK: - Top Bar

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
            Text(lm.t("mode.roulette.title"))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Button { showCustomization = true } label: {
                Image(systemName: "paintbrush.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.pressableLight)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    // MARK: - Input Mode Selector

    private var inputModeSelector: some View {
        HStack(spacing: 0) {
            ForEach(ItemInputMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        viewModel.inputMode = mode
                        viewModel.reset()
                    }
                } label: {
                    Text(lm.t(mode.labelKey))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(viewModel.inputMode == mode ? .white : .white.opacity(0.62))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            viewModel.inputMode == mode
                                ? theme.primary.opacity(0.28)
                                : Color.clear
                        )
                }
            }
        }
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(.white.opacity(0.1), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    // MARK: - Source Row

    @ViewBuilder
    private var sourceRow: some View {
        switch viewModel.inputMode {
        case .savedList:
            Button { showListPicker = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.primary)
                    Text(selectedList?.name ?? lm.t("draw.pickList"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(.white.opacity(0.09), lineWidth: 1))
            }
        case .directEntry:
            Button { showDirectEntryEditor = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.primary)
                    Text(viewModel.directEntries.isEmpty
                         ? lm.t("roulette.direct.enterItems")
                         : (viewModel.directEntries.count == 1 ? lm.t("lists.item.singular") : String(format: lm.t("lists.item.plural"), viewModel.directEntries.count)))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(lm.t("button.edit"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(.white.opacity(0.09), lineWidth: 1))
            }
        }
    }

    // MARK: - Wheel Section

    private func wheelSection(size: CGFloat) -> some View {
        ZStack {
            // Wheel
            WheelView(segments: segments, centerColor: theme.primary, colorStyle: wheelColorStyle)
                .rotationEffect(.degrees(viewModel.rotationAngle))
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
                .overlay { frameOverlay(style: frameStyle, size: size) }

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
            .frame(height: size)
            .offset(y: -20)

            // Result overlay
            if let result = viewModel.result {
                resultCard(for: result)
                    .transition(.scale(scale: 0.65).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.72), value: viewModel.result != nil)
    }

    // MARK: - Frame Overlay

    @ViewBuilder
    private func frameOverlay(style: WheelFrameStyle, size: CGFloat) -> some View {
        switch style {
        case .none:
            EmptyView()
        case .simple:
            EmptyView()  // WheelView draws its own subtle ring
        case .thick:
            Circle()
                .stroke(theme.primary, lineWidth: 9)
                .frame(width: size - 4, height: size - 4)
                .shadow(color: theme.primary.opacity(0.3), radius: 6)
        case .glow:
            ZStack {
                Circle()
                    .stroke(Color(hex: "FFE66D").opacity(0.5), lineWidth: 8)
                    .frame(width: size - 2, height: size - 2)
                    .blur(radius: 6)
                Circle()
                    .stroke(Color(hex: "FFE66D"), lineWidth: 2.5)
                    .frame(width: size - 4, height: size - 4)
            }
            .shadow(color: Color(hex: "FFE66D").opacity(0.6), radius: 14)
        case .casino:
            ZStack {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [Color(hex: "FFD700"), Color(hex: "FFA000"), Color(hex: "FFD700"), Color(hex: "FFF0AA"), Color(hex: "FFA000"), Color(hex: "FFD700")],
                            center: .center
                        ),
                        lineWidth: 7
                    )
                    .frame(width: size - 4, height: size - 4)
                Circle()
                    .stroke(Color(hex: "FFD700").opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    .frame(width: size + 10, height: size + 10)
            }
            .shadow(color: Color(hex: "FFD700").opacity(0.5), radius: 10)
        case .premium:
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [Color(hex: "C8C8C8"), Color(hex: "FFFFFF"), Color(hex: "888888"), Color(hex: "E8E8E8"), Color(hex: "C8C8C8")],
                        center: .center
                    ),
                    lineWidth: 6
                )
                .frame(width: size - 4, height: size - 4)
                .shadow(color: .white.opacity(0.25), radius: 5)
        }
    }

    // MARK: - Result Card

    @ViewBuilder
    private func resultCard(for result: String) -> some View {
        VStack(spacing: 14) {
            Text("🎉")
                .font(.system(size: 44))
            Text(result)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .shadow(color: .black.opacity(0.4), radius: 4)
            HStack(spacing: 12) {
                Button { viewModel.reset() } label: {
                    Text(lm.t("button.again"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(viewModel.winnerColor.contrastingText)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(viewModel.winnerColor, in: Capsule())
                        .shadow(color: viewModel.winnerColor.opacity(0.45), radius: 6, y: 3)
                }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 26)
        .padding(.horizontal, 30)
        .background(
            ZStack {
                // Always-dark base — guarantees white text contrast regardless of winner color
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.black.opacity(0.78))
                // Subtle color tint from winner — visible but never overwhelms readability
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(LinearGradient(
                        colors: [viewModel.winnerColor.opacity(0.35), viewModel.winnerColor.opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                // Colored border echoes the winner color without lightening the card
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(viewModel.winnerColor.opacity(0.55), lineWidth: 1.5)
            }
        )
        .innerHighlight(cornerRadius: 26, intensity: 0.12)
        .shadow(color: viewModel.winnerColor.opacity(0.45), radius: 24, y: 10)
        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    }

    // MARK: - Spin Button

    private var spinButton: some View {
        Button {
            viewModel.spin(items: segments, palette: wheelColorStyle.colors, hapticsEnabled: hapticsEnabled)
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
            .shadow(color: theme.primary.opacity(viewModel.isSpinning ? 0.12 : 0.40), radius: 12, y: 6)
        }
        .disabled(viewModel.isSpinning)
        .buttonStyle(.pressable)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isSpinning)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "circle.grid.cross")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.35))
            switch viewModel.inputMode {
            case .savedList:
                Text(lists.isEmpty
                     ? lm.t("roulette.empty.noLists")
                     : lm.t("roulette.empty.listEmpty"))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            case .directEntry:
                VStack(spacing: 8) {
                    Text(lm.t("roulette.empty.min2"))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(lm.t("roulette.empty.addHint"))
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    // MARK: - List Picker Sheet

    private var listPickerSheet: some View {
        NavigationStack {
            List(lists) { list in
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        Button {
                            selectedList = list
                            viewModel.reset()
                            showListPicker = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(list.name)
                                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.primary)
                                    Text(list.items.count == 1 ? lm.t("lists.item.singular") : String(format: lm.t("lists.item.plural"), list.items.count))
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if list === selectedList {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(theme.primary)
                                        .padding(.trailing, 8)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                if expandedListIDs.contains(list.id) {
                                    expandedListIDs.remove(list.id)
                                } else {
                                    expandedListIDs.insert(list.id)
                                }
                            }
                        } label: {
                            Image(systemName: expandedListIDs.contains(list.id) ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                                .padding(.leading, 12)
                        }
                        .buttonStyle(.plain)
                    }

                    if expandedListIDs.contains(list.id) {
                        let visibleItems = list.items.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(visibleItems, id: \.self) { item in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(theme.primary.opacity(0.55))
                                        .frame(width: 5, height: 5)
                                    Text(item)
                                        .font(.system(size: 14, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .padding(.leading, 2)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .navigationTitle(lm.t("draw.pickList"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lm.t("button.close")) { showListPicker = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Direct Entry Editor Sheet

    private var directEntryEditorSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Input field
                HStack(spacing: 8) {
                    TextField(lm.t("roulette.direct.placeholder"), text: $newEntryText)
                        .font(.system(size: 16, design: .rounded))
                        .tint(theme.primary)
                        .submitLabel(.done)
                        .onSubmit {
                            viewModel.addDirectEntry(text: newEntryText)
                            newEntryText = ""
                        }
                    if !newEntryText.isEmpty {
                        Button {
                            viewModel.addDirectEntry(text: newEntryText)
                            newEntryText = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(theme.primary)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: newEntryText.isEmpty)

                if viewModel.directEntries.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "text.badge.plus")
                            .font(.system(size: 44))
                            .foregroundStyle(theme.primary.opacity(0.5))
                        Text(lm.t("roulette.direct.emptyHint"))
                            .font(.system(size: 16, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text(lm.t("roulette.direct.pasteHint"))
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(Array(viewModel.directEntries.enumerated()), id: \.offset) { index, entry in
                            HStack {
                                Text(entry)
                                    .font(.system(size: 16, design: .rounded))
                                Spacer()
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets.sorted().reversed() {
                                viewModel.removeDirectEntry(at: index)
                            }
                        }
                    }
                }
            }
            .navigationTitle(lm.t("roulette.direct.title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(lm.t("button.ok")) { showDirectEntryEditor = false }
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
                if !viewModel.directEntries.isEmpty {
                    ToolbarItem(placement: .cancellationAction) {
                        EditButton()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Wheel Drawing

struct WheelView: View {
    let segments: [String]
    var centerColor: Color = Color(hex: "FF6B6B")
    var colorStyle: WheelColorStyle = .vivid

    var body: some View {
        Canvas { context, size in
            guard !segments.isEmpty else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 4
            let count = segments.count
            let segAngle = 2 * Double.pi / Double(count)

            for i in 0..<count {
                let startAngle = Double(i) * segAngle - Double.pi / 2
                let endAngle = startAngle + segAngle
                let midAngle = startAngle + segAngle / 2

                var path = Path()
                path.move(to: center)
                path.addArc(center: center, radius: radius,
                            startAngle: .radians(startAngle), endAngle: .radians(endAngle),
                            clockwise: false)
                path.closeSubpath()
                context.fill(path, with: .color(colorStyle.colors[i % colorStyle.colors.count]))

                var highlight = Path()
                highlight.move(to: center)
                highlight.addArc(center: center, radius: radius,
                                 startAngle: .radians(startAngle),
                                 endAngle: .radians(startAngle + segAngle * 0.18),
                                 clockwise: false)
                highlight.closeSubpath()
                context.fill(highlight, with: .color(.white.opacity(0.1)))

                var line = Path()
                line.move(to: center)
                line.addLine(to: CGPoint(
                    x: center.x + radius * cos(startAngle),
                    y: center.y + radius * sin(startAngle)
                ))
                context.stroke(line, with: .color(.white.opacity(0.5)), lineWidth: 1.5)

                let labelRadius = radius * 0.65
                let labelPoint = CGPoint(
                    x: center.x + labelRadius * cos(midAngle),
                    y: center.y + labelRadius * sin(midAngle)
                )
                let raw = segments[i]
                let label = raw
                let availableRadial = radius * 0.55
                let sizeByCount = 100.0 / Double(count)
                let sizeByLength = Double(availableRadial) / max(1.0, Double(raw.count) * 0.62)
                let fontSize = max(7.0, min(14.0, min(sizeByCount, sizeByLength)))

                let segmentColor = colorStyle.colors[i % colorStyle.colors.count]
                let labelColor: Color = segmentColor.isLight ? Color(white: 0.12) : .white
                context.drawLayer { ctx in
                    ctx.translateBy(x: labelPoint.x, y: labelPoint.y)
                    var textAngle = midAngle
                    if cos(midAngle) < 0 { textAngle += .pi }
                    ctx.rotate(by: .radians(textAngle))
                    ctx.draw(
                        Text(label)
                            .font(.system(size: fontSize, weight: .bold, design: .rounded))
                            .foregroundStyle(labelColor),
                        at: .zero,
                        anchor: .center
                    )
                }
            }

            var outerRing = Path()
            outerRing.addEllipse(in: CGRect(
                x: center.x - radius - 1, y: center.y - radius - 1,
                width: (radius + 1) * 2, height: (radius + 1) * 2
            ))
            context.stroke(outerRing, with: .color(.white.opacity(0.55)), lineWidth: 3.5)

            var innerRing = Path()
            innerRing.addEllipse(in: CGRect(
                x: center.x - radius + 2, y: center.y - radius + 2,
                width: (radius - 2) * 2, height: (radius - 2) * 2
            ))
            context.stroke(innerRing, with: .color(.black.opacity(0.12)), lineWidth: 2)

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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            segments.isEmpty
                ? "Roulette vide"
                : "Roulette avec \(segments.count) options : \(segments.joined(separator: ", "))"
        )
    }
}

#Preview {
    RouletteView()
        .modelContainer(for: ChoiceList.self, inMemory: true)
}
