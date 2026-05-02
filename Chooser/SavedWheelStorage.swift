import Foundation

// MARK: - Model

struct SavedWheel: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var optionNames: [String]
    var optionWeights: [Double]
    var createdAt: Date = .now
}

// MARK: - Storage

enum WheelStorage {
    private static let key = "savedWeightedWheels"

    static func load() -> [SavedWheel] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let wheels = try? JSONDecoder().decode([SavedWheel].self, from: data)
        else { return [] }
        return wheels
    }

    static func add(_ wheel: SavedWheel) {
        var wheels = load()
        wheels.insert(wheel, at: 0)
        persist(wheels)
    }

    static func delete(id: UUID) {
        var wheels = load()
        wheels.removeAll { $0.id == id }
        persist(wheels)
    }

    private static func persist(_ wheels: [SavedWheel]) {
        if let data = try? JSONEncoder().encode(wheels) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
