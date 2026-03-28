import Foundation
import SwiftData
import Observation

@Observable
final class DashboardViewModel {
    var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    var todaySnapshot: DailySnapshot?
    var recentSnapshots: [DailySnapshot] = [] // Last 7 days for charts
    var activeQuests: [Quest] = []
    var profile: UserProfile?
    var isLoading = false
    var error: String?
    var recentUnlocks: [String] = [] // Achievement IDs just unlocked
    var xpGainedThisSession = 0

    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    func goToPreviousDay() {
        guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        selectedDate = prev
    }

    func goToNextDay() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard selectedDate < today,
              let next = calendar.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        selectedDate = next
    }

    func goToToday() {
        selectedDate = Calendar.current.startOfDay(for: Date())
    }

    private var modelContext: ModelContext?
    private var healthKitManager: HealthKitDataProvider?
    private var scoringEngine: ScoringEngine?
    private var baselineEngine: BaselineEngine?
    private var xpEngine: XPEngine?
    private var streakManager: StreakManager?
    private var questEngine: QuestEngine?
    private var rawSampleCollector: RawSampleCollector?
    private var feedService: FeedService?

    func configure(
        modelContext: ModelContext,
        healthKitManager: HealthKitDataProvider,
        scoringEngine: ScoringEngine,
        baselineEngine: BaselineEngine,
        xpEngine: XPEngine,
        streakManager: StreakManager,
        questEngine: QuestEngine,
        rawSampleCollector: RawSampleCollector? = nil,
        feedService: FeedService? = nil
    ) {
        self.modelContext = modelContext
        self.healthKitManager = healthKitManager
        self.scoringEngine = scoringEngine
        self.baselineEngine = baselineEngine
        self.xpEngine = xpEngine
        self.streakManager = streakManager
        self.questEngine = questEngine
        self.rawSampleCollector = rawSampleCollector
        self.feedService = feedService
    }

    /// Load data for the selected date. Full scoring/XP only runs for today.
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

            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let profile = fetchOrCreateProfile(in: modelContext)

            if isToday {
                // Full refresh for today: fetch live data, score, XP, quests
                let snapshot = fetchOrCreateSnapshot(for: today, in: modelContext)
                let healthData = try await healthKitManager.fetchDailySummary(for: today)

                snapshot.steps = healthData.steps
                snapshot.activeCalories = healthData.activeCalories
                snapshot.exerciseMinutes = healthData.exerciseMinutes
                snapshot.standMinutes = healthData.standMinutes
                snapshot.restingHeartRate = healthData.restingHeartRate
                snapshot.hrvSDNN = healthData.hrvSummary?.mean
                snapshot.hrvMin = healthData.hrvSummary?.min
                snapshot.hrvMax = healthData.hrvSummary?.max
                snapshot.hrvSampleCount = healthData.hrvSummary?.sampleCount
                snapshot.heartRateMean = healthData.heartRateSummary?.mean
                snapshot.heartRateMin = healthData.heartRateSummary?.min
                snapshot.heartRateMax = healthData.heartRateSummary?.max
                snapshot.workoutCount = healthData.workouts.count
                snapshot.workoutTypes = healthData.workouts.types
                snapshot.workoutDurationMinutes = healthData.workouts.totalDurationMinutes > 0 ? healthData.workouts.totalDurationMinutes : nil
                snapshot.workoutCalories = healthData.workouts.totalCalories > 0 ? healthData.workouts.totalCalories : nil
                snapshot.workoutDistanceMeters = healthData.workouts.totalDistanceMeters > 0 ? healthData.workouts.totalDistanceMeters : nil
                snapshot.vo2Max = healthData.vo2Max
                snapshot.oxygenSaturation = healthData.oxygenSaturation
                snapshot.respiratoryRate = healthData.respiratoryRate
                snapshot.wristTemperature = healthData.wristTemperature
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

                baselineEngine.updateBaselines(from: healthData)

                let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
                let prevSnapshot = fetchSnapshot(for: yesterday, in: modelContext)
                let recentHRV = fetchRecentHRV(days: 3, before: today, in: modelContext)
                let recentBedtimes = fetchRecentBedtimes(days: 7, before: today, in: modelContext)
                let activeDays = countActiveDays(last: 7, before: today, in: modelContext)

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

                streakManager.processCheckIn(profile: profile)

                let xp = xpEngine.evaluateDaily(snapshot: snapshot, profile: profile)
                xpGainedThisSession = xp

                xpEngine.seedAchievementsIfNeeded()
                recentUnlocks = xpEngine.checkAchievements(snapshot: snapshot, profile: profile)

                let _ = questEngine.generateDailyQuests(for: today)
                let completedIDs = questEngine.evaluateQuests(snapshot: snapshot)
                for _ in completedIDs {
                    let (questXP, _) = xpEngine.awardXP(.dailyQuestComplete, profile: profile)
                    xpGainedThisSession += questXP
                    profile.totalQuestsCompleted += 1
                    snapshot.questsCompleted += 1
                }

                // Record feed items for today's events
                if let feed = feedService {
                    // Record workouts
                    for workoutType in healthData.workouts.types {
                        feed.recordWorkout(
                            type: workoutType,
                            durationMinutes: healthData.workouts.totalDurationMinutes / max(1.0, Double(healthData.workouts.count)),
                            calories: healthData.workouts.totalCalories > 0 ? healthData.workouts.totalCalories / max(1.0, Double(healthData.workouts.count)) : nil,
                            distanceMeters: healthData.workouts.totalDistanceMeters > 0 ? healthData.workouts.totalDistanceMeters / max(1.0, Double(healthData.workouts.count)) : nil
                        )
                    }

                    // Record achievements
                    for achievementID in recentUnlocks {
                        let desc = FetchDescriptor<Achievement>(predicate: #Predicate { $0.id == achievementID })
                        if let achievement = try? modelContext.fetch(desc).first {
                            feed.recordAchievementUnlocked(achievement: achievement)
                        }
                    }

                    // Quest completions and daily summaries excluded from feed per design
                }

                self.todaySnapshot = snapshot
                self.activeQuests = questEngine.activeQuests()

                // Collect raw samples in background (doesn't block UI)
                if let collector = rawSampleCollector {
                    Task.detached(priority: .utility) {
                        await collector.collectRawSamples(for: today)
                    }
                }
            } else {
                // Past day: just read the stored snapshot
                self.todaySnapshot = fetchSnapshot(for: selectedDate, in: modelContext)
                self.activeQuests = []
            }

            self.recentSnapshots = fetchRecentSnapshots(days: 7, before: selectedDate, in: modelContext)
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

    private func fetchRecentSnapshots(days: Int, before date: Date, in context: ModelContext) -> [DailySnapshot] {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
        let start = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: date))!
        var descriptor = FetchDescriptor<DailySnapshot>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
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
