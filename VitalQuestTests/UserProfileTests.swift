import Testing
import Foundation
import SwiftData
@testable import VitalQuest

@Suite("User Profile Tests")
@MainActor
struct UserProfileTests {
    let modelContainer: ModelContainer

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: DailySnapshot.self, MetricBaseline.self, Quest.self,
            Achievement.self, UserProfile.self, JournalEntry.self, CustomLog.self, FeedItem.self, Activity.self,
            configurations: config
        )
    }

    // MARK: - XP & Level

    @Test("New profile starts at level 1 with 0 XP")
    func initialState() {
        let profile = UserProfile()
        #expect(profile.level == 1)
        #expect(profile.totalXP == 0)
        #expect(profile.currentStreak == 0)
        #expect(profile.streakFreezes == 1) // Starts with one free
    }

    @Test("addXP increases total")
    func addXPBasic() {
        let profile = UserProfile()
        modelContainer.mainContext.insert(profile)
        let _ = profile.addXP(50)
        #expect(profile.totalXP == 50)
    }

    @Test("addXP returns 0 for non-positive amounts")
    func addXPZero() {
        let profile = UserProfile()
        modelContainer.mainContext.insert(profile)
        let levelUps = profile.addXP(0)
        #expect(levelUps == 0)
        #expect(profile.totalXP == 0)
    }

    @Test("Level up at correct XP threshold")
    func levelUpThreshold() {
        let profile = UserProfile()
        modelContainer.mainContext.insert(profile)
        // Level 1→2 requires cumulativeXP(forLevel: 2) = xpRequired(forLevel: 1) = 100
        let levelUps = profile.addXP(100)
        #expect(levelUps == 1)
        #expect(profile.level == 2)
    }

    @Test("Multiple level ups in single addXP")
    func multipleLevelUps() {
        let profile = UserProfile()
        modelContainer.mainContext.insert(profile)
        // Give enough XP to jump several levels
        let levelUps = profile.addXP(5000)
        #expect(levelUps > 1)
        #expect(profile.level > 2)
    }

    @Test("Level capped at 99")
    func levelCap() {
        let profile = UserProfile()
        modelContainer.mainContext.insert(profile)
        let _ = profile.addXP(999_999_999)
        #expect(profile.level <= 99)
    }

    @Test("XP required scales with level")
    func xpRequiredScaling() {
        let xp1 = UserProfile.xpRequired(forLevel: 1)
        let xp5 = UserProfile.xpRequired(forLevel: 5)
        let xp10 = UserProfile.xpRequired(forLevel: 10)
        #expect(xp1 == 100)
        #expect(xp5 > xp1)
        #expect(xp10 > xp5)
    }

    @Test("Cumulative XP is sum of prior levels")
    func cumulativeXP() {
        let cum3 = UserProfile.cumulativeXP(forLevel: 3)
        let expected = UserProfile.xpRequired(forLevel: 1) + UserProfile.xpRequired(forLevel: 2)
        #expect(cum3 == expected)
    }

    @Test("Level progress is between 0 and 1")
    func levelProgress() {
        let profile = UserProfile()
        modelContainer.mainContext.insert(profile)
        profile.totalXP = 50 // Halfway through level 1 (needs 100)
        let progress = profile.levelProgress
        #expect(progress >= 0 && progress <= 1)
        #expect(abs(progress - 0.5) < 0.01)
    }

    @Test("XP to next level decreases as XP increases")
    func xpToNextLevel() {
        let profile = UserProfile()
        modelContainer.mainContext.insert(profile)
        let initial = profile.xpToNextLevel
        profile.totalXP = 50
        let after = profile.xpToNextLevel
        #expect(after < initial)
    }

    // MARK: - Titles

    @Test("Title progression through levels")
    func titleProgression() {
        let profile = UserProfile()
        modelContainer.mainContext.insert(profile)

        profile.level = 1
        #expect(profile.title == "Novice")

        profile.level = 6
        #expect(profile.title == "Apprentice")

        profile.level = 11
        #expect(profile.title == "Journeyman")

        profile.level = 21
        #expect(profile.title == "Adept")

        profile.level = 31
        #expect(profile.title == "Expert")

        profile.level = 41
        #expect(profile.title == "Master")

        profile.level = 51
        #expect(profile.title == "Grandmaster")

        profile.level = 61
        #expect(profile.title == "Legend")

        profile.level = 76
        #expect(profile.title == "Mythic")
    }

    // MARK: - Default Goals

    @Test("Default goals are reasonable")
    func defaultGoals() {
        let profile = UserProfile()
        #expect(profile.stepGoal == 10000)
        #expect(profile.calorieGoal == 500)
        #expect(profile.sleepGoalHours == 8.0)
        #expect(profile.exerciseGoalMinutes == 30)
    }
}

