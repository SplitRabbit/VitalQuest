import Foundation
import SwiftData

@Model
final class Activity {
    @Attribute(.unique) var id: UUID

    var name: String
    var icon: String             // SF Symbol name
    var colorName: String        // Theme color (e.g. "pink", "green")
    var isDefault: Bool          // System-provided vs user-created
    var isHidden: Bool           // Soft-delete for defaults, hard-delete for custom
    var sortOrder: Int

    init(
        name: String,
        icon: String,
        colorName: String = "pink",
        isDefault: Bool = false,
        isHidden: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorName = colorName
        self.isDefault = isDefault
        self.isHidden = isHidden
        self.sortOrder = sortOrder
    }
}

// MARK: - Default Activities

extension Activity {
    static let defaults: [(name: String, icon: String, color: String)] = [
        ("Running",            "figure.run",            "pink"),
        ("Cycling",            "figure.outdoor.cycle",  "green"),
        ("Walking",            "figure.walk",           "cyan"),
        ("Swimming",           "figure.pool.swim",      "blue"),
        ("Yoga",               "figure.yoga",           "purple"),
        ("Hiking",             "figure.hiking",         "green"),
        ("Strength Training",  "dumbbell.fill",         "orange"),
        ("HIIT",               "bolt.heart.fill",       "pink"),
        ("Elliptical",         "figure.elliptical",     "cyan"),
        ("Rowing",             "figure.rower",          "blue"),
        ("Dance",              "figure.dance",          "purple"),
        ("Pilates",            "figure.pilates",        "pink"),
        ("Cross Training",     "figure.cross.training", "orange"),
    ]

    /// Seed default activities into the model context if none exist.
    static func seedDefaults(context: ModelContext) {
        let descriptor = FetchDescriptor<Activity>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        for (index, def) in defaults.enumerated() {
            let activity = Activity(
                name: def.name,
                icon: def.icon,
                colorName: def.color,
                isDefault: true,
                sortOrder: index
            )
            context.insert(activity)
        }
    }

    /// Look up an activity by name, returning icon and color. Falls back to generic if not found.
    static func lookup(name: String, in context: ModelContext) -> (icon: String, colorName: String) {
        let predicate = #Predicate<Activity> { $0.name == name && !$0.isHidden }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        if let match = try? context.fetch(descriptor).first {
            return (match.icon, match.colorName)
        }
        return ("figure.mixed.cardio", "pink")
    }
}
