import Foundation
import SwiftData

@Observable
final class AnalyticsEngine {
    private let modelContext: ModelContext
    private let baselineEngine: BaselineEngine

    init(modelContext: ModelContext, baselineEngine: BaselineEngine) {
        self.modelContext = modelContext
        self.baselineEngine = baselineEngine
    }

    // MARK: - Metric Extraction

    /// All numeric metrics extractable from a DailySnapshot, keyed by name.
    static let metricExtractors: [String: (DailySnapshot) -> Double?] = [
        "steps": { Double($0.steps) },
        "activeCalories": { $0.activeCalories },
        "exerciseMinutes": { $0.exerciseMinutes },
        "standMinutes": { $0.standMinutes },
        "restingHeartRate": { $0.restingHeartRate },
        "hrvSDNN": { $0.hrvSDNN },
        "sleepDurationMinutes": { $0.sleepDurationMinutes },
        "deepSleepMinutes": { $0.deepSleepMinutes },
        "remSleepMinutes": { $0.remSleepMinutes },
        "coreSleepMinutes": { $0.coreSleepMinutes },
        "awakeMinutes": { $0.awakeMinutes },
        "vo2Max": { $0.vo2Max },
        "oxygenSaturation": { $0.oxygenSaturation },
        "respiratoryRate": { $0.respiratoryRate },
        "wristTemperature": { $0.wristTemperature },
        "bodyMass": { $0.bodyMass },
        "bodyFatPercentage": { $0.bodyFatPercentage },
        "distanceWalkingRunning": { $0.distanceWalkingRunning },
        "flightsClimbed": { $0.flightsClimbed.map(Double.init) },
        "mindfulMinutes": { $0.mindfulMinutes },
        "workoutCount": { Double($0.workoutCount) },
        "hrvMin": { $0.hrvMin },
        "hrvMax": { $0.hrvMax },
        "hrvSampleCount": { $0.hrvSampleCount.map(Double.init) },
        "heartRateMean": { $0.heartRateMean },
        "heartRateMin": { $0.heartRateMin },
        "heartRateMax": { $0.heartRateMax },
        "workoutDurationMinutes": { $0.workoutDurationMinutes },
        "workoutCalories": { $0.workoutCalories },
        "workoutDistanceMeters": { $0.workoutDistanceMeters },
        "recoveryScore": { $0.recoveryScore },
        "sleepScore": { $0.sleepScore },
        "activityScore": { $0.activityScore },
        "dataCompleteness": { $0.dataCompleteness }
    ]

    /// Extract time series for a given metric across snapshots.
    private func extractValues(for metric: String, from snapshots: [DailySnapshot]) -> [Double] {
        guard let extractor = Self.metricExtractors[metric] else { return [] }
        return snapshots.compactMap { extractor($0) }
    }

    // MARK: - Trend Detection

    func computeTrends(snapshots: [DailySnapshot], windows: [Int] = [7, 14, 30]) -> [MetricTrend] {
        let sorted = snapshots.sorted { $0.date < $1.date }
        var trends: [MetricTrend] = []

        for (metric, _) in Self.metricExtractors {
            let allValues = extractValues(for: metric, from: sorted)
            guard allValues.count >= 7 else { continue }

            let sd = Statistics.stdDev(values: allValues)
            guard sd > 0 else { continue }

            for window in windows {
                guard allValues.count >= window else { continue }
                let windowValues = Array(allValues.suffix(window))
                let slope = Statistics.linearSlope(values: windowValues)
                let magnitude = slope / sd

                let direction: MetricTrend.TrendDirection
                if abs(magnitude) < 0.1 {
                    direction = .stable
                } else if magnitude > 0 {
                    // For most metrics, increasing is improving.
                    // For RHR and awakeMinutes, lower is better.
                    let invertedMetrics: Set<String> = ["restingHeartRate", "awakeMinutes"]
                    direction = invertedMetrics.contains(metric) ? .declining : .improving
                } else {
                    let invertedMetrics: Set<String> = ["restingHeartRate", "awakeMinutes"]
                    direction = invertedMetrics.contains(metric) ? .improving : .declining
                }

                trends.append(MetricTrend(
                    metric: metric,
                    window: window,
                    slope: slope,
                    direction: direction,
                    magnitude: magnitude
                ))
            }
        }

        return trends
    }