@Suite("Feed Service Tests")
@MainActor
struct FeedServiceTests {
    let modelContainer: ModelContainer
    let feedService: FeedService

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: DailySnapshot.self, MetricBaseline.self, Quest.self,
            Achievement.self, UserProfile.self, JournalEntry.self, CustomLog.self, FeedItem.self, Activity.self,
            configurations: config
        )
        feedService = FeedService(modelContext: modelContainer.mainContext)
        Activity.seedDefaults(context: modelContainer.mainContext)
    }

    @Test("Record workout creates private feed item")
    func recordWorkout() {
        feedService.recordWorkout(type: "Running", durationMinutes: 30, calories: 250, distanceMeters: 5000)
        let descriptor = FetchDescriptor<FeedItem>()
        let items = (try? modelContainer.mainContext.fetch(descriptor)) ?? []
        #expect(items.count == 1)
        #expect(items[0].type == .workout)
        #expect(items[0].visibility == .private)
        #expect(items[0].title == "Running")
        #expect(items[0].detail?.contains("30 min") == true)
    }

    @Test("Record achievement creates private feed item")
    func recordAchievement() {
        let achievement = Achievement(id: "test", title: "Test Badge", subtitle: "Test subtitle", icon: "star.fill", category: .activity)
        achievement.xpReward = 100
        modelContainer.mainContext.insert(achievement)
        feedService.recordAchievementUnlocked(achievement: achievement)

        let descriptor = FetchDescriptor<FeedItem>()
        let items = (try? modelContainer.mainContext.fetch(descriptor)) ?? []
        #expect(items.count == 1)
        #expect(items[0].type == .achievement)
        #expect(items[0].visibility == .private)
        #expect(items[0].metricValue == 100)
        #expect(items[0].metricUnit == "XP")
    }

    @Test("Record quest complete creates private feed item")
    func recordQuestComplete() {
        let quest = Quest(
            title: "Walk 8000 steps", flavorText: "Go go go",
            type: .daily, metric: "steps", targetValue: 8000,
            xpReward: 30, assignedDate: Date(), deadline: Date().addingTimeInterval(86400)
        )
        modelContainer.mainContext.insert(quest)
        feedService.recordQuestCompleted(quest: quest)

        let descriptor = FetchDescriptor<FeedItem>()
        let items = (try? modelContainer.mainContext.fetch(descriptor)) ?? []
        #expect(items.count == 1)
        #expect(items[0].type == .questComplete)
        #expect(items[0].visibility == .private)
    }

    @Test("Record level up creates private feed item")
    func recordLevelUp() {
        feedService.recordLevelUp(newLevel: 10, title: "Apprentice")
        let descriptor = FetchDescriptor<FeedItem>()
        let items = (try? modelContainer.mainContext.fetch(descriptor)) ?? []
        #expect(items.count == 1)
        #expect(items[0].type == .milestone)
        #expect(items[0].visibility == .private)
        #expect(items[0].title == "Level 10")
    }

    @Test("Record streak milestone creates private feed item")
    func recordStreakMilestone() {
        feedService.recordStreakMilestone(days: 30)
        let descriptor = FetchDescriptor<FeedItem>()
        let items = (try? modelContainer.mainContext.fetch(descriptor)) ?? []
        #expect(items.count == 1)
        #expect(items[0].type == .streakUpdate)
        #expect(items[0].visibility == .private)
        #expect(items[0].metricValue == 30)
    }

    @Test("Record personal best creates private feed item")
    func recordPersonalBest() {
        feedService.recordPersonalBest(metric: "steps", value: 15000, unit: "steps")
        let descriptor = FetchDescriptor<FeedItem>()
        let items = (try? modelContainer.mainContext.fetch(descriptor)) ?? []
        #expect(items.count == 1)
        #expect(items[0].type == .personalBest)
        #expect(items[0].visibility == .private)
    }

    @Test("Record daily summary skips insufficient data")
    func recordDailySummaryInsufficientData() {
        let snapshot = DailySnapshot(date: Date())
        // No scores set — hasSufficientData should be false
        modelContainer.mainContext.insert(snapshot)
        feedService.recordDailySummary(snapshot: snapshot)

        let descriptor = FetchDescriptor<FeedItem>()
        let items = (try? modelContainer.mainContext.fetch(descriptor)) ?? []
        #expect(items.isEmpty)
    }

    @Test("Record daily summary creates item with scores")
    func recordDailySummaryWithData() {
        let snapshot = DailySnapshot(date: Date())
        snapshot.steps = 10000
        snapshot.activeCalories = 500
        snapshot.exerciseMinutes = 30
        snapshot.sleepDurationMinutes = 480
        snapshot.recoveryScore = 75
        snapshot.sleepScore = 80
        snapshot.activityScore = 70
        snapshot.dataCompleteness = 0.9
        modelContainer.mainContext.insert(snapshot)
        feedService.recordDailySummary(snapshot: snapshot)

        let descriptor = FetchDescriptor<FeedItem>()
        let items = (try? modelContainer.mainContext.fetch(descriptor)) ?? []
        #expect(items.count == 1)
        #expect(items[0].type == .dailySummary)
        #expect(items[0].visibility == .private)
        #expect(items[0].detail?.contains("Recovery") == true)
    }

    @Test("Multiple feed items accumulate correctly")
    func multipleFeedItems() {
        feedService.recordWorkout(type: "Running", durationMinutes: 30, calories: 250, distanceMeters: nil)
        feedService.recordWorkout(type: "Yoga", durationMinutes: 45, calories: nil, distanceMeters: nil)
        feedService.recordStreakMilestone(days: 7)

        let descriptor = FetchDescriptor<FeedItem>()
        let items = (try? modelContainer.mainContext.fetch(descriptor)) ?? []
        #expect(items.count == 3)
    }
}
