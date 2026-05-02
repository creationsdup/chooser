import SwiftUI
import SwiftData

// MARK: - Ranked Item
// @Observable class so each card tracks only its own isRevealed — no shared counter.

@Observable
final class RankedItem: Identifiable {
    let id = UUID()
    let name: String
    let position: Int   // 1-based
    var isRevealed = false

    init(name: String, position: Int) {
        self.name = name
        self.position = position
    }
}

// MARK: - View Model

@Observable
final class RankingViewModel {
    var items: [RankedItem] = []
    var isRevealing = false

    var inputMode: ItemInputMode = .savedList
    var directEntries: [String] = []

    private var revealTask: Task<Void, Never>? = nil

    var isEmpty: Bool { items.isEmpty }

    func startRanking(names: [String], hapticsEnabled: Bool) {
        guard names.count >= 2, !isRevealing else { return }
        revealTask?.cancel()

        items = names.shuffled().enumerated().map { i, name in
            RankedItem(name: name, position: i + 1)
        }
        isRevealing = true
        if hapticsEnabled { hapticImpact(.heavy) }

        // Adaptive delay based on list size
        let delayNs: UInt64
        let count = items.count
        if      count <= 5  { delayNs = 550_000_000 }
        else if count <= 10 { delayNs = 400_000_000 }
        else if count <= 15 { delayNs = 280_000_000 }
        else                { delayNs = 180_000_000 }

        // Capture array snapshot so mutations to self.items (reset) don't corrupt iteration
        let snapshot = items

        revealTask = Task { @MainActor in
            // Reveal from last place → 1st place for suspense
            for i in stride(from: snapshot.count - 1, through: 0, by: -1) {
                try? await Task.sleep(nanoseconds: delayNs)
                guard !Task.isCancelled else { return }
                snapshot[i].isRevealed = true   // only this card's view re-renders
                if hapticsEnabled {
                    i == 0 ? hapticSuccess() : hapticImpact(.light)
                }
            }
            self.isRevealing = false
        }
    }

    func reset() {
        revealTask?.cancel()
        revealTask = nil
        items = []
        isRevealing = false
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
    }
}

// MARK: - Ranking Card View
// Separate struct so SwiftUI tracks identity per card and skips re-renders for unchanged cards.

private struct RankingCardView: View {
    let item: RankedItem
    let badgeColor: Color

    var body: some View {
        HStack(spacing: 14) {

            // ── Badge ──────────────────────────────────────────────────────
            ZStack {
                Circle()
                    .fill(item.isRevealed ? badgeColor.opacity(0.25) : .white.opacity(0.06))
                    .frame(width: 46, height: 46)

                // Plain number — always present, changes style
                if item.position > 3 || !item.isRevealed {
                    Text("\(item.position)")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(item.isRevealed ? badgeColor : .white.opacity(0.2))
                        .opacity(item.isRevealed && item.position <= 3 ? 0 : 1)
                }

                // Medal emoji for top 3 — fades in on reveal
                if item.position <= 3 {
                    Text(medal(item.position))
                        .font(.system(size: 22))
                        .opacity(item.isRevealed ? 1 : 0)
                        .scaleEffect(item.isRevealed ? 1 : 0.4)
                }
            }

            // ── Name zone — opacity cross-fade, no view insertion/removal ─
            ZStack(alignment: .leading) {
                // Dots placeholder
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(.white.opacity(0.15))
                            .frame(width: 5, height: 5)
                    }
                }
                .opacity(item.isRevealed ? 0 : 1)

                // Actual name
                Text(item.name)
                    .font(.system(
                        size: item.position == 1 ? 19 : 16,
                        weight: item.position == 1 ? .black : .semibold,
                        design: .rounded
                    ))
                    .foregroundStyle(item.position == 1 ? Color(hex: "FBBF24") : .white)
                    .lineLimit(2)
                    .opacity(item.isRevealed ? 1 : 0)
                    .offset(x: item.isRevealed ? 0 : 8)
            }

