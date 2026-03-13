import Foundation
import SwiftData

enum Mood: String, CaseIterable {
    case great, good, okay, rough

    var emoji: String {
        switch self {
        case .great: "😄"
        case .good: "🙂"
        case .okay: "😐"
        case .rough: "😣"
        }
    }
}

@Model
final class JournalEntry {
    @Attribute(.unique) var date: Date

    var hadCoffee: Bool
    var hadAlcohol: Bool
    var stayedHydrated: Bool
    var lateMeal: Bool
    var feltStressed: Bool

    var mood: String
    var lastUpdated: Date

    init(date: Date,
         hadCoffee: Bool = false,
         hadAlcohol: Bool = false,
         stayedHydrated: Bool = false,
         lateMeal: Bool = false,
         feltStressed: Bool = false,
         mood: String = Mood.okay.rawValue) {
        self.date = date
        self.hadCoffee = hadCoffee
        self.hadAlcohol = hadAlcohol
        self.stayedHydrated = stayedHydrated
        self.lateMeal = lateMeal
        self.feltStressed = feltStressed
        self.mood = mood
        self.lastUpdated = Date()
    }
}
