import Testing
import Foundation
import SwiftData
@testable import VitalQuest

@Suite("Streak Manager Tests")
@MainActor
struct StreakManagerTests {
    let modelContainer: ModelContainer
    let manager: StreakManager

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: DailySnapshot.self, MetricBaseline.self, Quest.self,
            Achievement.self, UserProfile.self, JournalEntry.self, CustomLog.self, FeedItem.self, Activity.self,
            configurations: config
        )
        manager = StreakManager(modelContext: modelContainer.mainContext)
    }

    // MARK: - Check-In

    @Test("First check-in starts streak at 1")
    func firstCheckIn() {
        let profile = UserProfile()
        modelContainer.mainContext.insert(profile)
        manager.processCheckIn(profile: profile)
        #expect(profile.currentStreak == 1)
        #expect(profile.totalDaysTracked == 1)
        #expect(profile.lastActiveDate != nil)
    }

    @Test("Same-day check-in is no-op")
    func sameDayCheckIn() {
        let profile = UserProfile()
        profile.lastActiveDate = Calendar.current.startOfDay(for: Date())
        profile.currentStreak = 5
        profile.totalDaysTracked = 10
        modelContainer.mainContext.insert(profile)

        manager.processCheckIn(profile: profile)
        #expect(profile.currentStreak == 5)
        #expect(profile.totalDaysTracked == 10)
    }

    @Test("Consecutive day extends streak")
    func consecutiveDay() {
        let profile = UserProfile()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!
        profile.lastActiveDate = yesterday
        profile.currentStreak = 5
        profile.totalDaysTracked = 10
        modelContainer.mainContext.insert(profile)

        manager.processCheckIn(profile: profile)
        #expect(profile.currentStreak == 6)
        #expect(profile.totalDaysTracked == 11)
    }

    @Test("Missed one day uses freeze if available")
    func missedOneDayWithFreeze() {
        let profile = UserProfile()
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Calendar.current.startOfDay(for: Date()))!
        profile.lastActiveDate = twoDaysAgo
        profile.currentStreak = 10
        profile.streakFreezes = 2
        profile.totalDaysTracked = 15
        modelContainer.mainContext.insert(profile)

        manager.processCheckIn(profile: profile)
        #expect(profile.currentStreak == 11) // Preserved + today
        #expect(profile.streakFreezes == 1)
        #expect(profile.totalStreakFreezesUsed == 1)
    }

    @Test("Missed one day without freeze breaks streak")
    func missedOneDayNoFreeze() {
        let profile = UserProfile()
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Calendar.current.startOfDay(for: Date()))!
        profile.lastActiveDate = twoDaysAgo
        profile.currentStreak = 10
        profile.streakFreezes = 0
        modelContainer.mainContext.insert(profile)

        manager.processCheckIn(profile: profile)
        #expect(profile.currentStreak == 1)
    }

    @Test("Missed 2+ days always breaks streak")
    func missedMultipleDays() {
        let profile = UserProfile()
        let fourDaysAgo = Calendar.current.date(byAdding: .day, value: -4, to: Calendar.current.startOfDay(for: Date()))!
        profile.lastActiveDate = fourDaysAgo
        profile.currentStreak = 20
        profile.streakFreezes = 3
        modelContainer.mainContext.insert(profile)

        manager.processCheckIn(profile: profile)
        #expect(profile.currentStreak == 1) // Reset regardless of freezes
        #expect(profile.streakFreezes == 3) // Freezes not consumed
    }

    @Test("Longest streak updates when current exceeds it")
    func longestStreakUpdates() {
        let profile = UserProfile()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!
        profile.lastActiveDate = yesterday
        profile.currentStreak = 15
        profile.longestStreak = 15
        modelContainer.mainContext.insert(profile)

        manager.processCheckIn(profile: profile)
        #expect(profile.longestStreak == 16)
    }

    @Test("7-day milestone awards streak freeze")
    func milestoneAwardsFreeze() {
        let profile = UserProfile()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!
        profile.lastActiveDate = yesterday
        profile.currentStreak = 6 // Will become 7
        profile.streakFreezes = 1
        modelContainer.mainContext.insert(profile)

        manager.processCheckIn(profile: profile)
        #expect(profile.currentStreak == 7)
        #expect(profile.streakFreezes == 2) // Got +1
    }

    @Test("Streak freeze capped at 3")
    func freezeCapped() {
        let profile = UserProfile()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!
        profile.lastActiveDate = yesterday
        profile.currentStreak = 13 // Will become 14
        profile.streakFreezes = 3
        modelContainer.mainContext.insert(profile)

        manager.processCheckIn(profile: profile)
        #expect(profile.currentStreak == 14)
        #expect(profile.streakFreezes == 3) // Still 3, capped
    }

    // MARK: - Streak At Risk

    @Test("Streak at risk when not checked in today")
    func streakAtRisk() {
        let profile = UserProfile()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!
        profile.lastActiveDate = yesterday
        profile.currentStreak = 5
        modelContainer.mainContext.insert(profile)

        #expect(manager.streakAtRisk(profile: profile))
    }

    @Test("Streak not at risk when checked in today")
    func streakNotAtRisk() {
        let profile = UserProfile()
        profile.lastActiveDate = Calendar.current.startOfDay(for: Date())
        profile.currentStreak = 5
        modelContainer.mainContext.insert(profile)

        #expect(!manager.streakAtRisk(profile: profile))
    }

    @Test("Streak not at risk with zero streak")
    func streakNotAtRiskZero() {
        let profile = UserProfile()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!
        profile.lastActiveDate = yesterday
        profile.currentStreak = 0
        modelContainer.mainContext.insert(profile)

        #expect(!manager.streakAtRisk(profile: profile))
    }

    // MARK: - Purchase Freeze

    @Test("Purchase freeze deducts XP")
    func purchaseFreeze() {
        let profile = UserProfile()
        profile.totalXP = 1000
        profile.streakFreezes = 1
        modelContainer.mainContext.insert(profile)

        let result = manager.purchaseStreakFreeze(profile: profile)
        #expect(result == true)
        #expect(profile.totalXP == 500)
        #expect(profile.streakFreezes == 2)
    }

    @Test("Purchase freeze fails with insufficient XP")
    func purchaseFreezeInsufficientXP() {
        let profile = UserProfile()
        profile.totalXP = 200
        profile.streakFreezes = 1
        modelContainer.mainContext.insert(profile)

        let result = manager.purchaseStreakFreeze(profile: profile)
        #expect(result == false)
        #expect(profile.totalXP == 200)
    }

    @Test("Purchase freeze fails when at max capacity")
    func purchaseFreezeAtMax() {
        let profile = UserProfile()
        profile.totalXP = 1000
        profile.streakFreezes = 3
        modelContainer.mainContext.insert(profile)

        let result = manager.purchaseStreakFreeze(profile: profile)
        #expect(result == false)
        #expect(profile.streakFreezes == 3)
    }
}