            Spacer()

            // ── Trophy for 1st ─────────────────────────────────────────────
            if item.position == 1 {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(hex: "FBBF24"))
                    .shadow(color: Color(hex: "FBBF24").opacity(0.6), radius: 6)
                    .opacity(item.isRevealed ? 1 : 0)
                    .scaleEffect(item.isRevealed ? 1 : 0.3)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)   // fixed — no layout shift during reveal
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(item.isRevealed ? badgeColor.opacity(0.3) : .white.opacity(0.06), lineWidth: 1)
                )
        )
        .shadow(
            color: item.isRevealed && item.position == 1 ? Color(hex: "FBBF24").opacity(0.18) : .clear,
            radius: 10, y: 4
        )
        .animation(.spring(response: 0.42, dampingFraction: 0.68), value: item.isRevealed)
    }

    private var cardFill: Color {
        guard item.isRevealed else { return .white.opacity(0.04) }
        return item.position == 1 ? Color(hex: "FBBF24").opacity(0.11) : .white.opacity(0.07)
    }

    private func medal(_ pos: Int) -> String {
        switch pos {
        case 1: return "🥇"
        case 2: return "🥈"
        default: return "🥉"
        }
    }
}

// MARK: - Direct Entry Panel
// Isolated in its own struct so keystrokes only re-render this component,
// not the entire RankingView (which would re-render the ranking cards).

private struct DirectEntryPanelView: View {
    let viewModel: RankingViewModel
    let theme: AppTheme
    let lm: LanguageManager
    @Binding var showSaveSheet: Bool

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 8) {
            // Input field
            HStack(spacing: 8) {
                TextField(lm.t("ranking.direct.placeholder"), text: $text)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(.white)
                    .tint(theme.primary)
                    .submitLabel(.return)
                    .focused($focused)
                    .onSubmit {
                        viewModel.addDirectEntry(text: text)
                        text = ""
                        focused = true
                    }
                if !text.isEmpty {
                    Button {
                        viewModel.addDirectEntry(text: text)
                        text = ""
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
            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: text.isEmpty)

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
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                        viewModel.removeDirectEntry(at: index)
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.35))
                                        .padding(5)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
                .frame(maxHeight: 130)
                .scrollDismissesKeyboard(.interactively)
                HStack {
                    Spacer()
                    Button { showSaveSheet = true } label: {
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
        .onAppear {
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                focused = true
            }
        }
    }
}

// MARK: - Ranking View

