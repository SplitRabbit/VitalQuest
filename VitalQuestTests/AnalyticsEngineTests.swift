import Testing
import Foundation
import SwiftData
@testable import VitalQuest

@Suite("Analytics Engine Tests")
@MainActor
struct AnalyticsEngineTests {
    let modelContainer: ModelContainer
    let baselineEngine: BaselineEngine
    let analyticsEngine: AnalyticsEngine

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: DailySnapshot.self, MetricBaseline.self, Quest.self,
            Achievement.self, UserProfile.self, JournalEntry.self, CustomLog.self, FeedItem.self, Activity.self,
            configurations: config
        )
        baselineEngine = BaselineEngine(modelContext: modelContainer.mainContext)
        analyticsEngine = AnalyticsEngine(modelContext: modelContainer.mainContext, baselineEngine: baselineEngine)
    }

    /// Build an array of snapshots with a linear trend in steps.
    private func buildSnapshots(days: Int, stepBase: Int = 8000, stepSlope: Int = 100) -> [DailySnapshot] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<days).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            let snap = DailySnapshot(date: date)
            snap.steps = stepBase + (days - 1 - offset) * stepSlope // Increasing over time
            snap.activeCalories = Double(300 + (days - 1 - offset) * 10)
            snap.exerciseMinutes = 30
            snap.standMinutes = 60
            snap.sleepDurationMinutes = 450
            snap.deepSleepMinutes = 80
            snap.remSleepMinutes = 100
            snap.coreSleepMinutes = 270
            snap.awakeMinutes = 15
            snap.recoveryScore = 70
            snap.sleepScore = 75
            snap.activityScore = 65
            snap.dataCompleteness = 0.9
            modelContainer.mainContext.insert(snap)
            return snap
        }
    }

    // MARK: - Trend Detection

    @Test("Detects improving trend in steps")
    func trendDetectionImproving() {
        let snapshots = buildSnapshots(days: 14, stepBase: 5000, stepSlope: 500)
        let trends = analyticsEngine.computeTrends(snapshots: snapshots, windows: [7])
        let stepTrend = trends.first { $0.metric == "steps" && $0.window == 7 }
        #expect(stepTrend != nil)
        #expect(stepTrend?.direction == .improving)
        #expect(stepTrend?.slope ?? 0 > 0)
    }

    @Test("Stable values produce stable trend")
    func trendDetectionStable() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let snapshots: [DailySnapshot] = (0..<14).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            let snap = DailySnapshot(date: date)
            snap.steps = 10000 // Constant
            snap.activeCalories = 400
            snap.exerciseMinutes = 30
            snap.standMinutes = 60
            snap.dataCompleteness = 1.0
            modelContainer.mainContext.insert(snap)
            return snap
        }

        let trends = analyticsEngine.computeTrends(snapshots: snapshots, windows: [7])
        let stepTrend = trends.first { $0.metric == "steps" }
        // Constant values → stddev = 0 → no trend produced (guard sd > 0)
        #expect(stepTrend == nil)
    }

    @Test("Needs at least 7 data points")
    func trendMinimumData() {
        let snapshots = buildSnapshots(days: 5)
        let trends = analyticsEngine.computeTrends(snapshots: snapshots, windows: [7])
        // Only 5 values, window requires 7
        let stepTrend7 = trends.first { $0.metric == "steps" && $0.window == 7 }
        #expect(stepTrend7 == nil)
    }

    // MARK: - Correlations

    @Test("Correlation matrix is symmetric")
    func correlationSymmetric() {
        let snapshots = buildSnapshots(days: 15)
        let matrix = analyticsEngine.computeCorrelations(snapshots: snapshots)
        let n = matrix.metrics.count
        for i in 0..<n {
            for j in 0..<n {
                #expect(abs(matrix.values[i][j] - matrix.values[j][i]) < 0.001)
            }
        }
    }

    @Test("Diagonal of correlation matrix is 1.0")
    func correlationDiagonal() {
        let snapshots = buildSnapshots(days: 15)
        let matrix = analyticsEngine.computeCorrelations(snapshots: snapshots)
        for i in 0..<matrix.metrics.count {
            #expect(matrix.values[i][i] == 1.0)
        }
    }

    @Test("Top correlations filters by threshold")
    func topCorrelationsThreshold() {
        let snapshots = buildSnapshots(days: 15)
        let matrix = analyticsEngine.computeCorrelations(snapshots: snapshots)
        let top = analyticsEngine.topCorrelations(from: matrix, threshold: 0.9)
        for (_, _, r) in top {
            #expect(abs(r) >= 0.9)
        }
    }

    @Test("Top correlations sorted by absolute value")
    func topCorrelationsSorted() {
        let snapshots = buildSnapshots(days: 15)
        let matrix = analyticsEngine.computeCorrelations(snapshots: snapshots)
        let top = analyticsEngine.topCorrelations(from: matrix, threshold: 0.3)
        for i in 0..<max(0, top.count - 1) {
            #expect(abs(top[i].2) >= abs(top[i + 1].2))
        }
    }

    // MARK: - Anomaly Detection

    @Test("Anomaly detected for extreme value")
    func anomalyDetection() {
        // Build baseline with 20+ samples with some variation (needed for nonzero stddev)
        for i in 0..<20 {
            baselineEngine.recordValue(Double(9500 + i * 50), for: "steps") // 9500 to 10450
        }

        let snapshot = DailySnapshot(date: Date())
        snapshot.steps = 50000 // Way above normal (~10000 mean)
        modelContainer.mainContext.insert(snapshot)

        let anomalies = analyticsEngine.detectAnomalies(snapshot: snapshot)
        let stepAnomaly = anomalies.first { $0.metric == "steps" }
        #expect(stepAnomaly != nil)
        #expect(stepAnomaly?.direction == .above)
        #expect(abs(stepAnomaly?.zScore ?? 0) > 2.0)
    }

    @Test("No anomaly for normal value")
    func noAnomalyNormal() {
        for i in 0..<20 {
            baselineEngine.recordValue(Double(9500 + i * 50), for: "steps")
        }

        let snapshot = DailySnapshot(date: Date())
        snapshot.steps = 10000 // Normal range
        modelContainer.mainContext.insert(snapshot)

        let anomalies = analyticsEngine.detectAnomalies(snapshot: snapshot)
        let stepAnomaly = anomalies.first { $0.metric == "steps" }
        #expect(stepAnomaly == nil)
    }

    @Test("Anomaly requires 14+ baseline samples")
    func anomalyRequiresBaseline() {
        for _ in 0..<10 {
            baselineEngine.recordValue(10000, for: "steps")
        }

        let snapshot = DailySnapshot(date: Date())
        snapshot.steps = 50000
        modelContainer.mainContext.insert(snapshot)

        let anomalies = analyticsEngine.detectAnomalies(snapshot: snapshot)
        let stepAnomaly = anomalies.first { $0.metric == "steps" }
        #expect(stepAnomaly == nil) // Not enough baseline data
    }

    // MARK: - Weekday Averages

    @Test("Weekday averages groups by day of week")
    func weekdayAveragesGrouping() {
        let snapshots = buildSnapshots(days: 14)
        let averages = analyticsEngine.weekdayAverages(snapshots: snapshots)
        // 14 days covers all 7 weekdays
        #expect(averages.count == 7)
    }

    @Test("Weekday averages contain step data")
    func weekdayAveragesContainSteps() {
        let snapshots = buildSnapshots(days: 14)
        let averages = analyticsEngine.weekdayAverages(snapshots: snapshots)
        for (_, metrics) in averages {
            #expect(metrics["steps"] != nil)
            #expect(metrics["steps"]! > 0)
        }
    }

    // MARK: - Personal Bests

    @Test("Personal bests finds highest and lowest values")
    func personalBestsFindsExtremes() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for offset in 0..<10 {
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            let snap = DailySnapshot(date: date)
            snap.steps = 5000 + offset * 2000 // 5000 to 23000
            snap.activeCalories = 200 + Double(offset) * 50
            modelContainer.mainContext.insert(snap)
        }

        let descriptor = FetchDescriptor<DailySnapshot>()
        let snapshots = (try? modelContainer.mainContext.fetch(descriptor)) ?? []
        let bests = analyticsEngine.personalBests(snapshots: snapshots)

        let stepBest = bests.first { $0.metric == "steps" }
        #expect(stepBest != nil)
        #expect(stepBest?.highValue == 23000)
        #expect(stepBest?.lowValue == 5000)
    }

    @Test("Personal bests returns sorted by metric name")
    func personalBestsSorted() {
        let snapshots = buildSnapshots(days: 10)
        let bests = analyticsEngine.personalBests(snapshots: snapshots)
        for i in 0..<max(0, bests.count - 1) {
            #expect(bests[i].metric <= bests[i + 1].metric)
        }
    }
}

