import Foundation
import SwiftData

@Model
final class Quest {


    @Attribute(.unique) var id: UUID

    var title: String
    var flavorText: String
    var type: QuestType
    var status: QuestStatus
    var metric: String           // e.g. "steps", "sleepScore", "exerciseMinutes"
    var targetValue: Double
    var currentValue: Double
    var xpReward: Int
    var assignedDate: Date
    var deadline: Date
    var completedDate: Date?

    init(
        title: String,
        flavorText: String,
        type: QuestType,
        metric: String,
        targetValue: Double,
        xpReward: Int,
        assignedDate: Date = Date(),
        deadline: Date
    ) {
        self.id = UUID()
        self.title = title
        self.flavorText = flavorText
        self.type = type
        self.status = .active
        self.metric = metric
        self.targetValue = targetValue
        self.currentValue = 0
        self.xpReward = xpReward
        self.assignedDate = assignedDate
        self.deadline = deadline
        self.completedDate = nil
    }

    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(currentValue / targetValue, 1.0)
    }

    var isExpired: Bool {
        status == .active && Date() > deadline
    }
}

enum QuestType: String, Codable, CaseIterable {
    case daily
    case weekly
    case epic
}

enum QuestStatus: String, Codable, CaseIterable {
    case active
    case completed
    case failed
    case expired
}
