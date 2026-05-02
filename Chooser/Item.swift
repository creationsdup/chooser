import SwiftData
import Foundation

@Model
final class ChoiceList {
    var name: String
    var items: [String]
    var createdAt: Date

    init(name: String, items: [String] = [], createdAt: Date = .now) {
        self.name = name
        self.items = items
        self.createdAt = createdAt
    }
}
