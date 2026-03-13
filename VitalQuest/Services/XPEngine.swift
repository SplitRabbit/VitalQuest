import Foundation
import SwiftData
import Observation

/// Manages XP awards, level progression, and achievement checks.
@Observable
final class XPEngine {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - XP Awards

    enum XPSource: String {
        case dailyCheckIn = "Daily Check-in"
        case workoutDetected = "Workout"
        case stepGoalHit = "Step Goal"
        case sleepScoreHigh = "Sleep Score 80+"
        case recoveryScoreHigh = "Recovery Score 80+"
        case dailyQuestComplete = "Daily Quest"
        case weeklyQuestComplete = "Weekly Quest"
        case epicQuestComplete = "Epic Quest"
        case streakBonus7 = "7-Day Streak"
        case streakBonus30 = "30-Day Streak"
        case personalBest = "Personal Best"

        var xpAmount: Int {
            switch self {
            case .dailyCheckIn: return 10
            case .workoutDetected: return 25
            case .stepGoalHit: return 20
            case .sleepScoreHigh: return 15
            case .recoveryScoreHigh: return 15
            case .dailyQuestComplete: return 30
            case .weeklyQuestComplete: return 100
            case .epicQuestComplete: return 500
            case .streakBonus7: return 50
            case .streakBonus30: return 200
            case .personalBest: return 40
            }
        }
    }

    /// Award XP to the user profile. Returns (xpAwarded, levelUps).
    @discardableResult
    func awardXP(_ source: XPSource, profile: UserProfile, multiplier: Double = 1.0) -> (xp: Int, levelUps: Int) {
        let amount = Int(Double(source.xpAmount) * multiplier)
        let levelUps = profile.addXP(amount)
        return (amount, levelUps)
    }

    /// Award XP for a workout, scaling by duration.
    @discardableResult
    func awardWorkoutXP(durationMinutes: Double, profile: UserProfile) -> (xp: Int, levelUps: Int) {
        let baseXP: Int
        switch durationMinutes {
        case ..<15: baseXP = 15
        case 15..<30: baseXP = 25
        case 30..<60: baseXP = 35
        default: baseXP = 50
        }
        let levelUps = profile.addXP(baseXP)
        return (baseXP, levelUps)
    }

    // MARK: - Daily XP Evaluation

    /// Evaluate all XP sources for today's snapshot. Returns total XP awarded.
    func evaluateDaily(snapshot: DailySnapshot, profile: UserProfile) -> Int {
        var totalXP = 0

        // Daily check-in
        if !snapshot.checkedIn {
            snapshot.checkedIn = true
            let (xp, _) = awardXP(.dailyCheckIn, profile: profile)
            totalXP += xp
        }

        // Score milestones
        if let sleep = snapshot.sleepScore, sleep >= 80 {
            let (xp, _) = awardXP(.sleepScoreHigh, profile: profile)
            totalXP += xp
        }
        if let recovery = snapshot.recoveryScore, recovery >= 80 {
            let (xp, _) = awardXP(.recoveryScoreHigh, profile: profile)
            totalXP += xp
        }

        // Step goal
        if snapshot.steps >= profile.stepGoal {
            let (xp, _) = awardXP(.stepGoalHit, profile: profile)
            totalXP += xp
        }

        // Workout XP (by count, simplified)
        if snapshot.workoutCount > 0 {
            let (xp, _) = awardXP(.workoutDetected, profile: profile)
            totalXP += xp
        }

        snapshot.xpEarned = totalXP
        return totalXP
    }

    // MARK: - Achievement Checks

    /// Check and unlock achievements. Returns newly unlocked achievement IDs.
    func checkAchievements(snapshot: DailySnapshot, profile: UserProfile) -> [String] {
        var unlocked: [String] = []

        let descriptor = FetchDescriptor<Achievement>(
            predicate: #Predicate { !$0.isUnlocked }
        )
        guard let locked = try? modelContext.fetch(descriptor) else { return [] }

        for achievement in locked {
            if shouldUnlock(achievement: achievement, snapshot: snapshot, profile: profile) {
                achievement.unlock()
                profile.addXP(achievement.xpReward)
                unlocked.append(achievement.id)
            }
        }

        return unlocked
    }

    private func shouldUnlock(achievement: Achievement, snapshot: DailySnapshot, profile: UserProfile) -> Bool {
        switch achievement.id {
        // Streaks
        case "streak_3": return profile.currentStreak >= 3
        case "streak_7": return profile.currentStreak >= 7
        case "streak_14": return profile.currentStreak >= 14
        case "streak_30": return profile.currentStreak >= 30
        case "streak_60": return profile.currentStreak >= 60
        case "streak_100": return profile.currentStreak >= 100

        // Scores
        case "recovery_90": return (snapshot.recoveryScore ?? 0) >= 90
        case "sleep_90": return (snapshot.sleepScore ?? 0) >= 90
        case "activity_90": return (snapshot.activityScore ?? 0) >= 90
        case "all_scores_80":
            return (snapshot.recoveryScore ?? 0) >= 80 &&
                   (snapshot.sleepScore ?? 0) >= 80 &&
                   (snapshot.activityScore ?? 0) >= 80
        case "perfect_day":
            return (snapshot.recoveryScore ?? 0) >= 90 &&
                   (snapshot.sleepScore ?? 0) >= 90 &&
                   (snapshot.activityScore ?? 0) >= 90

        // Activity
        case "steps_10k": return snapshot.steps >= 10000
        case "steps_20k": return snapshot.steps >= 20000
        case "calories_1000": return snapshot.activeCalories >= 1000
        case "exercise_60": return snapshot.exerciseMinutes >= 60

        // Data
        case "baseline_ready": return profile.totalDaysTracked >= 14
        case "first_week_data": return profile.totalDaysTracked >= 7
        case "month_data": return profile.totalDaysTracked >= 30

        // Level
        case "level_5": return profile.level >= 5
        case "level_10": return profile.level >= 10
        case "level_25": return profile.level >= 25
        case "level_50": return profile.level >= 50
        case "quest_10": return profile.totalQuestsCompleted >= 10
        case "quest_50": return profile.totalQuestsCompleted >= 50

        default: return false
        }
    }

    // MARK: - Seed Achievements

    /// Seed achievements on first launch if none exist.
    func seedAchievementsIfNeeded() {
        let descriptor = FetchDescriptor<Achievement>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        for achievement in Achievement.seeds {
            modelContext.insert(achievement)
        }
    }
}
