import Foundation
import SwiftData
import Observation

@Observable
final class DashboardViewModel {
    var todaySnapshot: DailySnapshot?
    var recentSnapshots: [DailySnapshot] = [] // Last 7 days for charts
    var activeQuests: [Quest] = []
    var profile: UserProfile?
    var isLoading = false
    var error: String?
    var recentUnlocks: [String] = [] // Achievement IDs just unlocked
    var xpGainedThisSession = 0

    private var modelContext: ModelContext?
    private var healthKitManager: HealthKitDataProvider?
    private var scoringEngine: ScoringEngine?
    private var baselineEngine: BaselineEngine?
    private var xpEngine: XPEngine?
    private var streakManager: StreakManager?
    private var questEngine: QuestEngine?

    func configure(
        modelContext: ModelContext,
        healthKitManager: HealthKitDataProvider,
        scoringEngine: ScoringEngine,
        baselineEngine: BaselineEngine,
        xpEngine: XPEngine,
        streakManager: StreakManager,
        questEngine: QuestEngine
    ) {
        self.modelContext = modelContext
        self.healthKitManager = healthKitManager
        self.scoringEngine = scoringEngine
        self.baselineEngine = baselineEngine
        self.xpEngine = xpEngine
        self.streakManager = streakManager
        self.questEngine = questEngine
    }

    /// Full refresh: fetch health data, compute scores, award XP, update quests.
    func refresh() async {
        guard let modelContext, let healthKitManager, let scoringEngine,
              let baselineEngine, let xpEngine, let streakManager, let questEngine else { return }

        isLoading = true
        error = nil

        do {
            // Ensure authorization
            if !healthKitManager.isAuthorized {
                try await healthKitManager.requestAuthorization()
            }

            // Get or create today's snapshot
            let today = Calendar.current.startOfDay(for: Date())
            let snapshot = fetchOrCreateSnapshot(for: today, in: modelContext)

            // Fetch today's health data
            let healthData = try await healthKitManager.fetchDailySummary(for: today)

            // Update raw metrics on snapshot
            snapshot.steps = healthData.steps
            snapshot.activeCalories = healthData.activeCalories
            snapshot.exerciseMinutes = healthData.exerciseMinutes
            snapshot.standMinutes = healthData.standMinutes
            snapshot.restingHeartRate = healthData.restingHeartRate
            snapshot.hrvSDNN = healthData.hrvSDNN
            snapshot.workoutCount = healthData.workoutCount
            snapshot.workoutTypes = healthData.workoutTypes
            snapshot.bodyMass = healthData.bodyMass
            snapshot.bodyFatPercentage = healthData.bodyFatPercentage
            snapshot.distanceWalkingRunning = healthData.distanceWalkingRunning
            snapshot.flightsClimbed = healthData.flightsClimbed
            snapshot.mindfulMinutes = healthData.mindfulMinutes
            if let sleep = healthData.sleep {
                snapshot.sleepDurationMinutes = sleep.totalMinutes
                snapshot.deepSleepMinutes = sleep.deepMinutes
                snapshot.remSleepMinutes = sleep.remMinutes
                snapshot.coreSleepMinutes = sleep.coreMinutes
                snapshot.awakeMinutes = sleep.awakeMinutes
                snapshot.bedtime = sleep.bedtime
                snapshot.wakeTime = sleep.wakeTime
            }

            // Update baselines
            baselineEngine.updateBaselines(from: healthData)

            // Get context for scoring
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            let prevSnapshot = fetchSnapshot(for: yesterday, in: modelContext)
            let recentHRV = fetchRecentHRV(days: 3, before: today, in: modelContext)
            let recentBedtimes = fetchRecentBedtimes(days: 7, before: today, in: modelContext)
            let activeDays = countActiveDays(last: 7, before: today, in: modelContext)

            // Get or create profile
            let profile = fetchOrCreateProfile(in: modelContext)

            // Compute scores
            scoringEngine.computeAllScores(
                for: snapshot,
                healthData: healthData,
                previousDaySnapshot: prevSnapshot,
                recentHRVValues: recentHRV,
                recentBedtimes: recentBedtimes,
                recentActiveDays: activeDays,
                profile: profile
            )

            snapshot.lastUpdated = Date()

            // Streak
            streakManager.processCheckIn(profile: profile)

            // XP
            let xp = xpEngine.evaluateDaily(snapshot: snapshot, profile: profile)
            xpGainedThisSession = xp

            // Achievements
            xpEngine.seedAchievementsIfNeeded()
            recentUnlocks = xpEngine.checkAchievements(snapshot: snapshot, profile: profile)

            // Quests
            let _ = questEngine.generateDailyQuests(for: today)
            let completedIDs = questEngine.evaluateQuests(snapshot: snapshot)
            for _ in completedIDs {
                let (questXP, _) = xpEngine.awardXP(.dailyQuestComplete, profile: profile)
                xpGainedThisSession += questXP
                profile.totalQuestsCompleted += 1
                snapshot.questsCompleted += 1
            }

            self.todaySnapshot = snapshot
            self.recentSnapshots = fetchRecentSnapshots(days: 7, in: modelContext)
            self.activeQuests = questEngine.activeQuests()
            self.profile = profile

            try modelContext.save()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Data Access Helpers

    private func fetchOrCreateSnapshot(for date: Date, in context: ModelContext) -> DailySnapshot {
        if let existing = fetchSnapshot(for: date, in: context) {
            return existing
        }
        let snapshot = DailySnapshot(date: date)
        context.insert(snapshot)
        return snapshot
    }

    private func fetchSnapshot(for date: Date, in context: ModelContext) -> DailySnapshot? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let descriptor = FetchDescriptor<DailySnapshot>(
            predicate: #Predicate { $0.date >= start && $0.date < end }
        )
        return try? context.fetch(descriptor).first
    }

    private func fetchOrCreateProfile(in context: ModelContext) -> UserProfile {
        let descriptor = FetchDescriptor<UserProfile>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let profile = UserProfile()
        context.insert(profile)
        return profile
    }

    private func fetchRecentHRV(days: Int, before date: Date, in context: ModelContext) -> [Double] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -days, to: date)!
        let descriptor = FetchDescriptor<DailySnapshot>(
            predicate: #Predicate { $0.date >= start && $0.date < date },
            sortBy: [SortDescriptor(\.date)]
        )
        guard let snapshots = try? context.fetch(descriptor) else { return [] }
        return snapshots.compactMap { $0.hrvSDNN }
    }

    private func fetchRecentBedtimes(days: Int, before date: Date, in context: ModelContext) -> [Date] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -days, to: date)!
        let descriptor = FetchDescriptor<DailySnapshot>(
            predicate: #Predicate { $0.date >= start && $0.date < date },
            sortBy: [SortDescriptor(\.date)]
        )
        guard let snapshots = try? context.fetch(descriptor) else { return [] }
        return snapshots.compactMap { $0.bedtime }
    }

    private func fetchRecentSnapshots(days: Int, in context: ModelContext) -> [DailySnapshot] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -days, to: today)!
        var descriptor = FetchDescriptor<DailySnapshot>(
            predicate: #Predicate { $0.date >= start },
            sortBy: [SortDescriptor(\.date)]
        )
        descriptor.fetchLimit = days + 1
        return (try? context.fetch(descriptor)) ?? []
    }

    private func countActiveDays(last days: Int, before date: Date, in context: ModelContext) -> Int {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -days, to: date)!
        let descriptor = FetchDescriptor<DailySnapshot>(
            predicate: #Predicate { $0.date >= start && $0.date < date && $0.checkedIn == true }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }
}
