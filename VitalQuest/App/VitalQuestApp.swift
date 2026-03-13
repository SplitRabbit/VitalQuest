import SwiftUI
import SwiftData

@main
struct VitalQuestApp: App {
    let modelContainer: ModelContainer
    @State private var healthKitManager: HealthKitManager
    @State private var scoringEngine: ScoringEngine
    @State private var baselineEngine: BaselineEngine
    @State private var xpEngine: XPEngine
    @State private var streakManager: StreakManager
    @State private var questEngine: QuestEngine

    init() {
        let schema = Schema([
            DailySnapshot.self,
            MetricBaseline.self,
            Quest.self,
            Achievement.self,
            UserProfile.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        let context = modelContainer.mainContext
        let hkManager = HealthKitManager()
        let baseline = BaselineEngine(modelContext: context)
        let scoring = ScoringEngine(baselineEngine: baseline)
        let xp = XPEngine(modelContext: context)
        let streak = StreakManager(modelContext: context)
        let quest = QuestEngine(modelContext: context, baselineEngine: baseline)

        _healthKitManager = State(initialValue: hkManager)
        _scoringEngine = State(initialValue: scoring)
        _baselineEngine = State(initialValue: baseline)
        _xpEngine = State(initialValue: xp)
        _streakManager = State(initialValue: streak)
        _questEngine = State(initialValue: quest)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(healthKitManager)
                .environment(scoringEngine)
                .environment(baselineEngine)
                .environment(xpEngine)
                .environment(streakManager)
                .environment(questEngine)
        }
        .modelContainer(modelContainer)
    }
}
