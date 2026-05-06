import SwiftData
import Foundation

@Model
final class ChoiceList {
    var name: String
    var items: [String]
    var createdAt: Date
    var emoji: String

    init(name: String, items: [String] = [], createdAt: Date = .now, emoji: String = "") {
        self.name = name
        self.items = items
        self.createdAt = createdAt
        self.emoji = emoji
    }
}
