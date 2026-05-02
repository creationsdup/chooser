import SwiftUI
import SwiftData

struct MyListsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) private var lm
    @Query(sort: \ChoiceList.createdAt, order: .reverse) private var lists: [ChoiceList]

    @State private var showCreateSheet = false
    @State private var newListName = ""

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
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                }
            }
        }
        .sheet(isPresented: $showCreateSheet, onDismiss: { newListName = "" }) {
            createListSheet
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
                            Image(systemName: "list.bullet")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(listColor(for: list))
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
            }
            .onDelete(perform: deleteLists)
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 64))
                .foregroundStyle(Color(hex: "4ECDC4").opacity(0.6))

            Text(lm.t("lists.empty.title"))
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text(lm.t("lists.empty.body"))
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showCreateSheet = true
            } label: {
                Label(lm.t("lists.create"), systemImage: "plus.circle.fill")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color(hex: "4ECDC4"), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(30)
    }

    // MARK: Create sheet

    private var createListSheet: some View {
        NavigationStack {
            Form {
                Section(lm.t("lists.new.nameSection")) {
                    TextField(lm.t("lists.new.placeholder"), text: $newListName)
                        .font(.system(size: 17, design: .rounded))
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
                    Button(lm.t("button.create")) {
                        createList()
                    }
                    .disabled(newListName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
            }
        }
        .presentationDetents([.height(220)])
    }

    // MARK: Helpers

    private func itemCountLabel(_ count: Int) -> String {
        if count == 1 { return lm.t("lists.item.singular") }
        let fmt = lm.t("lists.item.plural")
        return String(format: fmt, count)
    }

    private func createList() {
        let trimmed = newListName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(ChoiceList(name: trimmed))
        newListName = ""
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
        // Use a deterministic UTF-8 byte sum instead of hashValue,
        // which is not stable across app launches in Swift.
        let hash = list.name.utf8.reduce(0) { $0 &+ Int($1) }
        return colors[abs(hash) % colors.count]
    }
}

#Preview {
    NavigationStack {
        MyListsView()
    }
    .modelContainer(for: ChoiceList.self, inMemory: true)
    .environment(LanguageManager())
}
