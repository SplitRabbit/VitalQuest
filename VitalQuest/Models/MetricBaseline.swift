import Foundation
import SwiftData

@Model
final class MetricBaseline {
    // MARK: - Identity
    @Attribute(.unique) var metricName: String

    // MARK: - EWMA State (14-day, α = 0.133)
    var ewmaValue: Double
    var ewmaVariance: Double
    var ewmaAlpha: Double
    var ewmaSampleCount: Int

    // MARK: - Long-term Stats (60-day SMA)
    var longTermMean: Double
    var longTermStdDev: Double
    var longTermSampleCount: Int

    // MARK: - History for Percentile (90-day sorted)
    var sortedHistory: [Double]
    var historyDates: [Date]

    // MARK: - Metadata
    var lastUpdated: Date

    init(metricName: String, alpha: Double = 0.133) {
        self.metricName = metricName
        self.ewmaValue = 0
        self.ewmaVariance = 0
        self.ewmaAlpha = alpha
        self.ewmaSampleCount = 0
        self.longTermMean = 0
        self.longTermStdDev = 0
        self.longTermSampleCount = 0
        self.sortedHistory = []
        self.historyDates = []
        self.lastUpdated = Date()
    }
}

// Well-known metric names
extension MetricBaseline {
    static let restingHeartRate = "restingHeartRate"
    static let hrvSDNN = "hrvSDNN"
    static let sleepDuration = "sleepDuration"
    static let deepSleepRatio = "deepSleepRatio"
    static let remSleepRatio = "remSleepRatio"
    static let steps = "steps"
    static let activeCalories = "activeCalories"
    static let exerciseMinutes = "exerciseMinutes"
    static let bedtimeConsistency = "bedtimeConsistency"
}
