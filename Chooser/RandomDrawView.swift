import SwiftUI
import SwiftData

// MARK: - View Model

@Observable
final class RandomDrawViewModel {
    var displayedItem: String = ""
    var isAnimating = false
    var result: String? = nil

    // Input
    var inputMode: ItemInputMode = .savedList
    var directEntries: [String] = []

    func draw(from items: [String], hapticsEnabled: Bool) {
        guard !items.isEmpty, !isAnimating else { return }
        isAnimating = true
        result = nil
        let winner = items.randomElement() ?? items[0]
        if hapticsEnabled { hapticImpact(.medium) }
        Task {
            let schedule: [(Int, UInt64)] = [
                (10, 70_000_000),
                (6,  120_000_000),
                (4,  230_000_000),
                (2,  390_000_000)
            ]
            for (count, delay) in schedule {
                for _ in 0..<count {
                    guard let random = items.randomElement() else { continue }
                    displayedItem = random
                    try? await Task.sleep(nanoseconds: delay)
                }
            }
            displayedItem = winner
            result = winner
            isAnimating = false
            if hapticsEnabled { hapticSuccess() }
        }
    }

    func reset() {
        result = nil
        displayedItem = ""
    }

    func addDirectEntry(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Support multiline paste: 1 line = 1 entry
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

// MARK: - View

struct RandomDrawView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(LanguageManager.self) private var lm
    @Environment(AppearanceManager.self) private var appearance
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query private var lists: [ChoiceList]
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var isLandscape: Bool { verticalSizeClass == .compact }
    private var isAtmosLight: Bool { appearance.visualStyle == .atmos && colorScheme == .light }
    private var gameFg: Color { isAtmosLight ? Color(hex: "1A1A2E") : .white }

    @State private var viewModel = RandomDrawViewModel()
    @State private var selectedList: ChoiceList? = nil
    @State private var showListPicker = false
    @State private var showSaveSheet = false
    @State private var saveListName = ""
    @State private var newEntryText = ""
    // Reel context — items visible above/below the selection window
    @State private var reelAbove: [String] = ["·", "·"]
    @State private var reelBelow: [String] = ["·", "·"]
    @FocusState private var entryFieldFocused: Bool

    private var validItems: [String] {
        switch viewModel.inputMode {
        case .savedList:
            return selectedList?.items.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? []
        case .directEntry:
            return viewModel.directEntries
        }
    }

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
            if selectedList == nil { selectedList = lists.first }
            refreshIdleReel()
        }
        .onChange(of: lists.count) { _, _ in
            if selectedList == nil { selectedList = lists.first }
        }
        // Update reel context on every item change during animation
        .onChange(of: viewModel.displayedItem) { _, _ in
            guard viewModel.isAnimating, !validItems.isEmpty else { return }
            withAnimation(.easeInOut(duration: 0.07)) {
                reelAbove = (0..<2).map { _ in validItems.randomElement() ?? "·" }
                reelBelow = (0..<2).map { _ in validItems.randomElement() ?? "·" }
            }
        }
        // Restore idle reel after reset
        .onChange(of: viewModel.result) { _, res in
            if res == nil { refreshIdleReel() }
        }
        .onChange(of: selectedList?.id) { _, _ in refreshIdleReel() }
        // Auto-focus keyboard when switching to direct entry mode
        .onChange(of: viewModel.inputMode) { _, mode in
            if mode == .directEntry {
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    entryFieldFocused = true
                }
            } else {
                entryFieldFocused = false
            }
        }
        .sheet(isPresented: $showListPicker) { listPickerSheet }
        .sheet(isPresented: $showSaveSheet) { saveSheet }
    }

    private func refreshIdleReel() {
        guard validItems.count >= 2 else {
            reelAbove = ["·", "·"]
            reelBelow = ["·", "·"]
            return
        }
        reelAbove = (0..<2).map { _ in validItems.randomElement() ?? "·" }
        reelBelow = (0..<2).map { _ in validItems.randomElement() ?? "·" }
    }

    // MARK: - Portrait Layout

    private var portraitLayout: some View {
        VStack(spacing: 0) {
            topBar

            // Reel only shown in savedList mode (direct entry needs keyboard space)
            if viewModel.inputMode == .savedList {
                if validItems.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Spacer(minLength: 12)
                    slotReel
                        .padding(.horizontal, 20)
                    Spacer(minLength: 12)
                }
            } else {
                Spacer(minLength: 16)
            }

            // Controls
            VStack(spacing: 10) {
                inputModeSelector
                sourcePanel
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            bottomActions
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
        }
    }

    // MARK: - Slot Reel

    private let reelItemH: CGFloat = 66

    private var slotReel: some View {
        let h = reelItemH
        let isIdle   = viewModel.displayedItem.isEmpty && !viewModel.isAnimating
        let isResult = viewModel.result != nil
        let centerText = viewModel.displayedItem

        return ZStack(alignment: .center) {

            // Drum background
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.black.opacity(0.30))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(.white.opacity(0.07), lineWidth: 1)
                )

            // ── 5 rows ──────────────────────────────────────────────
            VStack(spacing: 0) {

                // Row 0 – furthest above
                reelSideCell(reelAbove.count > 1 ? reelAbove[1] : "·", distance: 2)
                    .frame(height: h)

                // Row 1 – near above
                reelSideCell(reelAbove.count > 0 ? reelAbove[0] : "·", distance: 1)
                    .frame(height: h)

                // Row 2 – CENTER (selection window)
                Group {
                    if isIdle {
                        VStack(spacing: 7) {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(gameFg.opacity(0.22))
                            Text(lm.t("draw.ready"))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(gameFg.opacity(0.25))
                        }
                    } else {
                        Text(centerText)
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(isResult ? Color(hex: "FFE66D") : gameFg)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 24)
                            .id(centerText)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal:   .move(edge: .bottom).combined(with: .opacity)
                            ))
                            .shadow(
                                color: isResult ? Color(hex: "FFE66D").opacity(0.8) : .clear,
                                radius: 16
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: h)
                .animation(.easeInOut(duration: 0.075), value: centerText)
                .animation(.spring(response: 0.38, dampingFraction: 0.65), value: isResult)

                // Row 3 – near below
                reelSideCell(reelBelow.count > 0 ? reelBelow[0] : "·", distance: 1)
                    .frame(height: h)

                // Row 4 – furthest below
                reelSideCell(reelBelow.count > 1 ? reelBelow[1] : "·", distance: 2)
                    .frame(height: h)
            }

            // ── Selection window frame ──────────────────────────────
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isResult
                        ? LinearGradient(
                            colors: [Color(hex: "FFE66D"), Color(hex: "FFA040")],
                            startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(
                            colors: [theme.primary.opacity(0.7), theme.primary.opacity(0.35)],
                            startPoint: .leading, endPoint: .trailing),
                    lineWidth: isResult ? 2.5 : 1.5
                )
                .frame(height: h + 4)
                .padding(.horizontal, 8)
                .shadow(
                    color: isResult
                        ? Color(hex: "FFE66D").opacity(0.55)
                        : theme.primary.opacity(0.30),
                    radius: isResult ? 20 : 8
                )
                .animation(.spring(response: 0.38, dampingFraction: 0.7), value: isResult)

            // ── Winner seal (top-right corner) ─────────────────────
            if isResult {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(Color(hex: "FFE66D"))
                            .shadow(color: Color(hex: "FFE66D").opacity(0.7), radius: 10)
                            .padding(12)
                    }
                    Spacer()
                }
                .transition(.scale(scale: 0.3).combined(with: .opacity))
            }

            // ── Top + bottom fade masks ─────────────────────────────
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.black.opacity(0.28), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: h * 2.1)
                Spacer()
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.28)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: h * 2.1)
            }
            .allowsHitTesting(false)
        }
        .frame(height: h * 5)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    @ViewBuilder
    private func reelSideCell(_ text: String, distance: Int) -> some View {
        let opacity: Double = distance == 1 ? 0.32 : 0.14
        let size: CGFloat  = distance == 1 ? 19   : 15
        ZStack {
            Text(text)
                .font(.system(size: size, weight: .medium, design: .rounded))
                .foregroundStyle(gameFg.opacity(opacity))
                .lineLimit(1)
                .padding(.horizontal, 24)
                .id(text)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal:   .move(edge: .bottom).combined(with: .opacity)
                ))
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var landscapeLayout: some View {
        VStack(spacing: 0) {
            topBar
            HStack(alignment: .top, spacing: 0) {
                // Left: result area + draw button
                VStack(spacing: 0) {
                    Spacer()
                    if validItems.isEmpty {
                        emptyState
                    } else {
                        slotMachineSection
                    }
                    Spacer()
                    bottomActions
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity)

                // Right: mode selector + source panel
                VStack(spacing: 10) {
                    inputModeSelector
                    sourcePanel
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(width: 280)
            }
        }
    }

    // MARK: - Top Bar

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
            Text(lm.t("mode.randomDraw.title"))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(gameFg)
            Spacer()
            itemCountBadge
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var itemCountBadge: some View {
        if !validItems.isEmpty {
            Text("\(validItems.count)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(isAtmosLight ? theme.primary : .white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(theme.primary.opacity(0.3), in: Capsule())
                .overlay(Capsule().stroke(theme.primary.opacity(0.5), lineWidth: 1))
        } else {
            Color.clear.frame(width: 36, height: 28)
        }
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
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(viewModel.inputMode == mode ? .white : gameFg.opacity(0.45))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            viewModel.inputMode == mode
                                ? theme.primary.opacity(0.28)
                                : Color.clear
                        )
                }
            }
        }
        .background(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.06) : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.10) : Color.white.opacity(0.1), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Source Panel

    @ViewBuilder
    private var sourcePanel: some View {
        switch viewModel.inputMode {
        case .savedList:  savedListPanel
        case .directEntry: directEntryPanel
        }
    }

    private var savedListPanel: some View {
        Button { showListPicker = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.primary)
                Text(selectedList?.name ?? lm.t("draw.pickList"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(gameFg)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(gameFg.opacity(0.35))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.06) : Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.10) : Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    @ViewBuilder
    private var directEntryPanel: some View {
        VStack(spacing: 8) {
            // Input field
            HStack(spacing: 8) {
                TextField(lm.t("draw.direct.placeholder"), text: $newEntryText)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(gameFg)
                    .tint(theme.primary)
                    .submitLabel(.return)
                    .focused($entryFieldFocused)
                    .onSubmit {
                        viewModel.addDirectEntry(text: newEntryText)
                        newEntryText = ""
                        entryFieldFocused = true
                    }
                if !newEntryText.isEmpty {
                    Button {
                        viewModel.addDirectEntry(text: newEntryText)
                        newEntryText = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(theme.primary)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.06) : Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.12) : Color.white.opacity(0.12), lineWidth: 1))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: newEntryText.isEmpty)

            // Entries list
            if !viewModel.directEntries.isEmpty {
                ScrollView {
                    VStack(spacing: 5) {

                        ForEach(Array(viewModel.directEntries.enumerated()), id: \.offset) { index, entry in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(theme.primary.opacity(0.55))
                                    .frame(width: 7, height: 7)
                                Text(entry)
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundStyle(gameFg)
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                        viewModel.removeDirectEntry(at: index)
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(gameFg.opacity(0.35))
                                        .padding(5)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.05) : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
                .frame(maxHeight: 130)
                .scrollDismissesKeyboard(.interactively)

                // Save as list button
                HStack {
                    Spacer()
                    Button {
                        saveListName = ""
                        showSaveSheet = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 12, weight: .semibold))
                            Text(lm.t("draw.saveAsList"))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(theme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(theme.primary.opacity(0.1), in: Capsule())
                        .overlay(Capsule().stroke(theme.primary.opacity(0.3), lineWidth: 1))
                    }
                }
            }
        }
    }

    // MARK: - Slot Machine Section

    private var slotMachineSection: some View {
        VStack(spacing: 18) {
            ZStack {
                // Card background
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.15))
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.10) : Color.white.opacity(0.12), lineWidth: 1.5)
                    }
                    .innerHighlight(cornerRadius: 26, intensity: 0.10)
                    .shadow(
                        color: theme.primary.opacity(viewModel.isAnimating ? 0.35 : 0),
                        radius: 24, y: 0
                    )
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                    .animation(.easeInOut(duration: 0.6), value: viewModel.isAnimating)

                VStack(spacing: 10) {
                    if viewModel.displayedItem.isEmpty && !viewModel.isAnimating {
                        // Ready state
                        VStack(spacing: 8) {
                            Text("?")
                                .font(.system(size: 64, weight: .black, design: .rounded))
                                .foregroundStyle(gameFg.opacity(0.18))
                            Text(lm.t("draw.ready"))
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(gameFg.opacity(0.3))
                        }
                    } else if let res = viewModel.result {
                        // Result state
                        VStack(spacing: 12) {
                            Text("🎊")
                                .font(.system(size: 36))
                            Text(res)
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundStyle(gameFg)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .shadow(color: theme.primary.opacity(0.6), radius: 10)
                            Text(lm.t("draw.result"))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(theme.primary)
                        }
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    } else {
                        // Animating
                        Text(viewModel.displayedItem)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(gameFg)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .id(viewModel.displayedItem)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                    }
                }
                .padding(.vertical, 32)
            }
            .frame(minHeight: 150)
            .padding(.horizontal, 28)
            .animation(.easeInOut(duration: 0.07), value: viewModel.displayedItem)
            .animation(.spring(response: 0.45, dampingFraction: 0.72), value: viewModel.result != nil)

            // Items preview strip (only in ready state)
            if !viewModel.isAnimating && viewModel.result == nil && validItems.count <= 20 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(validItems, id: \.self) { item in
                            Text(item)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(gameFg.opacity(0.6))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 5)
                                .background(isAtmosLight ? Color(hex: "1A1A2E").opacity(0.06) : Color.white.opacity(0.09), in: Capsule())
                        }
                    }
                    .padding(.horizontal, 28)
                }
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.result != nil)
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        Button {
            if viewModel.result != nil {
                viewModel.reset()
            } else {
                viewModel.draw(from: validItems, hapticsEnabled: hapticsEnabled)
            }
        } label: {
            HStack(spacing: 10) {
                if viewModel.isAnimating {
                    ProgressView().tint(.white).scaleEffect(0.85)
                } else {
                    Image(systemName: viewModel.result != nil ? "arrow.clockwise" : "shuffle")
                        .font(.system(size: 18, weight: .semibold))
                }
                Text(viewModel.isAnimating ? lm.t("draw.drawing") : (viewModel.result != nil ? lm.t("button.again") : lm.t("draw.button")))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                viewModel.isAnimating ? theme.primary.opacity(0.50) : theme.primary,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .shadow(color: theme.primary.opacity(viewModel.isAnimating ? 0.12 : 0.38), radius: 14, y: 6)
        }
        .disabled(viewModel.isAnimating || validItems.isEmpty)
        .buttonStyle(.pressable)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isAnimating)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "ticket")
                .font(.system(size: 56))
                .foregroundStyle(gameFg.opacity(0.3))
            switch viewModel.inputMode {
            case .savedList:
                Text(lists.isEmpty
                     ? lm.t("draw.empty.noLists")
                     : lm.t("draw.empty.listEmpty"))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(gameFg.opacity(0.5))
                    .multilineTextAlignment(.center)
            case .directEntry:
                VStack(spacing: 6) {
                    Text(lm.t("draw.empty.noEntries"))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(gameFg.opacity(0.5))
                    Text(lm.t("draw.empty.noEntries.hint"))
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(gameFg.opacity(0.3))
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    // MARK: - Sheets

    private var listPickerSheet: some View {
        NavigationStack {
            List(lists) { list in
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
                        }
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

    private var saveSheet: some View {
        NavigationStack {
            Form {
                Section(lm.t("lists.new.nameSection")) {
                    TextField(lm.t("draw.save.placeholder"), text: $saveListName)
                        .font(.system(size: 16, design: .rounded))
                        .submitLabel(.done)
                }
                Section {
                    Text(viewModel.directEntries.count == 1 ? lm.t("lists.item.singular") : String(format: lm.t("lists.item.plural"), viewModel.directEntries.count))
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14, design: .rounded))
                }
            }
            .navigationTitle(lm.t("draw.save.title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lm.t("button.cancel")) { showSaveSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lm.t("button.save")) {
                        let name = saveListName.trimmingCharacters(in: .whitespaces)
                        let list = ChoiceList(name: name.isEmpty ? lm.t("draw.save.defaultName") : name, items: viewModel.directEntries)
                        modelContext.insert(list)
                        showSaveSheet = false
                    }
                    .disabled(viewModel.directEntries.isEmpty)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    RandomDrawView()
        .modelContainer(for: ChoiceList.self, inMemory: true)
}
