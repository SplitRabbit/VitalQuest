import Foundation
import SwiftData
import Observation

/// Generates and evaluates quests with adaptive difficulty.
@Observable
final class QuestEngine {
    private let modelContext: ModelContext
    private let baselineEngine: BaselineEngine

    init(modelContext: ModelContext, baselineEngine: BaselineEngine) {
        self.modelContext = modelContext
        self.baselineEngine = baselineEngine
    }

    // MARK: - Quest Templates

    struct QuestTemplate {
        let titlePattern: String
        let flavorText: String
        let metric: String
        let baseTarget: Double
        let scaleFactor: Double  // Multiplied by user's baseline
        let type: QuestType
        let baseXP: Int
    }

    static let dailyTemplates: [QuestTemplate] = [
        QuestTemplate(
            titlePattern: "March to the Market",
            flavorText: "The village needs supplies — trek to the merchant before sundown.",
            metric: "steps", baseTarget: 8000, scaleFactor: 1.1, type: .daily, baseXP: 30
        ),
        QuestTemplate(
            titlePattern: "The Burning Path",
            flavorText: "Channel your inner fire and burn through your calorie target.",
            metric: "activeCalories", baseTarget: 400, scaleFactor: 1.1, type: .daily, baseXP: 30
        ),
        QuestTemplate(
            titlePattern: "Training Grounds",
            flavorText: "Report to the training grounds for your daily exercise.",
            metric: "exerciseMinutes", baseTarget: 25, scaleFactor: 1.0, type: .daily, baseXP: 30
        ),
        QuestTemplate(
            titlePattern: "The Long Road",
            flavorText: "An ambitious journey awaits — push beyond your usual distance.",
            metric: "steps", baseTarget: 12000, scaleFactor: 1.2, type: .daily, baseXP: 40
        ),
        QuestTemplate(
            titlePattern: "Ember Sprint",
            flavorText: "A quick burst of flame — a short but intense workout.",
            metric: "exerciseMinutes", baseTarget: 15, scaleFactor: 0.8, type: .daily, baseXP: 20
        ),
        QuestTemplate(
            titlePattern: "Rest at the Inn",
            flavorText: "Even heroes need rest. Achieve a sleep score of 75+.",
            metric: "sleepScore", baseTarget: 75, scaleFactor: 1.0, type: .daily, baseXP: 25
        ),
        QuestTemplate(
            titlePattern: "Stand Your Ground",
            flavorText: "A vigilant watch requires standing guard through the day.",
            metric: "standMinutes", baseTarget: 60, scaleFactor: 1.0, type: .daily, baseXP: 25
        ),
        QuestTemplate(
            titlePattern: "The Forge Burns Hot",
            flavorText: "Stoke the furnace — burn through a challenging calorie goal.",
            metric: "activeCalories", baseTarget: 600, scaleFactor: 1.2, type: .daily, baseXP: 40
        ),
        QuestTemplate(
            titlePattern: "Warrior's Recovery",
            flavorText: "Let your body recover — achieve a recovery score of 70+.",
            metric: "recoveryScore", baseTarget: 70, scaleFactor: 1.0, type: .daily, baseXP: 25
        ),
        QuestTemplate(
            titlePattern: "The Pilgrim's Path",
            flavorText: "A gentle walk through the countryside. Every step counts.",
            metric: "steps", baseTarget: 5000, scaleFactor: 0.9, type: .daily, baseXP: 20
        ),
    ]

    // MARK: - Generate Daily Quests

    /// Generate 3 daily quests for today. Call at midnight or on first launch.
    func generateDailyQuests(for date: Date = Date()) -> [Quest] {
        // Don't duplicate if already generated today
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

        let descriptor = FetchDescriptor<Quest>(
            predicate: #Predicate { quest in
                quest.assignedDate >= dayStart &&
                quest.assignedDate < dayEnd
            }
        )
        if let existing = try? modelContext.fetch(descriptor) {
            let dailyExisting = existing.filter { $0.type == .daily }
            if !dailyExisting.isEmpty { return dailyExisting }
        }

        // Pick 3 random templates with different metrics
        var selectedTemplates: [QuestTemplate] = []
        var usedMetrics: Set<String> = []
        var shuffled = Self.dailyTemplates.shuffled()

        while selectedTemplates.count < 3 && !shuffled.isEmpty {
            let template = shuffled.removeFirst()
            if !usedMetrics.contains(template.metric) {
                selectedTemplates.append(template)
                usedMetrics.insert(template.metric)
            }
        }

        let quests = selectedTemplates.map { template in
            let target = adaptiveTarget(for: template)
            let quest = Quest(
                title: template.titlePattern,
                flavorText: template.flavorText,
                type: .daily,
                metric: template.metric,
                targetValue: target,
                xpReward: template.baseXP,
                assignedDate: dayStart,
                deadline: dayEnd
            )
            modelContext.insert(quest)
            return quest
        }

        return quests
    }

    // MARK: - Evaluate Quests

    /// Update quest progress based on today's data. Returns newly completed quest IDs.
    func evaluateQuests(snapshot: DailySnapshot) -> [UUID] {
        let descriptor = FetchDescriptor<Quest>()
        guard let allQuests = try? modelContext.fetch(descriptor) else { return [] }
        let activeQuests = allQuests.filter { $0.status == .active }

        var completed: [UUID] = []

        for quest in activeQuests {
            // Check if expired
            if quest.isExpired {
                quest.status = .expired
                continue
            }

            // Update progress
            let currentValue = metricValue(for: quest.metric, from: snapshot)
            quest.currentValue = currentValue

            // Check completion
            if currentValue >= quest.targetValue {
                quest.status = .completed
                quest.completedDate = Date()
                completed.append(quest.id)
            }
        }

        return completed
    }

    /// Get active quests
    func activeQuests() -> [Quest] {
        let descriptor = FetchDescriptor<Quest>(
            sortBy: [SortDescriptor(\.assignedDate, order: .reverse)]
        )
        return ((try? modelContext.fetch(descriptor)) ?? []).filter { $0.status == .active }
    }

    /// Get recently completed quests
    func completedQuests(limit: Int = 20) -> [Quest] {
        let descriptor = FetchDescriptor<Quest>(
            sortBy: [SortDescriptor(\.assignedDate, order: .reverse)]
        )
        return ((try? modelContext.fetch(descriptor)) ?? [])
            .filter { $0.status == .completed }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Private

    private func adaptiveTarget(for template: QuestTemplate) -> Double {
        // If we have a baseline, scale the target to the user's level
        if let baseline = baselineEngine.ewma(for: template.metric) {
            return baseline * template.scaleFactor
        }
        return template.baseTarget
    }

    private func metricValue(for metric: String, from snapshot: DailySnapshot) -> Double {
        switch metric {
        case "steps": return Double(snapshot.steps)
        case "activeCalories": return snapshot.activeCalories
        case "exerciseMinutes": return snapshot.exerciseMinutes
        case "standMinutes": return snapshot.standMinutes
        case "sleepScore": return snapshot.sleepScore ?? 0
        case "recoveryScore": return snapshot.recoveryScore ?? 0
        case "activityScore": return snapshot.activityScore ?? 0
        default: return 0
        }
    }
}
