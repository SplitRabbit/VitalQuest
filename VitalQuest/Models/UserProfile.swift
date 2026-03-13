import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var id: String // Singleton: always "main"

    // MARK: - XP & Level
    var totalXP: Int
    var level: Int

    // MARK: - Streaks
    var currentStreak: Int
    var longestStreak: Int
    var lastActiveDate: Date?
    var streakFreezes: Int
    var totalStreakFreezesUsed: Int

    // MARK: - Stats
    var totalQuestsCompleted: Int
    var totalWorkouts: Int
    var totalDaysTracked: Int
    var joinDate: Date

    // MARK: - Goals (customizable)
    var stepGoal: Int
    var calorieGoal: Double
    var sleepGoalHours: Double
    var exerciseGoalMinutes: Double

    init() {
        self.id = "main"
        self.totalXP = 0
        self.level = 1
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastActiveDate = nil
        self.streakFreezes = 1 // Start with one free freeze
        self.totalStreakFreezesUsed = 0
        self.totalQuestsCompleted = 0
        self.totalWorkouts = 0
        self.totalDaysTracked = 0
        self.joinDate = Date()
        self.stepGoal = 10000
        self.calorieGoal = 500
        self.sleepGoalHours = 8.0
        self.exerciseGoalMinutes = 30
    }

    // MARK: - Level System

    /// XP required to reach a given level: 100 × n^1.5
    static func xpRequired(forLevel n: Int) -> Int {
        Int(100.0 * pow(Double(n), 1.5))
    }

    /// Total cumulative XP needed to reach a given level
    static func cumulativeXP(forLevel n: Int) -> Int {
        (1..<n).reduce(0) { $0 + xpRequired(forLevel: $1) }
    }

    /// XP progress within current level (0.0 to 1.0)
    var levelProgress: Double {
        let currentLevelXP = Self.cumulativeXP(forLevel: level)
        let nextLevelXP = Self.cumulativeXP(forLevel: level + 1)
        let range = nextLevelXP - currentLevelXP
        guard range > 0 else { return 0 }
        return Double(totalXP - currentLevelXP) / Double(range)
    }

    /// XP still needed for next level
    var xpToNextLevel: Int {
        let nextLevelXP = Self.cumulativeXP(forLevel: level + 1)
        return max(0, nextLevelXP - totalXP)
    }

    /// Title based on current level
    var title: String {
        switch level {
        case 1...5: return "Novice"
        case 6...10: return "Apprentice"
        case 11...20: return "Journeyman"
        case 21...30: return "Adept"
        case 31...40: return "Expert"
        case 41...50: return "Master"
        case 51...60: return "Grandmaster"
        case 61...75: return "Legend"
        case 76...99: return "Mythic"
        default: return "Mythic"
        }
    }

    /// Add XP and level up if necessary. Returns number of level-ups.
    @discardableResult
    func addXP(_ amount: Int) -> Int {
        guard amount > 0 else { return 0 }
        totalXP += amount
        var levelUps = 0
        while level < 99 && totalXP >= Self.cumulativeXP(forLevel: level + 1) {
            level += 1
            levelUps += 1
        }
        return levelUps
    }
}
