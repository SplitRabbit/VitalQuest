import Foundation
import SwiftData

@Model
final class DailySnapshot {

    // MARK: - Identity
    @Attribute(.unique) var date: Date // Calendar day (midnight UTC)

    // MARK: - Raw Metrics
    var steps: Int
    var activeCalories: Double
    var exerciseMinutes: Double
    var standMinutes: Double
    var restingHeartRate: Double?
    var hrvSDNN: Double? // Mean of all daily samples (was: single sample)
    var hrvMin: Double?
    var hrvMax: Double?
    var hrvSampleCount: Int?
    var heartRateMean: Double?
    var heartRateMin: Double?
    var heartRateMax: Double?
    var sleepDurationMinutes: Double?
    var deepSleepMinutes: Double?
    var remSleepMinutes: Double?
    var coreSleepMinutes: Double?
    var awakeMinutes: Double?
    var bedtime: Date?
    var wakeTime: Date?
    var vo2Max: Double?
    var oxygenSaturation: Double?
    var respiratoryRate: Double?
    var wristTemperature: Double?
    var bodyMass: Double? // Weight in kg
    var bodyFatPercentage: Double?
    var distanceWalkingRunning: Double? // in meters
    var flightsClimbed: Int?
    var mindfulMinutes: Double?
    var workoutCount: Int
    var workoutTypes: [String]
    var workoutDurationMinutes: Double?
    var workoutCalories: Double?
    var workoutDistanceMeters: Double?

    // MARK: - Computed Scores (0-100)
    var recoveryScore: Double?
    var sleepScore: Double?
    var activityScore: Double?

    // MARK: - Score Components (stored for drill-down)
    var recoveryComponents: [String: Double]
    var sleepComponents: [String: Double]
    var activityComponents: [String: Double]

    // MARK: - Gamification
    var xpEarned: Int
    var questsCompleted: Int
    var checkedIn: Bool

    // MARK: - Metadata
    var lastUpdated: Date
    var dataCompleteness: Double // 0-1, fraction of expected metrics present

    init(date: Date) {
        self.date = Calendar.current.startOfDay(for: date)
        self.steps = 0
        self.activeCalories = 0
        self.exerciseMinutes = 0
        self.standMinutes = 0
        self.workoutCount = 0
        self.workoutTypes = []
        self.recoveryComponents = [:]
        self.sleepComponents = [:]
        self.activityComponents = [:]
        self.xpEarned = 0
        self.questsCompleted = 0
        self.checkedIn = false
        self.lastUpdated = Date()
        self.dataCompleteness = 0
    }
}

extension DailySnapshot {
    /// Calendar-day string for grouping (e.g. "2026-03-12")
    var dateString: String {
        date.formatted(.iso8601.year().month().day())
    }

    /// Whether this snapshot has enough data for meaningful scores
    var hasSufficientData: Bool {
        dataCompleteness >= 0.3
    }

    /// Primary display score
    var primaryScore: Double {
        recoveryScore ?? sleepScore ?? activityScore ?? 0
    }

    /// Color tier based on score value
    static func scoreTier(_ score: Double) -> ScoreTier {
        switch score {
        case 80...100: return .excellent
        case 60..<80: return .good
        case 40..<60: return .fair
        default: return .low
        }
    }
}

enum ScoreTier: String, CaseIterable {
    case excellent, good, fair, low

    var label: String {
        switch self {
        case .excellent: "Excellent"
        case .good: "Good"
        case .fair: "Fair"
        case .low: "Low"
        }
    }
}
