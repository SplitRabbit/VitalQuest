import Foundation
import SwiftData

/// Generates FeedItem entries from app events (workouts, achievements, quests, milestones).
/// All items default to private. Users can share individual items with friends.
@Observable
final class FeedService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Event Generators

    func recordWorkout(type: String, durationMinutes: Double, calories: Double?, distanceMeters: Double?) {
        var detail = "\(Int(durationMinutes)) min"
        if let cal = calories, cal > 0 {
            detail += " \u{2022} \(Int(cal)) cal"
        }
        if let dist = distanceMeters, dist > 0 {
            let km = dist / 1000
            detail += " \u{2022} \(String(format: "%.1f", km)) km"
        }

        let info = Activity.lookup(name: type, in: modelContext)

        let item = FeedItem(
            type: .workout,
            title: type,
            detail: detail,
            icon: info.icon,
            accentColorName: info.colorName,
            visibility: .private,
            metricValue: durationMinutes,
            metricUnit: "min"
        )
        modelContext.insert(item)
    }

    func recordAchievementUnlocked(achievement: Achievement) {
        let item = FeedItem(
            type: .achievement,
            title: achievement.title,
            detail: achievement.subtitle,
            icon: achievement.icon,
            accentColorName: "yellow",
            visibility: .private,
            metricValue: Double(achievement.xpReward),
            metricUnit: "XP",
            relatedAchievementID: achievement.id
        )
        modelContext.insert(item)
    }

    func recordQuestCompleted(quest: Quest) {
        let item = FeedItem(
            type: .questComplete,
            title: "Quest Complete",
            detail: quest.title,
            icon: "scroll.fill",
            accentColorName: "cyan",
            visibility: .private,
            metricValue: Double(quest.xpReward),
            metricUnit: "XP",
            relatedQuestID: quest.id.uuidString
        )
        modelContext.insert(item)
    }

    func recordLevelUp(newLevel: Int, title: String) {
        let item = FeedItem(
            type: .milestone,
            title: "Level \(newLevel)",
            detail: "Reached \(title) rank",
            icon: "arrow.up.circle.fill",
            accentColorName: "green",
            visibility: .private
        )
        modelContext.insert(item)
    }

    func recordStreakMilestone(days: Int) {
        let item = FeedItem(
            type: .streakUpdate,
            title: "\(days)-Day Streak",
            detail: "Consistency pays off",
            icon: "flame.fill",
            accentColorName: "orange",
            visibility: .private,
            metricValue: Double(days),
            metricUnit: "days"
        )
        modelContext.insert(item)
    }

    func recordPersonalBest(metric: String, value: Double, unit: String) {
        let item = FeedItem(
            type: .personalBest,
            title: "Personal Best",
            detail: metricDisplayName(metric),
            icon: "trophy.fill",
            accentColorName: "yellow",
            visibility: .private,
            metricValue: value,
            metricUnit: unit
        )
        modelContext.insert(item)
    }

    func recordDailySummary(snapshot: DailySnapshot) {
        guard snapshot.hasSufficientData else { return }

        let scores = [
            ("Recovery", snapshot.recoveryScore),
            ("Sleep", snapshot.sleepScore),
            ("Activity", snapshot.activityScore)
        ].compactMap { name, score -> String? in
            guard let s = score else { return nil }
            return "\(name) \(Int(s))"
        }

        guard !scores.isEmpty else { return }

        let item = FeedItem(
            type: .dailySummary,
            title: "Daily Summary",
            detail: scores.joined(separator: " \u{2022} "),
            icon: "chart.bar.fill",
            accentColorName: "green",
            visibility: .private,
            metricValue: snapshot.primaryScore,
            metricUnit: "score"
        )
        modelContext.insert(item)
    }

    // MARK: - Helpers

    private func metricDisplayName(_ metric: String) -> String {
        switch metric {
        case "steps": "Steps"
        case "activeCalories": "Active Calories"
        case "exerciseMinutes": "Exercise Minutes"
        case "hrvSDNN": "HRV"
        case "sleepDurationMinutes": "Sleep Duration"
        case "distanceWalkingRunning": "Distance"
        default: metric
        }
    }
}
