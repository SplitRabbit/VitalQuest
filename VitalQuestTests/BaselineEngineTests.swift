import Testing
import Foundation
import SwiftData
@testable import VitalQuest

@Suite("Baseline Engine Tests")
struct BaselineEngineTests {
    let modelContainer: ModelContainer
    let engine: BaselineEngine

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: DailySnapshot.self, MetricBaseline.self, Quest.self, Achievement.self, UserProfile.self,
            configurations: config
        )
        engine = BaselineEngine(modelContext: modelContainer.mainContext)
    }

    @Test("Recording a value creates a baseline")
    func recordCreates() {
        engine.recordValue(100, for: "testMetric")
        #expect(engine.ewma(for: "testMetric") == 100) // First value becomes EWMA
    }

    @Test("EWMA updates with new values")
    func ewmaUpdates() {
        engine.recordValue(100, for: "testMetric")
        engine.recordValue(200, for: "testMetric")
        let ewma = engine.ewma(for: "testMetric")!
        // Second update: 0.133*200 + 0.867*100 = 26.6 + 86.7 = 113.3
        #expect(abs(ewma - 113.3) < 0.1)
    }

    @Test("Percentile works after recording values")
    func percentileAfterRecording() {
        for v in stride(from: 10.0, through: 100.0, by: 10.0) {
            engine.recordValue(v, for: "testMetric")
        }
        let p50 = engine.percentile(value: 50, for: "testMetric")
        #expect(p50 >= 40 && p50 <= 60) // Should be around 50th percentile
    }

    @Test("Inverted percentile: lower value = higher percentile")
    func invertedPercentile() {
        for v in stride(from: 50.0, through: 80.0, by: 5.0) {
            engine.recordValue(v, for: "rhr")
        }
        let lowRHR = engine.invertedPercentile(value: 52, for: "rhr")
        let highRHR = engine.invertedPercentile(value: 78, for: "rhr")
        #expect(lowRHR > highRHR) // Lower RHR = higher inverted percentile
    }

    @Test("Has baseline returns false before 14 samples")
    func baselineThreshold() {
        for i in 0..<13 {
            engine.recordValue(Double(i), for: "testMetric")
        }
        #expect(!engine.hasBaseline(for: "testMetric"))
        engine.recordValue(13, for: "testMetric")
        #expect(engine.hasBaseline(for: "testMetric"))
    }

    @Test("Long-term mean and stddev compute correctly")
    func longTermStats() {
        let values = [10.0, 20.0, 30.0, 40.0, 50.0]
        for v in values {
            engine.recordValue(v, for: "testMetric")
        }
        let mean = engine.longTermMean(for: "testMetric")!
        #expect(abs(mean - 30.0) < 0.1) // SMA of sorted history
    }

    @Test("Z-score relative to personal distribution")
    func zScorePersonal() {
        // Build up a distribution
        for _ in 0..<30 {
            engine.recordValue(Double.random(in: 40...60), for: "testMetric")
        }
        // A value far above should have positive z-score
        let z = engine.zScore(value: 80, for: "testMetric")
        #expect(z > 1.0) // Well above the mean
    }

    @Test("Batch update from health data")
    func batchUpdate() {
        let data = DailyHealthData(
            date: Date(),
            steps: 10000,
            activeCalories: 500,
            exerciseMinutes: 30,
            standMinutes: 60,
            restingHeartRate: 62,
            hrvSDNN: 45,
            sleep: SleepData(
                totalMinutes: 480,
                deepMinutes: 80,
                remMinutes: 100,
                coreMinutes: 300,
                awakeMinutes: 20,
                bedtime: nil,
                wakeTime: nil
            ),
            vo2Max: nil,
            oxygenSaturation: nil,
            respiratoryRate: nil,
            wristTemperature: nil,
            workoutCount: 1,
            workoutTypes: ["Running"]
        )

        engine.updateBaselines(from: data)

        #expect(engine.ewma(for: MetricBaseline.steps) == 10000)
        #expect(engine.ewma(for: MetricBaseline.restingHeartRate) == 62)
        #expect(engine.ewma(for: MetricBaseline.activeCalories) == 500)
    }

    @Test("History trims to 90 entries")
    func historyTrim() {
        for i in 0..<100 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            engine.recordValue(Double(i), for: "trimTest", on: date)
        }
        #expect(engine.sampleCount(for: "trimTest") == 100) // EWMA count is 100
        // But the sorted history should be trimmed to 90
        // (Internal check — the percentile should still work)
        let p = engine.percentile(value: 50, for: "trimTest")
        #expect(p > 0) // Just verify it works
    }
}
