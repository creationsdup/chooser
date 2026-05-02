import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) private var lm
    @Query private var lists: [ChoiceList]

    @State private var showResetConfirm = false

    var body: some View {
        @Bindable var langMgr = lm

        Form {
            // ── Langue ────────────────────────────────────────────────────
            Section {
                ForEach(AppLanguage.allCases) { lang in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            lm.language = lang
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lm.displayName(for: lang))
                                    .font(.system(size: 16, design: .rounded))
                                    .foregroundStyle(.primary)
                                if let detail = lm.detailName(for: lang) {
                                    Text(detail)
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if lm.language == lang {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                                    .font(.system(size: 18))
                            }
                        }
                    }
                }
            } header: {
                Text(lm.t("settings.language.section"))
            }

            // ── Statistiques ──────────────────────────────────────────────
            Section {
                HStack {
                    Label(lm.t("settings.stats.lists"), systemImage: "list.bullet.clipboard.fill")
                    Spacer()
                    Text("\(lists.count)")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 15, design: .rounded))
                }
                HStack {
                    Label(lm.t("settings.stats.items"), systemImage: "circle.grid.3x3.fill")
                    Spacer()
                    Text("\(lists.flatMap(\.items).count)")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 15, design: .rounded))
                }
            } header: {
                Text(lm.t("settings.stats"))
            }

            // ── Zone de danger ────────────────────────────────────────────
            Section {
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label(lm.t("settings.reset"), systemImage: "trash.fill")
                }
            } header: {
                Text(lm.t("settings.danger"))
            } footer: {
                Text(lm.t("settings.reset.footer"))
            }

            // ── À propos ──────────────────────────────────────────────────
            Section {
                HStack {
                    Label(lm.t("settings.version"), systemImage: "info.circle.fill")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 15, design: .rounded))
                }
            } header: {
                Text(lm.t("settings.about"))
            }
        }
        .navigationTitle(lm.t("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            lm.t("settings.reset.confirm"),
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button(lm.t("settings.reset.action"), role: .destructive) {
                for list in lists { modelContext.delete(list) }
            }
            Button(lm.t("button.cancel"), role: .cancel) {}
        } message: {
            Text(lm.t("settings.reset.message"))
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: ChoiceList.self, inMemory: true)
    .environment(LanguageManager())
}
