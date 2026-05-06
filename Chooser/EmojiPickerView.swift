import SwiftUI

// MARK: - Emoji Category

enum EmojiCategory: CaseIterable {
    case popular, media, food, sport, work, nature, animals

    var icon: String {
        switch self {
        case .popular: return "⭐"
        case .media:   return "🎬"
        case .food:    return "🍕"
        case .sport:   return "⚽"
        case .work:    return "💼"
        case .nature:  return "🌿"
        case .animals: return "🐶"
        }
    }

    var labelKey: String {
        switch self {
        case .popular: return "emoji.cat.popular"
        case .media:   return "emoji.cat.media"
        case .food:    return "emoji.cat.food"
        case .sport:   return "emoji.cat.sport"
        case .work:    return "emoji.cat.work"
        case .nature:  return "emoji.cat.nature"
        case .animals: return "emoji.cat.animals"
        }
    }

    var emojis: [String] {
        switch self {
        case .popular:
            return ["🎬","🎵","📚","🍕","✈️","💪","💼","🏠","❤️","⭐",
                    "🔥","🎉","🎮","🎨","📝","🏆","🎯","💡","🌈","🚀",
                    "💰","🎁","🎂","🌸","⚽","🍺","☕","🌊","🐶","🎸"]
        case .media:
            return ["🎬","🎵","🎮","🎨","📚","📷","🎭","🎤","🎼","🎻",
                    "🥁","🎸","🎹","🎺","🎷","📺","🎧","📻","🎪","🎡",
                    "🎢","🎠","🃏","🎲","♟️","🎯","🎳","🎰","🎟️","🖼️"]
        case .food:
            return ["🍕","🍣","🍜","🍔","🌮","🍰","☕","🍺","🥗","🍦",
                    "🧁","🍱","🥐","🍷","🥟","🍛","🥩","🍖","🥪","🌯",
                    "🧆","🥚","🍳","🥞","🧇","🥓","🌽","🥦","🍇","🍓"]
        case .sport:
            return ["⚽","🏀","🎾","🏊","🧘","🚴","🏋️","🎯","🥊","🎿",
                    "⛷️","🏄","🤿","🧗","🏇","⛺","🥋","🤸","🏌️","🏸",
                    "🏒","⛳","🏹","🛹","🥌","🏆","🥇","🥈","🥉","🎖️"]
        case .work:
            return ["💼","📱","💻","📊","🔬","🎓","📝","🗂️","📌","✉️",
                    "📅","🏢","🔭","⚙️","🔧","🔨","🏗️","📐","📏","🔑",
                    "💊","🩺","⚖️","📈","📉","💡","🔎","🗃️","🖨️","🖱️"]
        case .nature:
            return ["🌸","🌊","🏔️","🌈","⭐","🔥","🌙","☀️","🌲","🌺",
                    "🌻","🌼","🌷","🍀","🌿","🍃","🍂","🍁","🌾","🌵",
                    "🌴","🎋","🍄","🌋","🏝️","❄️","⛄","🌪️","🌤️","🌦️"]
        case .animals:
            return ["🐶","🐱","🐭","🐻","🦊","🐺","🦁","🐯","🐸","🐢",
                    "🦄","🐧","🦋","🐝","🐙","🦈","🐬","🦅","🦜","🐠",
                    "🦒","🦓","🐘","🦏","🐊","🐿️","🦔","🐇","🦌","🐓"]
        }
    }
}

// MARK: - Emoji Picker Sheet

struct EmojiPickerSheet: View {
    @Binding var selectedEmoji: String
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var lm

    @State private var selectedCategory: EmojiCategory = .popular

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 6)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryTabs
                Divider()
                emojiGrid
            }
            .navigationTitle(lm.t("emoji.picker.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lm.t("emoji.picker.remove")) {
                        selectedEmoji = ""
                        dismiss()
                    }
                    .foregroundStyle(.red)
                    .opacity(selectedEmoji.isEmpty ? 0.35 : 1)
                    .disabled(selectedEmoji.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lm.t("button.close")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EmojiCategory.allCases, id: \.self) { cat in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedCategory = cat
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(cat.icon)
                                .font(.system(size: 14))
                            Text(lm.t(cat.labelKey))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(selectedCategory == cat ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            selectedCategory == cat ? Color.accentColor : Color(.secondarySystemFill),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var emojiGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(selectedCategory.emojis, id: \.self) { emoji in
                    Button {
                        selectedEmoji = emoji
                        dismiss()
                    } label: {
                        Text(emoji)
                            .font(.system(size: 34))
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .background(
                                selectedEmoji == emoji
                                    ? Color.accentColor.opacity(0.18)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(
                                        selectedEmoji == emoji ? Color.accentColor.opacity(0.5) : Color.clear,
                                        lineWidth: 1.5
                                    )
                            )
                            .scaleEffect(selectedEmoji == emoji ? 1.08 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: selectedEmoji)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}