struct RankingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(LanguageManager.self) private var lm
    @Environment(\.modelContext) private var modelContext
    @Query private var lists: [ChoiceList]
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    @State private var viewModel = RankingViewModel()
    @State private var selectedList: ChoiceList? = nil
    @State private var showListPicker = false
    @State private var showSaveSheet = false
    @State private var saveListName = ""

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
            theme.backgroundGradient.ignoresSafeArea()
            portraitLayout
        }
        .onAppear {
            if selectedList == nil { selectedList = lists.first }
        }
        .onChange(of: lists.count) { _, _ in
            if selectedList == nil { selectedList = lists.first }
        }
        .sheet(isPresented: $showListPicker) { listPickerSheet }
        .sheet(isPresented: $showSaveSheet) { saveSheet }
    }

    // MARK: - Portrait Layout

    private var portraitLayout: some View {
        VStack(spacing: 0) {
            topBar

            if viewModel.isEmpty {
                if validItems.count >= 2 {
                    Spacer(minLength: 16)
                    readyState
                        .padding(.horizontal, 20)
                    Spacer()
                } else {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                VStack(spacing: 10) {
                    inputModeSelector
                    sourcePanel
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            } else {
                rankingList
                    .padding(.horizontal, 16)
            }

            bottomActions
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                if !viewModel.isEmpty {
                    // Results page → return to ready state (don't quit the screen)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.reset()
                    }
                } else {
                    dismiss()
                }
            } label: {
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
            Text(lm.t("mode.ranking.title"))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
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
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(theme.primary.opacity(0.3), in: Capsule())
                .overlay(Capsule().stroke(theme.primary.opacity(0.5), lineWidth: 1))
        } else {
            Color.clear.frame(width: 36, height: 28)
        }
    }

    // MARK: - Ready State

    private var readyState: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                Image(systemName: "list.number")
                    .font(.system(size: 52))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "FBBF24"), theme.primary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(lm.t("ranking.ready.title"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                Text(lm.t("ranking.ready.subtitle"))
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(validItems, id: \.self) { item in
                        Text(item)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.1), in: Capsule())
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Ranking List

    private var rankingList: some View {
        ScrollView {
            LazyVStack(spacing: 7) {
                ForEach(viewModel.items) { item in
                    RankingCardView(
                        item: item,
                        badgeColor: badgeColor(item.position)
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func badgeColor(_ position: Int) -> Color {
        switch position {
        case 1: return Color(hex: "FBBF24")
        case 2: return Color(hex: "94A3B8")
        case 3: return Color(hex: "CD7C2F")
        default: return theme.primary
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
                        .foregroundStyle(viewModel.inputMode == mode ? .white : .white.opacity(0.45))
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
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.1), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Source Panel

    @ViewBuilder
    private var sourcePanel: some View {
        switch viewModel.inputMode {
        case .savedList:
            savedListPanel
        case .directEntry:
            DirectEntryPanelView(
                viewModel: viewModel,
                theme: theme,
                lm: lm,
                showSaveSheet: $showSaveSheet
            )
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
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.1), lineWidth: 1))
        }
    }


    // MARK: - Bottom Actions

    private var bottomActions: some View {
        Button {
            viewModel.startRanking(names: validItems, hapticsEnabled: hapticsEnabled)
        } label: {
            HStack(spacing: 10) {
                if viewModel.isRevealing {
                    ProgressView().tint(.white).scaleEffect(0.85)
                } else {
                    Image(systemName: viewModel.isEmpty ? "list.number" : "arrow.clockwise")
                        .font(.system(size: 18, weight: .semibold))
                }
                Text(buttonLabel)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                viewModel.isRevealing ? theme.primary.opacity(0.50) : theme.primary,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .shadow(color: theme.primary.opacity(viewModel.isRevealing ? 0.12 : 0.38), radius: 14, y: 6)
        }
        .disabled(viewModel.isRevealing || (viewModel.isEmpty && validItems.count < 2))
        .buttonStyle(.pressable)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isRevealing)
    }

    private var buttonLabel: String {
        if viewModel.isRevealing { return lm.t("ranking.revealing") }
        if !viewModel.isEmpty    { return lm.t("ranking.button.again") }
        return lm.t("ranking.button")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.number")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.3))
            switch viewModel.inputMode {
            case .savedList:
                Text(lists.isEmpty
                     ? lm.t("draw.empty.noLists")
                     : (validItems.count == 1 ? lm.t("ranking.empty.min2") : lm.t("draw.empty.listEmpty")))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            case .directEntry:
                VStack(spacing: 6) {
                    Text(viewModel.directEntries.count == 1
                         ? lm.t("ranking.empty.min2")
                         : lm.t("draw.empty.noEntries"))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(lm.t("draw.empty.noEntries.hint"))
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.horizontal, 32)
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
                            Text(list.items.count == 1
                                 ? lm.t("lists.item.singular")
                                 : String(format: lm.t("lists.item.plural"), list.items.count))
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
                    Text(viewModel.directEntries.count == 1
                         ? lm.t("lists.item.singular")
                         : String(format: lm.t("lists.item.plural"), viewModel.directEntries.count))
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
                        let list = ChoiceList(
                            name: name.isEmpty ? lm.t("draw.save.defaultName") : name,
                            items: viewModel.directEntries
                        )
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
    RankingView()
        .modelContainer(for: ChoiceList.self, inMemory: true)
        .environment(LanguageManager())
        .environment(\.appTheme, .coral)
}