    // MARK: - Correlation Analysis

    func computeCorrelations(snapshots: [DailySnapshot]) -> CorrelationMatrix {
        let sorted = snapshots.sorted { $0.date < $1.date }
        let metricNames = Self.metricExtractors.keys.sorted()

        // Build per-metric arrays (only where all values present across snapshots)
        var metricValues: [String: [Double]] = [:]
        for metric in metricNames {
            let values = extractValues(for: metric, from: sorted)
            if values.count == sorted.count && values.count >= 10 {
                metricValues[metric] = values
            }
        }

        let validMetrics = metricValues.keys.sorted()
        let n = validMetrics.count
        var matrix = Array(repeating: Array(repeating: 0.0, count: n), count: n)

        for i in 0..<n {
            matrix[i][i] = 1.0
            for j in (i + 1)..<n {
                let r = Statistics.pearsonCorrelation(
                    x: metricValues[validMetrics[i]]!,
                    y: metricValues[validMetrics[j]]!
                )
                matrix[i][j] = r
                matrix[j][i] = r
            }
        }

        return CorrelationMatrix(metrics: validMetrics, values: matrix)
    }

    func topCorrelations(from matrix: CorrelationMatrix, threshold: Double = 0.5) -> [(String, String, Double)] {
        var results: [(String, String, Double)] = []
        let n = matrix.metrics.count

        for i in 0..<n {
            for j in (i + 1)..<n {
                let r = matrix.values[i][j]
                if abs(r) >= threshold {
                    results.append((matrix.metrics[i], matrix.metrics[j], r))
                }
            }
        }

        return results.sorted { abs($0.2) > abs($1.2) }
    }

    // MARK: - Anomaly Detection

    func detectAnomalies(snapshot: DailySnapshot) -> [Anomaly] {
        var anomalies: [Anomaly] = []

        for (metric, extractor) in Self.metricExtractors {
            guard let value = extractor(snapshot) else { continue }
            guard baselineEngine.hasBaseline(for: metric),
                  baselineEngine.sampleCount(for: metric) >= 14 else { continue }

            let z = baselineEngine.zScore(value: value, for: metric)
            if abs(z) > 2.0 {
                anomalies.append(Anomaly(
                    metric: metric,
                    value: value,
                    zScore: z,
                    direction: z > 0 ? .above : .below,
                    date: snapshot.date
                ))
            }
        }

        return anomalies.sorted { abs($0.zScore) > abs($1.zScore) }
    }

    // MARK: - Day-of-Week Patterns

    func weekdayAverages(snapshots: [DailySnapshot]) -> [String: [String: Double]] {
        let calendar = Calendar.current
        let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

        // Group snapshots by weekday
        var grouped: [Int: [DailySnapshot]] = [:]
        for snap in snapshots {
            let weekday = calendar.component(.weekday, from: snap.date) // 1=Sun, 7=Sat
            grouped[weekday, default: []].append(snap)
        }

        var result: [String: [String: Double]] = [:]
        for (weekday, snaps) in grouped {
            var metricAverages: [String: Double] = [:]
            for (metric, _) in Self.metricExtractors {
                let values = extractValues(for: metric, from: snaps)
                if !values.isEmpty {
                    metricAverages[metric] = Statistics.sma(values: values)
                }
            }
            result[dayNames[weekday - 1]] = metricAverages
        }

        return result
    }

    // MARK: - Personal Records

    func personalBests(snapshots: [DailySnapshot]) -> [PersonalBest] {
        var bests: [PersonalBest] = []

        for (metric, extractor) in Self.metricExtractors {
            var highValue = -Double.infinity
            var highDate = Date.distantPast
            var lowValue = Double.infinity
            var lowDate = Date.distantPast
            var hasData = false

            for snap in snapshots {
                guard let value = extractor(snap) else { continue }
                hasData = true
                if value > highValue {
                    highValue = value
                    highDate = snap.date
                }
                if value < lowValue {
                    lowValue = value
                    lowDate = snap.date
                }
            }

            if hasData {
                bests.append(PersonalBest(
                    metric: metric,
                    highValue: highValue,
                    highDate: highDate,
                    lowValue: lowValue,
                    lowDate: lowDate
                ))
            }
        }

        return bests.sorted { $0.metric < $1.metric }
    }
}
