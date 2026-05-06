import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(LanguageManager.self)    private var lm
    @Environment(AppearanceManager.self) private var appearance
    @Environment(\.modelContext)          private var modelContext

    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label(lm.t("tab.home"), systemImage: "square.grid.2x2.fill")
            }

            NavigationStack {
                MyListsView()
            }
            .tabItem {
                Label(lm.t("tab.lists"), systemImage: "list.bullet.clipboard.fill")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(lm.t("tab.settings"), systemImage: "gearshape.fill")
            }
        }
        .tint(appearance.accent)
        .environment(\.appTheme, appearance.resolvedTheme)
        .onAppear { seedDefaultListsIfNeeded() }
    }

    private func seedDefaultListsIfNeeded() {
        let key = "defaultListsSeeded"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let lang = lm.resolvedLanguageCode
        let isFr = lang == "fr"

        let defaults: [(emoji: String, name: String, items: [String])] = [
            (
                "🎬",
                isFr ? "Films" : "Movies",
                isFr
                    ? ["Inception", "Interstellar", "Parasite", "Pulp Fiction", "Le Seigneur des Anneaux", "Shutter Island"]
                    : ["Inception", "Interstellar", "Parasite", "Pulp Fiction", "The Lord of the Rings", "Shutter Island"]
            ),
            (
                "🍕",
                isFr ? "Restaurants" : "Restaurants",
                isFr
                    ? ["Italien", "Japonais", "Mexicain", "Indien", "Libanais", "Thaïlandais"]
                    : ["Italian", "Japanese", "Mexican", "Indian", "Lebanese", "Thai"]
            ),
            (
                "✈️",
                isFr ? "Voyages" : "Trips",
                isFr
                    ? ["Japon", "Islande", "Portugal", "Maroc", "Argentine", "Thaïlande"]
                    : ["Japan", "Iceland", "Portugal", "Morocco", "Argentina", "Thailand"]
            ),
            (
                "⚽",
                isFr ? "Sports" : "Sports",
                isFr
                    ? ["Football", "Tennis", "Natation", "Vélo", "Course à pied", "Yoga"]
                    : ["Football", "Tennis", "Swimming", "Cycling", "Running", "Yoga"]
            ),
            (
                "🎉",
                isFr ? "Activités" : "Activities",
                isFr
                    ? ["Cinéma", "Bowling", "Karting", "Escape game", "Musée", "Pique-nique"]
                    : ["Cinema", "Bowling", "Karting", "Escape room", "Museum", "Picnic"]
            )
        ]

        for entry in defaults.reversed() {
            modelContext.insert(ChoiceList(name: entry.name, items: entry.items, emoji: entry.emoji))
        }

        UserDefaults.standard.set(true, forKey: key)
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: ChoiceList.self, inMemory: true)
        .environment(LanguageManager())
        .environment(AppearanceManager())
}
