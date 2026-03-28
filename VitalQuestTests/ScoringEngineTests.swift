import Testing
import Foundation
import SwiftData
@testable import VitalQuest

@Suite("Scoring Engine Tests")
@MainActor
struct ScoringEngineTests {
    let modelContainer: ModelContainer
    let baselineEngine: BaselineEngine
    let scoringEngine: ScoringEngine

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: DailySnapshot.self, MetricBaseline.self, Quest.self, Achievement.self, UserProfile.self,
            configurations: config
        )
        baselineEngine = BaselineEngine(modelContext: modelContainer.mainContext)
        scoringEngine = ScoringEngine(baselineEngine: baselineEngine)
    }

    // MARK: - Sleep Score Tests

    @Test("Sleep score is 0 with no data")
    func sleepScoreNoData() {
        let result = scoringEngine.computeSleepScore(sleep: nil, recentBedtimes: [])
        #expect(result.score == 0)
    }

    @Test("Perfect sleep scores high")
    func perfectSleep() {
        let sleep = SleepData(
            totalMinutes: 480, // 8 hours
            deepMinutes: 84,   // 17.5% — ideal
            remMinutes: 108,   // 22.5% — ideal
            coreMinutes: 288,
            awakeMinutes: 5,   // Very short
            bedtime: nil,
            wakeTime: nil
        )
        let result = scoringEngine.computeSleepScore(sleep: sleep, recentBedtimes: [])
        #expect(result.score >= 70) // Should be high without baselines
        #expect(result.components["duration"]! > 90) // 8h on 8h target
    }

    @Test("Short sleep scores lower")
    func shortSleep() {
        let sleep = SleepData(
            totalMinutes: 300, // 5 hours
            deepMinutes: 50,
            remMinutes: 60,
            coreMinutes: 190,
            awakeMinutes: 30,
            bedtime: nil,
            wakeTime: nil
        )
        let result = scoringEngine.computeSleepScore(sleep: sleep, recentBedtimes: [])
        #expect(result.score < 60)
    }

    @Test("Sleep duration gaussian peaks at target")
    func durationGaussian() {
        let atTarget = Statistics.gaussianScore(value: 8.0, target: 8.0, sigma: 1.5)
        let overTarget = Statistics.gaussianScore(value: 10.0, target: 8.0, sigma: 1.5)
        let underTarget = Statistics.gaussianScore(value: 6.0, target: 8.0, sigma: 1.5)
        #expect(atTarget == 100.0)
        #expect(overTarget < atTarget)
        #expect(underTarget < atTarget)
        #expect(abs(overTarget - underTarget) < 1) // Symmetric
    }

    // MARK: - Recovery Score Tests

    @Test("Recovery score with no data returns 50 (neutral)")
    func recoveryNoData() {
        let result = scoringEngine.computeRecoveryScore(
            hrvSDNN: nil, restingHeartRate: nil, sleepScore: nil,
            recentHRVValues: [], previousDayStrain: nil
        )
        #expect(result.score == 50)
    }

    @Test("Recovery score with partial data uses available components")
    func recoveryPartialData() {
        let result = scoringEngine.computeRecoveryScore(
            hrvSDNN: nil, restingHeartRate: nil, sleepScore: 85,
            recentHRVValues: [], previousDayStrain: nil
        )
        #expect(result.score > 0)
        #expect(result.components["sleep_quality"] == 85)
    }

    // MARK: - Activity Score Tests

    @Test("High activity metrics score well")
    func highActivity() {
        let result = scoringEngine.computeActivityScore(
            steps: 12000,
            activeCalories: 600,
            exerciseMinutes: 45,
            workoutTypes: ["Running", "Yoga"],
            recentActiveDays: 6,
            calorieGoal: 500,
            stepGoal: 10000
        )
        #expect(result.score >= 80)
        #expect(result.components["calories"]! == 100) // Over goal, capped
    }

    @Test("Zero activity scores low")
    func zeroActivity() {
        let result = scoringEngine.computeActivityScore(
            steps: 0, activeCalories: 0, exerciseMinutes: 0,
            workoutTypes: [], recentActiveDays: 0
        )
        #expect(result.score == 0)
    }

}

@Suite("Statistics Helpers Tests")
struct StatisticsHelpersTests {
    @Test("Percentile rank of smallest value is 0")
    func percentileSmallest() {
        let pct = Statistics.percentileRank(value: 1.0, in: [1.0, 2.0, 3.0, 4.0, 5.0])
        #expect(pct == 0)
    }

    @Test("Percentile rank of largest value is 100")
    func percentileLargest() {
        let pct = Statistics.percentileRank(value: 6.0, in: [1.0, 2.0, 3.0, 4.0, 5.0])
        #expect(pct == 100)
    }

    @Test("Median is at 50th percentile")
    func percentileMedian() {
        let pct = Statistics.percentileRank(value: 3.0, in: [1.0, 2.0, 3.0, 4.0, 5.0])
        #expect(pct == 40) // 2 values below 3 out of 5
    }

    @Test("Z-score of mean is 0")
    func zScoreOfMean() {
        let z = Statistics.zScore(value: 50, mean: 50, stdDev: 10)
        #expect(z == 0)
    }

    @Test("EWMA first update equals the value")
    func ewmaFirstValue() {
        let result = Statistics.ewmaUpdate(previous: 0, newValue: 100, alpha: 0.133)
        // alpha*100 + (1-alpha)*0 = 13.3
        #expect(abs(result - 13.3) < 0.1)
    }

    @Test("Linear slope detects upward trend")
    func linearSlopeUp() {
        let slope = Statistics.linearSlope(values: [10, 20, 30, 40])
        #expect(slope == 10)
    }

    @Test("Linear slope detects flat trend")
    func linearSlopeFlat() {
        let slope = Statistics.linearSlope(values: [50, 50, 50])
        #expect(slope == 0)
    }

    @Test("SMA computes correctly")
    func smaComputes() {
        let avg = Statistics.sma(values: [10, 20, 30])
        #expect(avg == 20)
    }

    @Test("StdDev computes correctly")
    func stdDevComputes() {
        let sd = Statistics.stdDev(values: [2, 4, 4, 4, 5, 5, 7, 9])
        #expect(abs(sd - 2.138) < 0.01) // Sample std dev
    }
}
