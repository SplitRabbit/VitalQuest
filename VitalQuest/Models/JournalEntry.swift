import Foundation
import SwiftData

@Model
final class JournalEntry {
    @Attribute(.unique) var date: Date

    var hadCoffee: Bool
    var hadAlcohol: Bool
    var stayedHydrated: Bool
    var lateMeal: Bool
    var feltStressed: Bool

    /// Custom user-created log toggles active for this entry (keyed by CustomLog id)
    var activeCustomLogs: [String]

    var lastUpdated: Date

    init(date: Date,
         hadCoffee: Bool = false,
         hadAlcohol: Bool = false,
         stayedHydrated: Bool = false,
         lateMeal: Bool = false,
         feltStressed: Bool = false) {
        self.date = date
        self.hadCoffee = hadCoffee
        self.hadAlcohol = hadAlcohol
        self.stayedHydrated = stayedHydrated
        self.lateMeal = lateMeal
        self.feltStressed = feltStressed
        self.activeCustomLogs = []
        self.lastUpdated = Date()
    }
}

/// Persistent custom log definition
@Model
final class CustomLog: Identifiable {
    @Attribute(.unique) var id: String
    var label: String
    var icon: String
    var createdAt: Date

    init(label: String, icon: String) {
        self.id = UUID().uuidString
        self.label = label
        self.icon = icon
        self.createdAt = Date()
    }
}
