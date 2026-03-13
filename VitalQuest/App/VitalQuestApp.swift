import SwiftUI
import SwiftData

@main
struct VitalQuestApp: App {
    let modelContainer: ModelContainer
    @State private var healthKitManager: HealthKitManager
    @State private var mockHealthKitManager: MockHealthKitManager
    @State private var scoringEngine: ScoringEngine
    @State private var baselineEngine: BaselineEngine
    @State private var xpEngine: XPEngine
    @State private var streakManager: StreakManager
    @State private var questEngine: QuestEngine
    @State private var dataExportService: DataExportService
    @State private var analyticsEngine: AnalyticsEngine
    @State private var mlModelManager: MLModelManager

    private let useMock: Bool

    init() {
        #if targetEnvironment(simulator)
        let useMock = true
        #else
        let useMock = false
        #endif
        self.useMock = useMock

        let schema = Schema([
            DailySnapshot.self,
            MetricBaseline.self,
            Quest.self,
            Achievement.self,
            UserProfile.self,
            JournalEntry.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        let context = modelContainer.mainContext
        let hkManager = HealthKitManager()
        let mockManager = MockHealthKitManager()
        let baseline = BaselineEngine(modelContext: context)
        let scoring = ScoringEngine(baselineEngine: baseline)
        let xp = XPEngine(modelContext: context)
        let streak = StreakManager(modelContext: context)
        let quest = QuestEngine(modelContext: context, baselineEngine: baseline)
        let export = DataExportService(modelContext: context)
        let analytics = AnalyticsEngine(modelContext: context, baselineEngine: baseline)
        let ml = MLModelManager()
        ml.loadModels()

        _healthKitManager = State(initialValue: hkManager)
        _mockHealthKitManager = State(initialValue: mockManager)
        _scoringEngine = State(initialValue: scoring)
        _baselineEngine = State(initialValue: baseline)
        _xpEngine = State(initialValue: xp)
        _streakManager = State(initialValue: streak)
        _questEngine = State(initialValue: quest)
        _dataExportService = State(initialValue: export)
        _analyticsEngine = State(initialValue: analytics)
        _mlModelManager = State(initialValue: ml)

        // Seed mock data in simulator if DB is empty
        if useMock {
            Self.seedMockDataIfNeeded(context: context)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(healthKitManager)
                .environment(mockHealthKitManager)
                .environment(scoringEngine)
                .environment(baselineEngine)
                .environment(xpEngine)
                .environment(streakManager)
                .environment(questEngine)
                .environment(dataExportService)
                .environment(analyticsEngine)
                .environment(mlModelManager)
        }
        .modelContainer(modelContainer)
    }

    /// Seed 30 days of mock snapshots + a profile so charts and UI have data
    private static func seedMockDataIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<DailySnapshot>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count < 7 else { return } // Already seeded

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for offset in 0..<30 {
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            let snap = DailySnapshot(date: date)

            // Realistic-ish data with slight day-to-day variation
            let dayFactor = 1.0 + sin(Double(offset) * 0.5) * 0.15
            snap.steps = Int(Double.random(in: 5000...13000) * dayFactor)
            snap.activeCalories = Double.random(in: 250...650) * dayFactor
            snap.exerciseMinutes = Double.random(in: 10...65)
            snap.standMinutes = Double.random(in: 30...100)
            snap.restingHeartRate = Double.random(in: 56...70) - (Double(offset) * 0.05) // slight improvement trend
            snap.hrvSDNN = Double.random(in: 28...58) + (Double(offset) * 0.08) // slight improvement trend
            let sleepTotal = Double.random(in: 360...510)
            let deepRatio = Double.random(in: 0.13...0.22)
            let remRatio = Double.random(in: 0.18...0.26)
            snap.sleepDurationMinutes = sleepTotal
            snap.deepSleepMinutes = sleepTotal * deepRatio
            snap.remSleepMinutes = sleepTotal * remRatio
            snap.coreSleepMinutes = sleepTotal - sleepTotal * deepRatio - sleepTotal * remRatio
            snap.awakeMinutes = Double.random(in: 8...35)
            snap.bodyMass = 75.0 + Double.random(in: -2...2) - (Double(offset) * 0.03) // slight downtrend
            snap.distanceWalkingRunning = Double.random(in: 2000...9000) * dayFactor
            snap.flightsClimbed = Int.random(in: 2...14)
            snap.mindfulMinutes = Bool.random() ? Double.random(in: 5...25) : nil
            snap.workoutCount = Int.random(in: 0...2)
            let workoutOptions = ["Running", "Cycling", "Yoga", "Swimming"]
            snap.workoutTypes = snap.workoutCount > 0 ? [workoutOptions[Int.random(in: 0..<workoutOptions.count)]] : []

            let sleepScore = Double.random(in: 40...90)
            snap.recoveryScore = Double.random(in: 45...92)
            snap.sleepScore = sleepScore
            snap.activityScore = Double.random(in: 35...88)

            snap.recoveryComponents = [
                "hrv_percentile": Double.random(in: 30...90),
                "rhr_percentile": Double.random(in: 35...85),
                "sleep_quality": sleepScore,
                "hrv_trend": Double.random(in: 40...80),
                "strain_impact": Double.random(in: 30...70)
            ]
            snap.sleepComponents = [
                "duration": Double.random(in: 50...95),
                "deep_sleep": Double.random(in: 40...85),
                "rem_sleep": Double.random(in: 35...80),
                "consistency": Double.random(in: 50...90),
                "nighttime_hrv": Double.random(in: 40...80),
                "sleep_latency": Double.random(in: 50...90)
            ]
            snap.activityComponents = [
                "calories": Double.random(in: 30...100),
                "steps": Double.random(in: 25...95),
                "exercise": Double.random(in: 20...100),
                "variety": Double.random(in: 0...80),
                "consistency": Double.random(in: 40...90)
            ]

            snap.xpEarned = Int.random(in: 30...180)
            snap.checkedIn = offset < 20 // Last 20 days checked in
            snap.dataCompleteness = Double.random(in: 0.6...1.0)

            context.insert(snap)
        }

        // Seed a profile with some progress
        let profileDescriptor = FetchDescriptor<UserProfile>()
        if (try? context.fetchCount(profileDescriptor)) == 0 {
            let profile = UserProfile()
            profile.totalXP = 2450
            profile.currentStreak = 12
            profile.longestStreak = 18
            profile.streakFreezes = 2
            profile.totalQuestsCompleted = 23
            context.insert(profile)
        }

        // Seed journal entries for ~20 of the 30 days
        let journalDescriptor = FetchDescriptor<JournalEntry>()
        if (try? context.fetchCount(journalDescriptor)) == 0 {
            let moods: [String] = Mood.allCases.map(\.rawValue)
            let noteOptions: [String?] = [
                nil, nil, nil, // Most days no notes
                "Felt great after morning run",
                "Rough night, woke up a few times",
                "Good energy all day",
                "Ate too late, couldn't sleep well",
                "Stayed on top of hydration today",
                nil,
            ]

            for offset in 0..<30 {
                // Skip ~10 random days
                guard offset % 3 != 2 else { continue }

                let date = calendar.date(byAdding: .day, value: -offset, to: today)!
                let entry = JournalEntry(
                    date: date,
                    hadCoffee: Bool.random(),
                    hadAlcohol: offset % 5 == 0,
                    stayedHydrated: Double.random(in: 0...1) > 0.3,
                    tookSupplements: Double.random(in: 0...1) > 0.5,
                    lateMeal: Double.random(in: 0...1) > 0.7,
                    screenBeforeBed: Double.random(in: 0...1) > 0.4,
                    feltStressed: Double.random(in: 0...1) > 0.7,
                    feltSick: Double.random(in: 0...1) > 0.9,
                    mood: moods[Int.random(in: 0..<moods.count)],
                    notes: noteOptions[Int.random(in: 0..<noteOptions.count)]
                )
                context.insert(entry)
            }
        }

        try? context.save()
    }
}
