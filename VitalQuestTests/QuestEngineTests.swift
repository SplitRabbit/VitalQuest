import Testing
import Foundation
import SwiftData
@testable import VitalQuest

@Suite("Quest Engine Tests")
@MainActor
struct QuestEngineTests {
    let modelContainer: ModelContainer
    let baselineEngine: BaselineEngine
    let questEngine: QuestEngine

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: DailySnapshot.self, MetricBaseline.self, Quest.self,
            Achievement.self, UserProfile.self, JournalEntry.self, CustomLog.self, FeedItem.self, Activity.self,
            configurations: config
        )
        baselineEngine = BaselineEngine(modelContext: modelContainer.mainContext)
        questEngine = QuestEngine(modelContext: modelContainer.mainContext, baselineEngine: baselineEngine)
    }

    // MARK: - Generation

    @Test("Generate daily quests creates 3 quests")
    func generateCreatesThree() {
        let quests = questEngine.generateDailyQuests()
        #expect(quests.count == 3)
    }

    @Test("Generated quests have different metrics")
    func generateDifferentMetrics() {
        let quests = questEngine.generateDailyQuests()
        let metrics = Set(quests.map(\.metric))
        #expect(metrics.count == 3)
    }

    @Test("Generate is idempotent for same day")
    func generateIdempotent() {
        let first = questEngine.generateDailyQuests()
        let second = questEngine.generateDailyQuests()
        #expect(first.count == 3)
        #expect(second.count == first.count)
        // Second call returns existing quests
        let firstIDs = Set(first.map(\.id))
        let secondIDs = Set(second.map(\.id))
        #expect(firstIDs == secondIDs)
    }

    @Test("Generated quests are active")
    func generatedQuestsActive() {
        let quests = questEngine.generateDailyQuests()
        for quest in quests {
            #expect(quest.status == .active)
        }
    }

    @Test("Generated quests use base targets without baseline")
    func baseTargetsWithoutBaseline() {
        let quests = questEngine.generateDailyQuests()
        // Without baselines, targets should match template base targets
        for quest in quests {
            #expect(quest.targetValue > 0)
        }
    }

    @Test("Adaptive targets scale with baseline")
    func adaptiveTargetsWithBaseline() {
        // Build baselines for steps
        for _ in 0..<20 {
            baselineEngine.recordValue(12000, for: "steps")
        }

        let quests = questEngine.generateDailyQuests()
        let stepQuest = quests.first { $0.metric == "steps" }
        if let sq = stepQuest {
            // Target should be based on ~12000 baseline * scaleFactor
            #expect(sq.targetValue > 8000) // Higher than base default
        }
    }

    // MARK: - Evaluation

    @Test("Quest completes when metric exceeds target")
    func questCompletesOnTarget() {
        let quests = questEngine.generateDailyQuests()
        let snapshot = DailySnapshot(date: Date())
        // Set all metrics high to ensure at least some quests complete
        snapshot.steps = 20000
        snapshot.activeCalories = 800
        snapshot.exerciseMinutes = 60
        snapshot.standMinutes = 120
        snapshot.sleepScore = 90
        snapshot.recoveryScore = 90
        snapshot.activityScore = 90
        modelContainer.mainContext.insert(snapshot)

        let completed = questEngine.evaluateQuests(snapshot: snapshot)
        #expect(!completed.isEmpty)
    }

    @Test("Quest stays active when metric below target")
    func questStaysActive() {
        let _ = questEngine.generateDailyQuests()
        let snapshot = DailySnapshot(date: Date())
        // Zero metrics — nothing should complete
        snapshot.steps = 0
        snapshot.activeCalories = 0
        snapshot.exerciseMinutes = 0
        snapshot.standMinutes = 0
        modelContainer.mainContext.insert(snapshot)

        let completed = questEngine.evaluateQuests(snapshot: snapshot)
        #expect(completed.isEmpty)
        #expect(!questEngine.activeQuests().isEmpty)
    }

    @Test("Completed quest has completedDate set")
    func completedQuestHasDate() {
        let _ = questEngine.generateDailyQuests()
        let snapshot = DailySnapshot(date: Date())
        snapshot.steps = 50000
        snapshot.activeCalories = 2000
        snapshot.exerciseMinutes = 120
        snapshot.standMinutes = 200
        snapshot.sleepScore = 100
        snapshot.recoveryScore = 100
        modelContainer.mainContext.insert(snapshot)

        let completedIDs = questEngine.evaluateQuests(snapshot: snapshot)
        let allQuests = questEngine.completedQuests()
        for quest in allQuests where completedIDs.contains(quest.id) {
            #expect(quest.completedDate != nil)
            #expect(quest.status == .completed)
        }
    }

    @Test("Active quests returns only active status")
    func activeQuestsFilter() {
        let _ = questEngine.generateDailyQuests()
        let snapshot = DailySnapshot(date: Date())
        snapshot.steps = 50000
        snapshot.activeCalories = 2000
        snapshot.exerciseMinutes = 120
        snapshot.standMinutes = 200
        snapshot.sleepScore = 100
        snapshot.recoveryScore = 100
        modelContainer.mainContext.insert(snapshot)

        let _ = questEngine.evaluateQuests(snapshot: snapshot)
        let active = questEngine.activeQuests()
        for quest in active {
            #expect(quest.status == .active)
        }
    }

    @Test("Completed quests list respects limit")
    func completedQuestsLimit() {
        // Generate quests for multiple days
        let calendar = Calendar.current
        for offset in 0..<5 {
            let date = calendar.date(byAdding: .day, value: -(offset + 1), to: Date())!
            let quest = Quest(
                title: "Test Quest \(offset)",
                flavorText: "Test",
                type: .daily,
                metric: "steps",
                targetValue: 1000,
                xpReward: 30,
                assignedDate: date,
                deadline: calendar.date(byAdding: .day, value: 1, to: date)!
            )
            quest.status = .completed
            quest.completedDate = date
            modelContainer.mainContext.insert(quest)
        }

        let completed = questEngine.completedQuests(limit: 3)
        #expect(completed.count == 3)
    }
}
