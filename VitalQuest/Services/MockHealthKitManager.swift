import Foundation

/// Mock data provider for SwiftUI Previews and unit tests.
/// Generates realistic health data without requiring HealthKit.
final class MockHealthKitManager: HealthKitDataProvider {
    var isAuthorized = true
    var shouldFail = false

    func requestAuthorization() async throws {
        if shouldFail { throw HealthKitError.notAvailable }
        isAuthorized = true
    }

    func fetchTodaySteps() async throws -> Int {
        Int.random(in: 6000...12000)
    }

    func fetchTodayActiveCalories() async throws -> Double {
        Double.random(in: 300...700)
    }

    func fetchTodayExerciseMinutes() async throws -> Double {
        Double.random(in: 15...60)
    }

    func fetchTodayStandMinutes() async throws -> Double {
        Double.random(in: 30...120)
    }

    func fetchRestingHeartRate(for date: Date) async throws -> Double? {
        Double.random(in: 55...72)
    }

    func fetchHRV(for date: Date) async throws -> Double? {
        Double.random(in: 25...65)
    }

    func fetchSleepAnalysis(for date: Date) async throws -> SleepData? {
        let totalSleep = Double.random(in: 360...510) // 6-8.5 hrs
        let deepRatio = Double.random(in: 0.12...0.22)
        let remRatio = Double.random(in: 0.18...0.28)
        let coreRatio = 1.0 - deepRatio - remRatio

        let calendar = Calendar.current
        let bedtime = calendar.date(bySettingHour: Int.random(in: 21...23), minute: Int.random(in: 0...59), second: 0,
                                     of: calendar.date(byAdding: .day, value: -1, to: date)!)
        let wakeTime = calendar.date(bySettingHour: Int.random(in: 5...8), minute: Int.random(in: 0...59), second: 0, of: date)

        return SleepData(
            totalMinutes: totalSleep,
            deepMinutes: totalSleep * deepRatio,
            remMinutes: totalSleep * remRatio,
            coreMinutes: totalSleep * coreRatio,
            awakeMinutes: Double.random(in: 10...40),
            bedtime: bedtime,
            wakeTime: wakeTime
        )
    }

    func fetchDailySummary(for date: Date) async throws -> DailyHealthData {
        DailyHealthData(
            date: Calendar.current.startOfDay(for: date),
            steps: Int.random(in: 4000...14000),
            activeCalories: Double.random(in: 200...800),
            exerciseMinutes: Double.random(in: 0...75),
            standMinutes: Double.random(in: 20...120),
            restingHeartRate: Double.random(in: 55...72),
            hrvSDNN: Double.random(in: 25...65),
            sleep: try await fetchSleepAnalysis(for: date),
            vo2Max: nil,
            oxygenSaturation: nil,
            respiratoryRate: nil,
            wristTemperature: nil,
            workoutCount: Int.random(in: 0...2),
            workoutTypes: Bool.random() ? ["Running"] : []
        )
    }

    func fetchHistoricalData(days: Int) async throws -> [DailyHealthData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return try await (0..<days).asyncMap { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            return try await self.fetchDailySummary(for: date)
        }.reversed()
    }
}

// Helper for async map
extension Sequence {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var results: [T] = []
        for element in self {
            results.append(try await transform(element))
        }
        return results
    }
}

// MARK: - Mock Snapshot Generator

extension DailySnapshot {
    /// Create a snapshot with realistic mock data for previews
    static func mockToday() -> DailySnapshot {
        let snap = DailySnapshot(date: Date())
        snap.steps = Int.random(in: 6000...12000)
        snap.activeCalories = Double.random(in: 300...600)
        snap.exerciseMinutes = Double.random(in: 15...60)
        snap.standMinutes = Double.random(in: 40...90)
        snap.restingHeartRate = Double.random(in: 56...68)
        snap.hrvSDNN = Double.random(in: 30...55)
        snap.sleepDurationMinutes = Double.random(in: 380...480)
        snap.deepSleepMinutes = Double.random(in: 60...100)
        snap.remSleepMinutes = Double.random(in: 70...120)
        snap.coreSleepMinutes = Double.random(in: 150...250)
        snap.recoveryScore = Double.random(in: 55...95)
        snap.sleepScore = Double.random(in: 50...90)
        snap.activityScore = Double.random(in: 40...85)
        snap.xpEarned = Int.random(in: 50...200)
        snap.checkedIn = true
        snap.dataCompleteness = 0.85
        return snap
    }

    /// Generate a week of mock snapshots
    static func mockWeek() -> [DailySnapshot] {
        let calendar = Calendar.current
        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: Date())!
            let snap = DailySnapshot(date: date)
            snap.steps = Int.random(in: 4000...14000)
            snap.activeCalories = Double.random(in: 200...700)
            snap.exerciseMinutes = Double.random(in: 0...75)
            snap.restingHeartRate = Double.random(in: 55...72)
            snap.hrvSDNN = Double.random(in: 25...60)
            snap.sleepDurationMinutes = Double.random(in: 300...510)
            snap.recoveryScore = Double.random(in: 40...95)
            snap.sleepScore = Double.random(in: 35...95)
            snap.activityScore = Double.random(in: 30...90)
            snap.dataCompleteness = Double.random(in: 0.5...1.0)
            return snap
        }.reversed()
    }
}
