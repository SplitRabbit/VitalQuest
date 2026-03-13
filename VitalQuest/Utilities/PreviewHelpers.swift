import SwiftUI
import SwiftData

/// Preview environment modifier that injects mock services
struct MockEnvironmentModifier: ViewModifier {
    func body(content: Content) -> some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: DailySnapshot.self, MetricBaseline.self, Quest.self, Achievement.self, UserProfile.self, JournalEntry.self,
            configurations: config
        )
        let context = container.mainContext
        let hk = HealthKitManager()
        let mock = MockHealthKitManager()
        let baseline = BaselineEngine(modelContext: context)
        let scoring = ScoringEngine(baselineEngine: baseline)
        let xp = XPEngine(modelContext: context)
        let streak = StreakManager(modelContext: context)
        let quest = QuestEngine(modelContext: context, baselineEngine: baseline)

        return content
            .modelContainer(container)
            .environment(hk)
            .environment(mock)
            .environment(scoring)
            .environment(baseline)
            .environment(xp)
            .environment(streak)
            .environment(quest)
    }
}

extension View {
    func withMockEnvironment() -> some View {
        modifier(MockEnvironmentModifier())
    }
}
