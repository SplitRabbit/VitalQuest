import Foundation
import SwiftData
import Observation

/// Tracks daily streaks with freeze mechanics.
@Observable
final class StreakManager {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Process a check-in for today. Call when user opens app and has health data.
    func processCheckIn(profile: UserProfile) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let lastActive = profile.lastActiveDate else {
            // First ever check-in
            profile.currentStreak = 1
            profile.lastActiveDate = today
            profile.totalDaysTracked += 1
            return
        }

        let lastActiveDay = calendar.startOfDay(for: lastActive)

        if calendar.isDate(lastActiveDay, inSameDayAs: today) {
            // Already checked in today
            return
        }

        let daysSinceActive = calendar.dateComponents([.day], from: lastActiveDay, to: today).day ?? 0

        switch daysSinceActive {
        case 1:
            // Consecutive day — extend streak
            profile.currentStreak += 1
        case 2:
            // Missed one day — try to use freeze
            if profile.streakFreezes > 0 {
                profile.streakFreezes -= 1
                profile.totalStreakFreezesUsed += 1
                profile.currentStreak += 1 // Freeze preserved the streak, now +1 for today
            } else {
                // Streak broken
                profile.currentStreak = 1
            }
        default:
            // Missed 2+ days — streak broken
            profile.currentStreak = 1
        }

        profile.lastActiveDate = today
        profile.longestStreak = max(profile.longestStreak, profile.currentStreak)
        profile.totalDaysTracked += 1

        // Award streak freeze at 7-day milestones
        if profile.currentStreak > 0 && profile.currentStreak.isMultiple(of: 7) {
            profile.streakFreezes = min(profile.streakFreezes + 1, 3) // Max 3
        }
    }

    /// Check if streak is at risk (no check-in today and it's getting late).
    func streakAtRisk(profile: UserProfile) -> Bool {
        guard let lastActive = profile.lastActiveDate else { return false }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastDay = calendar.startOfDay(for: lastActive)
        return !calendar.isDate(lastDay, inSameDayAs: today) && profile.currentStreak > 0
    }

    /// Buy a streak freeze with XP (500 XP cost).
    func purchaseStreakFreeze(profile: UserProfile) -> Bool {
        guard profile.streakFreezes < 3, profile.totalXP >= 500 else { return false }
        profile.totalXP -= 500
        profile.streakFreezes += 1
        return true
    }
}
