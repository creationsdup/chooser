import SwiftUI
import SwiftData

struct MyListsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) private var lm
    @Query(sort: \ChoiceList.createdAt, order: .reverse) private var lists: [ChoiceList]

    @State private var showCreateSheet = false
    @State private var newListName = ""
    @State private var newListEmoji = ""
    @State private var listToEdit: ChoiceList? = nil

    var body: some View {
        Group {
            if lists.isEmpty {
                emptyState
            } else {
                listContent
            }
        }
        .navigationTitle(lm.t("lists.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showCreateSheet = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                }
            }
        }
        .sheet(isPresented: $showCreateSheet, onDismiss: { newListName = ""; newListEmoji = "" }) {
            createListSheet
        }
        .sheet(item: $listToEdit) { list in
            EditListSheet(list: list)
                .environment(lm)
        }
    }

    // MARK: List content

    private var listContent: some View {
        List {
            ForEach(lists) { list in
                NavigationLink(destination: ListDetailView(list: list)) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(listColor(for: list).opacity(0.15))
                                .frame(width: 44, height: 44)
                            if list.emoji.isEmpty {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(listColor(for: list))
                            } else {
                                Text(list.emoji)
                                    .font(.system(size: 26))
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(list.name)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                            Text(itemCountLabel(list.items.count))
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        listToEdit = list
                    } label: {
                        Label(lm.t("lists.rename"), systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
            .onDelete(perform: deleteLists)
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor.opacity(0.6))

            Text(lm.t("lists.empty.title"))
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text(lm.t("lists.empty.body"))
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button { showCreateSheet = true } label: {
                Label(lm.t("lists.create"), systemImage: "plus.circle.fill")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(30)
    }

    // MARK: Create sheet

    private var createListSheet: some View {
        NavigationStack {
            Form {
                Section(lm.t("lists.new.nameSection")) {
                    HStack(spacing: 12) {
                        EmojiField(emoji: $newListEmoji)
                        TextField(lm.t("lists.new.placeholder"), text: $newListName)
                            .font(.system(size: 17, design: .rounded))
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(lm.t("lists.new.title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lm.t("button.cancel")) { showCreateSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lm.t("button.create")) { createList() }
                        .disabled(newListName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
            }
        }
        .presentationDetents([.height(200)])
    }

    // MARK: Helpers

    private func itemCountLabel(_ count: Int) -> String {
        if count == 1 { return lm.t("lists.item.singular") }
        return String(format: lm.t("lists.item.plural"), count)
    }

    private func createList() {
        let trimmed = newListName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(ChoiceList(name: trimmed, emoji: newListEmoji))
        newListName = ""
        newListEmoji = ""
        showCreateSheet = false
    }

    private func deleteLists(_ offsets: IndexSet) {
        for index in offsets { modelContext.delete(lists[index]) }
    }

    private func listColor(for list: ChoiceList) -> Color {
        let colors: [Color] = [
            Color(hex: "FF6B6B"), Color(hex: "4ECDC4"), Color(hex: "A855F7"),
            Color(hex: "10B981"), Color(hex: "F59E0B"), Color(hex: "3B82F6")
        ]
        let hash = list.name.utf8.reduce(0) { $0 &+ Int($1) }
        return colors[abs(hash) % colors.count]
    }
}

// MARK: - Emoji Field

struct EmojiField: View {
    @Binding var emoji: String
    @State private var showPicker = false

    var body: some View {
        Button { showPicker = true } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 48, height: 48)

                if emoji.isEmpty {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                } else {
                    Text(emoji)
                        .font(.system(size: 28))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.accentColor.opacity(emoji.isEmpty ? 0 : 0.45), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPicker) {
            EmojiPickerSheet(selectedEmoji: $emoji)
        }
    }
}

// MARK: - Edit List Sheet

struct EditListSheet: View {
    let list: ChoiceList
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var lm

    @State private var name: String
    @State private var emoji: String
    @FocusState private var nameFocused: Bool

    init(list: ChoiceList) {
        self.list = list
        _name  = State(initialValue: list.name)
        _emoji = State(initialValue: list.emoji)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(lm.t("lists.new.nameSection")) {
                    HStack(spacing: 12) {
                        EmojiField(emoji: $emoji)
                        TextField(lm.t("lists.new.placeholder"), text: $name)
                            .font(.system(size: 17, design: .rounded))
                            .focused($nameFocused)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(lm.t("lists.rename.title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lm.t("button.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lm.t("button.save")) {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty { list.name = trimmed }
                        list.emoji = emoji
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
            }
            .onAppear { nameFocused = true }
        }
        .presentationDetents([.height(200)])
    }
}

#Preview {
    NavigationStack {
        MyListsView()
    }
    .modelContainer(for: ChoiceList.self, inMemory: true)
    .environment(LanguageManager())
}
