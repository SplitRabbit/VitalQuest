import Foundation
import SwiftData

@Model
final class Achievement {
    @Attribute(.unique) var id: String // e.g. "streak_7", "level_10"

    var title: String
    var subtitle: String
    var icon: String          // SF Symbol name
    var category: AchievementCategory
    var isUnlocked: Bool
    var unlockedDate: Date?
    var xpReward: Int

    init(
        id: String,
        title: String,
        subtitle: String,
        icon: String,
        category: AchievementCategory,
        xpReward: Int = 40
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.category = category
        self.isUnlocked = false
        self.unlockedDate = nil
        self.xpReward = xpReward
    }

    func unlock() {
        guard !isUnlocked else { return }
        isUnlocked = true
        unlockedDate = Date()
    }
}

enum AchievementCategory: String, Codable, CaseIterable {
    case streak       // Streak milestones
    case score        // Score achievements
    case activity     // Activity feats
    case dataNerd     // Data nerd badges
    case level        // Level milestones

    var label: String {
        switch self {
        case .streak: "Streaks"
        case .score: "Scores"
        case .activity: "Activity"
        case .dataNerd: "Data Nerd"
        case .level: "Levels"
        }
    }

    var icon: String {
        switch self {
        case .streak: "flame.fill"
        case .score: "star.fill"
        case .activity: "figure.run"
        case .dataNerd: "chart.xyaxis.line"
        case .level: "trophy.fill"
        }
    }
}

// MARK: - Seed Data
extension Achievement {
    static var seeds: [Achievement] { [
        // Streak
        Achievement(id: "streak_3", title: "Getting Started", subtitle: "3-day streak", icon: "flame", category: .streak),
        Achievement(id: "streak_7", title: "Week Warrior", subtitle: "7-day streak", icon: "flame.fill", category: .streak, xpReward: 50),
        Achievement(id: "streak_14", title: "Fortnight Focus", subtitle: "14-day streak", icon: "flame.fill", category: .streak, xpReward: 75),
        Achievement(id: "streak_30", title: "Monthly Master", subtitle: "30-day streak", icon: "flame.circle.fill", category: .streak, xpReward: 200),
        Achievement(id: "streak_60", title: "Iron Will", subtitle: "60-day streak", icon: "flame.circle.fill", category: .streak, xpReward: 300),
        Achievement(id: "streak_100", title: "Centurion", subtitle: "100-day streak", icon: "flame.circle.fill", category: .streak, xpReward: 500),

        // Score
        Achievement(id: "recovery_90", title: "Peak Recovery", subtitle: "Recovery score 90+", icon: "bolt.heart.fill", category: .score),
        Achievement(id: "sleep_90", title: "Dream State", subtitle: "Sleep score 90+", icon: "moon.stars.fill", category: .score),
        Achievement(id: "activity_90", title: "Unstoppable", subtitle: "Activity score 90+", icon: "figure.run", category: .score),
        Achievement(id: "all_scores_80", title: "Balanced", subtitle: "All scores 80+ in one day", icon: "scale.3d", category: .score, xpReward: 75),
        Achievement(id: "perfect_day", title: "Perfect Day", subtitle: "All scores 90+ in one day", icon: "sparkles", category: .score, xpReward: 150),

        // Activity
        Achievement(id: "steps_10k", title: "10K Club", subtitle: "10,000 steps in a day", icon: "figure.walk", category: .activity),
        Achievement(id: "steps_20k", title: "Marathon Walker", subtitle: "20,000 steps in a day", icon: "figure.walk.motion", category: .activity, xpReward: 75),
        Achievement(id: "workout_7_days", title: "Gym Rat", subtitle: "Work out 7 days straight", icon: "dumbbell.fill", category: .activity, xpReward: 100),
        Achievement(id: "calories_1000", title: "Furnace", subtitle: "Burn 1,000 active calories", icon: "flame", category: .activity, xpReward: 75),
        Achievement(id: "exercise_60", title: "Hour Power", subtitle: "60+ exercise minutes in a day", icon: "timer", category: .activity),

        // Data Nerd
        Achievement(id: "first_week_data", title: "Data Collector", subtitle: "Complete first week of data", icon: "chart.bar", category: .dataNerd),
        Achievement(id: "month_data", title: "Statistician", subtitle: "30 days of data collected", icon: "chart.bar.fill", category: .dataNerd, xpReward: 100),
        Achievement(id: "baseline_ready", title: "Baseline Built", subtitle: "14-day baselines established", icon: "chart.xyaxis.line", category: .dataNerd, xpReward: 50),
        Achievement(id: "all_metrics", title: "Full Spectrum", subtitle: "All health metrics recorded in one day", icon: "waveform.path.ecg", category: .dataNerd, xpReward: 75),

        // Level
        Achievement(id: "level_5", title: "Apprentice", subtitle: "Reach level 5", icon: "star", category: .level),
        Achievement(id: "level_10", title: "Rising Star", subtitle: "Reach level 10", icon: "star.fill", category: .level, xpReward: 75),
        Achievement(id: "level_25", title: "Veteran", subtitle: "Reach level 25", icon: "star.circle", category: .level, xpReward: 150),
        Achievement(id: "level_50", title: "Master", subtitle: "Reach level 50", icon: "star.circle.fill", category: .level, xpReward: 300),
        Achievement(id: "quest_10", title: "Adventurer", subtitle: "Complete 10 quests", icon: "scroll", category: .level),
        Achievement(id: "quest_50", title: "Hero", subtitle: "Complete 50 quests", icon: "scroll.fill", category: .level, xpReward: 150),
    ] }
}