// MARK: - Additional Statistics Tests

@Suite("Statistics Helpers Extended Tests")
struct StatisticsHelpersExtendedTests {
    @Test("Pearson correlation of identical arrays is 1.0")
    func pearsonIdentical() {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let r = Statistics.pearsonCorrelation(x: values, y: values)
        #expect(abs(r - 1.0) < 0.001)
    }

    @Test("Pearson correlation of inversely related arrays is -1.0")
    func pearsonInverse() {
        let x = [1.0, 2.0, 3.0, 4.0, 5.0]
        let y = [5.0, 4.0, 3.0, 2.0, 1.0]
        let r = Statistics.pearsonCorrelation(x: x, y: y)
        #expect(abs(r - (-1.0)) < 0.001)
    }

    @Test("Pearson correlation of weakly correlated data has small magnitude")
    func pearsonWeakCorrelation() {
        let x = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
        let y = [2.0, 8.0, 1.0, 7.0, 3.0, 6.0, 4.0, 5.0] // Scrambled
        let r = Statistics.pearsonCorrelation(x: x, y: y)
        #expect(abs(r) < 0.7)
    }

    @Test("Pearson correlation returns 0 for single element")
    func pearsonShort() {
        let r = Statistics.pearsonCorrelation(x: [1.0], y: [2.0])
        #expect(r == 0)
    }

