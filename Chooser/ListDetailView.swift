import SwiftUI
import SwiftData

struct ListDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) private var lm
    let list: ChoiceList

    @State private var newItemText = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        Group {
            if list.items.isEmpty {
                emptyState
                    .toolbar { toolbarContent }
            } else {
                itemList
                    .toolbar { toolbarContent }
            }
        }
        .navigationTitle(list.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .safeAreaInset(edge: .bottom) {
            addItemBar
        }
    }

    // MARK: Item list

    private var itemList: some View {
        List {
            ForEach(Array(list.items.enumerated()), id: \.0) { index, item in
                HStack {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                    Text(item)
                        .font(.system(size: 17, design: .rounded))
                }
                .padding(.vertical, 2)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteItems(IndexSet(integer: index))
                    } label: {
                        Label(lm.t("button.delete"), systemImage: "trash")
                    }
                }
            }
            .onDelete(perform: deleteItems)
            .onMove(perform: moveItems)
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 56))
                .foregroundStyle(.secondary.opacity(0.6))
            Text(lm.t("detail.emptyTitle"))
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text(lm.t("detail.emptyBody"))
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Add item bar

    private var addItemBar: some View {
        HStack(spacing: 10) {
            TextField(lm.t("detail.addPlaceholder"), text: $newItemText)
                .font(.system(size: 16, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                #if os(iOS)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                #else
                .background(Color(.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                #endif
                .focused($fieldFocused)
                .onSubmit { addItem() }

            Button(action: addItem) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(newItemText.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : Color(hex: "4ECDC4"))
            }
            .disabled(newItemText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .primaryAction) {
            EditButton()
        }
        #else
        ToolbarItem(placement: .primaryAction) {
            EmptyView()
        }
        #endif
    }

    // MARK: Actions

    private func addItem() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        list.items.append(trimmed)
        newItemText = ""
    }

    private func deleteItems(_ offsets: IndexSet) {
        list.items.remove(atOffsets: offsets)
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        list.items.move(fromOffsets: source, toOffset: destination)
    }
}

#Preview {
    let list = ChoiceList(name: "Films", items: ["Inception", "Interstellar", "Dune"])
    NavigationStack {
        ListDetailView(list: list)
    }
    .modelContainer(for: ChoiceList.self, inMemory: true)
    .environment(LanguageManager())
}
