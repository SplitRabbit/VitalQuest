import Testing
import Foundation
import SwiftData
@testable import VitalQuest

@Suite("XP Engine Tests")
@MainActor
struct XPEngineTests {
    let modelContainer: ModelContainer
    let engine: XPEngine

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: DailySnapshot.self, MetricBaseline.self, Quest.self,
            Achievement.self, UserProfile.self, JournalEntry.self, CustomLog.self, FeedItem.self, Activity.self,
            configurations: config
        )
        engine = XPEngine(modelContext: modelContainer.mainContext)
    }

    // MARK: - XP Awards

    @Test("Award XP adds to profile")
    func awardXPBasic() {
        let profile = UserProfile()
        modelContainer.mainContext.insert(profile)
        let (xp, _) = engine.awardXP(.dailyCheckIn, profile: profile)
        #expect(xp == 10)
        #expect(profile.totalXP == 10)
    }

    @Test("Award XP with multiplier scales correctly")
    func awardXPMultiplier() {
        let profile = UserProfile()
        modelContainer.mainContext.insert(profile)
        let (xp, _) = engine.awardXP(.workoutDetected, profile: profile, multiplier: 2.0)
        #expect(xp == 50) // 25 * 2
        #expect(profile.totalXP == 50)
    }

    @Test("Award XP triggers level up")
    func awardXPLevelUp() {
        let profile = UserProfile()
        modelContainer.mainContext.insert(profile)
        // Level 1 → 2 requires xpRequired(forLevel: 1) = 100 * 1^1.5 = 100
        profile.totalXP = 95
        let (_, levelUps) = engine.awardXP(.dailyCheckIn, profile: profile) // +10 → 105
        #expect(levelUps == 1)
        #expect(profile.level == 2)
    }

    @Test("Workout XP scales by duration")
    func workoutXPDuration() {
        let profile = UserProfile()
        modelContainer.mainContext.insert(profile)

        let (shortXP, _) = engine.awardWorkoutXP(durationMinutes: 10, profile: profile)
        #expect(shortXP == 15)

        let profile2 = UserProfile()
        modelContainer.mainContext.insert(profile2)
        let (longXP, _) = engine.awardWorkoutXP(durationMinutes: 75, profile: profile2)
        #expect(longXP == 50)
    }

    @Test("Workout XP tiers: <15, 15-30, 30-60, 60+")
    func workoutXPTiers() {
        let amounts = [10.0, 20.0, 45.0, 90.0]
        let expected = [15, 25, 35, 50]

        for (duration, expectedXP) in zip(amounts, expected) {
            let p = UserProfile()
            modelContainer.mainContext.insert(p)
            let (xp, _) = engine.awardWorkoutXP(durationMinutes: duration, profile: p)
            #expect(xp == expectedXP)
        }
    }

    // MARK: - Daily Evaluation

    @Test("Daily evaluation awards check-in XP")
    func dailyCheckIn() {
        let profile = UserProfile()
        modelContainer.mainContext.insert(profile)
        let snapshot = DailySnapshot(date: Date())
        modelContainer.mainContext.insert(snapshot)

        let totalXP = engine.evaluateDaily(snapshot: snapshot, profile: profile)
        #expect(totalXP >= 10) // At minimum, check-in XP
        #expect(snapshot.checkedIn == true)
    }

    @Test("Daily evaluation doesn't double-award check-in")
    func dailyCheckInNoDuplicate() {
        let profile = UserProfile()
        modelContainer.mainContext.insert(profile)
        let snapshot = DailySnapshot(date: Date())
        snapshot.checkedIn = true // Already checked in
        modelContainer.mainContext.insert(snapshot)

        let totalXP = engine.evaluateDaily(snapshot: snapshot, profile: profile)
        // No check-in XP since already checked in
        #expect(totalXP == 0 || snapshot.steps >= profile.stepGoal || snapshot.workoutCount > 0)
    }

    @Test("Daily evaluation awards sleep score bonus")
    func dailySleepBonus() {
        let profile = UserProfile()
        modelContainer.mainContext.insert(profile)
        let snapshot = DailySnapshot(date: Date())
        snapshot.sleepScore = 85
        modelContainer.mainContext.insert(snapshot)

        let totalXP = engine.evaluateDaily(snapshot: snapshot, profile: profile)
        #expect(totalXP >= 25) // check-in (10) + sleep bonus (15)
    }

    @Test("Daily evaluation awards step goal bonus")
    func dailyStepGoal() {
        let profile = UserProfile()
        profile.stepGoal = 10000
        modelContainer.mainContext.insert(profile)
        let snapshot = DailySnapshot(date: Date())
        snapshot.steps = 12000
        modelContainer.mainContext.insert(snapshot)

        let totalXP = engine.evaluateDaily(snapshot: snapshot, profile: profile)
        #expect(totalXP >= 30) // check-in (10) + steps (20)
    }

    @Test("Daily evaluation awards workout XP")
    func dailyWorkout() {
        let profile = UserProfile()
        modelContainer.mainContext.insert(profile)
        let snapshot = DailySnapshot(date: Date())
        snapshot.workoutCount = 1
        modelContainer.mainContext.insert(snapshot)

        let totalXP = engine.evaluateDaily(snapshot: snapshot, profile: profile)
        #expect(totalXP >= 35) // check-in (10) + workout (25)
    }

    @Test("Daily evaluation cumulates all bonuses")
    func dailyAllBonuses() {
        let profile = UserProfile()
        profile.stepGoal = 10000
        modelContainer.mainContext.insert(profile)
        let snapshot = DailySnapshot(date: Date())
        snapshot.steps = 15000
        snapshot.sleepScore = 90
        snapshot.recoveryScore = 85
        snapshot.workoutCount = 1
        modelContainer.mainContext.insert(snapshot)

        let totalXP = engine.evaluateDaily(snapshot: snapshot, profile: profile)
        // check-in(10) + sleep(15) + recovery(15) + steps(20) + workout(25) = 85
        #expect(totalXP == 85)
    }

    // MARK: - Achievements

    @Test("Seed achievements creates entries")
    func seedAchievements() {
        engine.seedAchievementsIfNeeded()
        let descriptor = FetchDescriptor<Achievement>()
        let count = try? modelContainer.mainContext.fetchCount(descriptor)
        #expect(count == Achievement.seeds.count)
    }

    @Test("Seed achievements is idempotent")
    func seedAchievementsIdempotent() {
        engine.seedAchievementsIfNeeded()
        engine.seedAchievementsIfNeeded()
        let descriptor = FetchDescriptor<Achievement>()
        let count = try? modelContainer.mainContext.fetchCount(descriptor)
        #expect(count == Achievement.seeds.count)
    }

    @Test("Achievement unlocked for streak milestone")
    func achievementStreakUnlock() {
        engine.seedAchievementsIfNeeded()
        let profile = UserProfile()
        profile.currentStreak = 7
        modelContainer.mainContext.insert(profile)
        let snapshot = DailySnapshot(date: Date())
        modelContainer.mainContext.insert(snapshot)

        let unlocked = engine.checkAchievements(snapshot: snapshot, profile: profile)
        #expect(unlocked.contains("streak_3"))
        #expect(unlocked.contains("streak_7"))
    }

    @Test("Achievement unlocked for high score")
    func achievementScoreUnlock() {
        engine.seedAchievementsIfNeeded()
        let profile = UserProfile()
        modelContainer.mainContext.insert(profile)
        let snapshot = DailySnapshot(date: Date())
        snapshot.recoveryScore = 92
        snapshot.sleepScore = 91
        snapshot.activityScore = 95
        modelContainer.mainContext.insert(snapshot)

        let unlocked = engine.checkAchievements(snapshot: snapshot, profile: profile)
        #expect(unlocked.contains("recovery_90"))
        #expect(unlocked.contains("sleep_90"))
        #expect(unlocked.contains("activity_90"))
        #expect(unlocked.contains("all_scores_80"))
        #expect(unlocked.contains("perfect_day"))
    }

    @Test("Already unlocked achievements are not re-unlocked")
    func achievementNoReUnlock() {
        engine.seedAchievementsIfNeeded()
        let profile = UserProfile()
        profile.currentStreak = 7
        modelContainer.mainContext.insert(profile)
        let snapshot = DailySnapshot(date: Date())
        modelContainer.mainContext.insert(snapshot)

        let first = engine.checkAchievements(snapshot: snapshot, profile: profile)
        #expect(!first.isEmpty)

        let second = engine.checkAchievements(snapshot: snapshot, profile: profile)
        // All previously unlocked, so nothing new
        #expect(second.isEmpty)
    }
}
