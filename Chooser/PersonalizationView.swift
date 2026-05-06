import SwiftUI

// MARK: - Personalization View

struct PersonalizationView: View {
    @Environment(LanguageManager.self)    private var lm
    @Environment(AppearanceManager.self) private var appearance

    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    var body: some View {
        @Bindable var mgr = appearance

        Form {

            // ── Apparence ─────────────────────────────────────────────────
            Section {
                ColorSchemePicker(selected: $mgr.colorScheme)
            } header: {
                SectionHeader(label: lm.t("appearance.colorScheme"), icon: "circle.lefthalf.filled")
            }

            // ── Couleur d'accent ───────────────────────────────────────────
            Section {
                AccentColorPicker(selected: $mgr.accentColor)
            } header: {
                SectionHeader(label: lm.t("appearance.accentColor"), icon: "paintpalette.fill")
            } footer: {
                Text(lm.t("appearance.accentColor.footer"))
            }

            // ── Style visuel ───────────────────────────────────────────────
            Section {
                VisualStylePicker(selected: $mgr.visualStyle)
            } header: {
                SectionHeader(label: lm.t("appearance.visualStyle"), icon: "wand.and.stars")
            } footer: {
                Text(lm.t("appearance.visualStyle.footer"))
            }

            // ── Expérience ─────────────────────────────────────────────────
            Section {
                Toggle(isOn: $hapticsEnabled) {
                    Label(lm.t("settings.haptics"), systemImage: "hand.tap.fill")
                }
                Toggle(isOn: $mgr.animationsReduced) {
                    Label(lm.t("appearance.animations.reduced"), systemImage: "figure.walk.motion")
                }
            } header: {
                SectionHeader(label: lm.t("appearance.experience"), icon: "hand.tap.fill")
            } footer: {
                Text(lm.t("appearance.experience.footer"))
            }
        }
        .navigationTitle(lm.t("personalization.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let label: String
    let icon: String

    var body: some View {
        Label(label, systemImage: icon)
            .textCase(nil)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
    }
}

// MARK: - Color Scheme Picker

private struct ColorSchemePicker: View {
    @Binding var selected: AppColorScheme
    @Environment(LanguageManager.self) private var lm

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppColorScheme.allCases) { scheme in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                        selected = scheme
                        hapticImpact(.light)
                    }
                } label: {
                    VStack(spacing: 7) {
                        Image(systemName: scheme.icon)
                            .font(.system(size: 19, weight: .medium))
                            .foregroundStyle(selected == scheme ? .white : Color(.secondaryLabel))
                        Text(lm.t(scheme.labelKey))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(selected == scheme ? .white : Color(.secondaryLabel))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        selected == scheme ? Color.accentColor : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: selected)
            }
        }
        .padding(4)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Accent Color Picker

private struct AccentColorPicker: View {
    @Binding var selected: AppAccentColor

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppAccentColor.allCases) { accent in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                        selected = accent
                        hapticImpact(.light)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(accent.color)
                            .frame(width: 36, height: 36)
                            .shadow(
                                color: accent.color.opacity(selected == accent ? 0.55 : 0.20),
                                radius: selected == accent ? 8 : 3,
                                y: 2
                            )

                        if selected == accent {
                            Circle()
                                .stroke(.white, lineWidth: 2.5)
                                .frame(width: 36, height: 36)
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(.white)
                        }
                    }
                    .scaleEffect(selected == accent ? 1.14 : 1.0)
                    .animation(.spring(response: 0.28, dampingFraction: 0.6), value: selected)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Visual Style Picker

private struct VisualStylePicker: View {
    @Binding var selected: AppVisualStyle
    @Environment(LanguageManager.self) private var lm

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(AppVisualStyle.allCases.enumerated()), id: \.element.id) { index, style in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selected = style
                        hapticImpact(.light)
                    }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    selected == style
                                        ? Color.accentColor.opacity(0.15)
                                        : Color(.tertiarySystemFill)
                                )
                                .frame(width: 44, height: 44)
                            Image(systemName: style.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(selected == style ? Color.accentColor : Color.secondary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(lm.t(style.labelKey))
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(lm.t(style.descKey))
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if selected == style {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: selected)

                if index < AppVisualStyle.allCases.count - 1 {
                    Divider()
                        .padding(.leading, 58)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PersonalizationView()
    }
    .environment(LanguageManager())
    .environment(AppearanceManager())
}
