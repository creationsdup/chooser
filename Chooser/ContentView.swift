import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(LanguageManager.self)    private var lm
    @Environment(AppearanceManager.self) private var appearance

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
                PersonalizationView()
            }
            .tabItem {
                Label(lm.t("tab.appearance"), systemImage: "paintpalette.fill")
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
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: ChoiceList.self, inMemory: true)
        .environment(LanguageManager())
        .environment(AppearanceManager())
}
