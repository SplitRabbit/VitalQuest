import Foundation
import SwiftData

@Model
final class FeedItem {
    @Attribute(.unique) var id: UUID

    var timestamp: Date
    var type: FeedItemType
    var title: String
    var detail: String?
    var icon: String            // SF Symbol
    var accentColorName: String // Color name from theme (e.g. "green", "blue", "pink")

    // Visibility
    var visibility: FeedVisibility

    // User-authored sharing content
    var caption: String?
    @Attribute(.externalStorage) var photoData: Data? // Stored externally for large images

    // Optional references
    var metricValue: Double?
    var metricUnit: String?
    var relatedAchievementID: String?
    var relatedQuestID: String?

    init(
        type: FeedItemType,
        title: String,
        detail: String? = nil,
        icon: String,
        accentColorName: String = "green",
        visibility: FeedVisibility = .private,
        metricValue: Double? = nil,
        metricUnit: String? = nil,
        relatedAchievementID: String? = nil,
        relatedQuestID: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.type = type
        self.title = title
        self.detail = detail
        self.icon = icon
        self.accentColorName = accentColorName
        self.visibility = visibility
        self.metricValue = metricValue
        self.metricUnit = metricUnit
        self.relatedAchievementID = relatedAchievementID
        self.relatedQuestID = relatedQuestID
    }
}

// MARK: - Feed Item Types

enum FeedItemType: String, Codable, CaseIterable {
    case workout
    case achievement
    case questComplete
    case milestone        // Level up, streak milestone
    case personalBest
    case dailySummary
    case streakUpdate
}

// MARK: - Visibility

enum FeedVisibility: String, Codable, CaseIterable {
    case `public`   // Visible to friends
    case `private`  // Only visible to user

    var label: String {
        switch self {
        case .public: "Public"
        case .private: "Private"
        }
    }

    var icon: String {
        switch self {
        case .public: "globe"
        case .private: "lock.fill"
        }
    }
}