    @Test("Pearson correlation truncates to shorter array length")
    func pearsonMismatch() {
        // Implementation uses min(x.count, y.count), so [1,2] vs [1,2,3] computes on [1,2] vs [1,2]
        let r = Statistics.pearsonCorrelation(x: [1.0, 2.0], y: [1.0, 2.0, 3.0])
        #expect(abs(r - 1.0) < 0.001) // Perfect correlation on the overlapping portion
    }

    @Test("Moving average with window 1 returns original")
    func movingAverageWindow1() {
        let values = [10.0, 20.0, 30.0]
        let ma = Statistics.movingAverage(values: values, window: 1)
        #expect(ma == values)
    }

    @Test("Moving average smooths values")
    func movingAverageSmooths() {
        let values = [10.0, 20.0, 30.0, 40.0, 50.0]
        let ma = Statistics.movingAverage(values: values, window: 3)
        // First 2 values don't have full window
        #expect(ma.count == values.count)
        // Third value should be average of [10, 20, 30] = 20
        #expect(abs(ma[2] - 20.0) < 0.001)
        // Fourth value should be average of [20, 30, 40] = 30
        #expect(abs(ma[3] - 30.0) < 0.001)
    }

    @Test("Moving average returns empty for empty input")
    func movingAverageEmpty() {
        let ma = Statistics.movingAverage(values: [], window: 3)
        #expect(ma.isEmpty)
    }

    @Test("Autocorrelation of constant series is NaN or 0")
    func autocorrelationConstant() {
        let values = [5.0, 5.0, 5.0, 5.0, 5.0]
        let ac = Statistics.autocorrelation(values: values, lag: 1)
        // Constant → stddev = 0 → division by zero → NaN or 0
        #expect(ac.isNaN || ac == 0)
    }

    @Test("Autocorrelation lag 0 returns 0 (guard requires lag > 0)")
    func autocorrelationLag0() {
        let values = [1.0, 3.0, 5.0, 7.0, 9.0]
        let ac = Statistics.autocorrelation(values: values, lag: 0)
        #expect(ac == 0) // Implementation guards lag > 0
    }

    @Test("Autocorrelation lag 1 of linear sequence is high")
    func autocorrelationLag1Linear() {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
        let ac = Statistics.autocorrelation(values: values, lag: 1)
        #expect(ac > 0.9) // Linear series is highly autocorrelated
    }

    @Test("Linear slope of downward trend is negative")
    func linearSlopeDown() {
        let slope = Statistics.linearSlope(values: [40.0, 30.0, 20.0, 10.0])
        #expect(slope == -10)
    }

    @Test("Gaussian score at 2 sigma below target")
    func gaussianScoreTwoSigma() {
        let score = Statistics.gaussianScore(value: 4.0, target: 8.0, sigma: 2.0)
        // At 2σ away: exp(-0.5 * 4) * 100 ≈ 13.5
        #expect(score > 10 && score < 20)
    }

    @Test("Clamp01Score keeps value in 0-100 range")
    func clampRange() {
        #expect(Statistics.clamp01Score(150) == 100)
        #expect(Statistics.clamp01Score(-10) == 0)
        #expect(Statistics.clamp01Score(50) == 50)
    }
}
