import Foundation
import SwiftData
import Observation

/// Manages personalized baselines using EWMA (14-day) and SMA (60-day).
/// Provides z-scores and percentile ranks against user's own history.
@Observable
final class BaselineEngine {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Update Baseline

    /// Record a new data point for a metric, updating EWMA and history.
    func recordValue(_ value: Double, for metricName: String, on date: Date = Date()) {
        let baseline = fetchOrCreate(metricName: metricName)

        // Update EWMA
        if baseline.ewmaSampleCount == 0 {
            baseline.ewmaValue = value
            baseline.ewmaVariance = 0
        } else {
            let newEWMA = Statistics.ewmaUpdate(previous: baseline.ewmaValue, newValue: value, alpha: baseline.ewmaAlpha)
            baseline.ewmaVariance = Statistics.ewmaVarianceUpdate(
                previousVariance: baseline.ewmaVariance,
                newValue: value,
                ewma: baseline.ewmaValue,
                alpha: baseline.ewmaAlpha
            )
            baseline.ewmaValue = newEWMA
        }
        baseline.ewmaSampleCount += 1

        // Update sorted history for percentiles
        Statistics.insertSorted(
            value: value,
            date: date,
            into: &baseline.sortedHistory,
            dates: &baseline.historyDates,
            maxCount: 90
        )

        // Recompute long-term stats from history
        baseline.longTermMean = Statistics.sma(values: baseline.sortedHistory)
        baseline.longTermStdDev = Statistics.stdDev(values: baseline.sortedHistory)
        baseline.longTermSampleCount = baseline.sortedHistory.count

        baseline.lastUpdated = date
    }

    // MARK: - Query Baseline

    /// Get the current EWMA (short-term trend) for a metric
    func ewma(for metricName: String) -> Double? {
        let baseline = fetch(metricName: metricName)
        guard let b = baseline, b.ewmaSampleCount > 0 else { return nil }
        return b.ewmaValue
    }

    /// Get the 60-day SMA (long-term baseline) for a metric
    func longTermMean(for metricName: String) -> Double? {
        let baseline = fetch(metricName: metricName)
        guard let b = baseline, b.longTermSampleCount > 0 else { return nil }
        return b.longTermMean
    }

    /// Z-score of a value against the 90-day personal distribution
    func zScore(value: Double, for metricName: String) -> Double {
        guard let baseline = fetch(metricName: metricName),
              baseline.longTermStdDev > 0 else { return 0 }
        return Statistics.zScore(value: value, mean: baseline.longTermMean, stdDev: baseline.longTermStdDev)
    }

    /// Percentile rank (0-100) of a value against user's 90-day history
    func percentile(value: Double, for metricName: String) -> Double {
        guard let baseline = fetch(metricName: metricName),
              !baseline.sortedHistory.isEmpty else { return 50 }
        return Statistics.percentileRank(value: value, in: baseline.sortedHistory)
    }

    /// Inverted percentile (lower = better, e.g., resting HR)
    func invertedPercentile(value: Double, for metricName: String) -> Double {
        guard let baseline = fetch(metricName: metricName),
              !baseline.sortedHistory.isEmpty else { return 50 }
        return Statistics.invertedPercentileRank(value: value, in: baseline.sortedHistory)
    }

    /// Whether we have enough data for meaningful baselines (≥14 days)
    func hasBaseline(for metricName: String) -> Bool {
        guard let baseline = fetch(metricName: metricName) else { return false }
        return baseline.ewmaSampleCount >= 14
    }

    /// Number of days of data we have for a metric
    func sampleCount(for metricName: String) -> Int {
        fetch(metricName: metricName)?.ewmaSampleCount ?? 0
    }

    // MARK: - Batch Update from DailyHealthData

    /// Update all baselines from a daily health data record
    func updateBaselines(from data: DailyHealthData) {
        recordValue(Double(data.steps), for: MetricBaseline.steps, on: data.date)
        recordValue(data.activeCalories, for: MetricBaseline.activeCalories, on: data.date)
        recordValue(data.exerciseMinutes, for: MetricBaseline.exerciseMinutes, on: data.date)

        if let rhr = data.restingHeartRate {
            recordValue(rhr, for: MetricBaseline.restingHeartRate, on: data.date)
        }
        if let hrv = data.hrvSDNN {
            recordValue(Statistics.lnTransform(hrv), for: MetricBaseline.hrvSDNN, on: data.date)
        }
        if let sleep = data.sleep {
            recordValue(sleep.totalMinutes, for: MetricBaseline.sleepDuration, on: data.date)
            let total = sleep.totalMinutes
            if total > 0 {
                recordValue(sleep.deepMinutes / total, for: MetricBaseline.deepSleepRatio, on: data.date)
                recordValue(sleep.remMinutes / total, for: MetricBaseline.remSleepRatio, on: data.date)
            }
        }
    }

    // MARK: - Private

    private func fetch(metricName: String) -> MetricBaseline? {
        let descriptor = FetchDescriptor<MetricBaseline>(
            predicate: #Predicate { $0.metricName == metricName }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchOrCreate(metricName: String) -> MetricBaseline {
        if let existing = fetch(metricName: metricName) {
            return existing
        }
        let baseline = MetricBaseline(metricName: metricName)
        modelContext.insert(baseline)
        return baseline
    }
}
