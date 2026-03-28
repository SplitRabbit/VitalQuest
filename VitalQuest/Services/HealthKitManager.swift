import Foundation
import HealthKit
import Observation

/// Protocol for dependency injection and testing
protocol HealthKitDataProvider {
    func requestAuthorization() async throws
    var isAuthorized: Bool { get }
    func fetchTodaySteps() async throws -> Int
    func fetchTodayActiveCalories() async throws -> Double
    func fetchTodayExerciseMinutes() async throws -> Double
    func fetchTodayStandMinutes() async throws -> Double
    func fetchRestingHeartRate(for date: Date) async throws -> Double?
    func fetchHRV(for date: Date) async throws -> Double?
    func fetchSleepAnalysis(for date: Date) async throws -> SleepData?
    func fetchDailySummary(for date: Date) async throws -> DailyHealthData
    func fetchHistoricalData(days: Int) async throws -> [DailyHealthData]
}

struct SleepData {
    var totalMinutes: Double
    var deepMinutes: Double
    var remMinutes: Double
    var coreMinutes: Double
    var awakeMinutes: Double
    var bedtime: Date?
    var wakeTime: Date?
}

struct HRVSummary {
    var mean: Double
    var min: Double
    var max: Double
    var sampleCount: Int
}

struct HeartRateSummary {
    var mean: Double
    var min: Double
    var max: Double
}

struct WorkoutSummary {
    var count: Int
    var types: [String]
    var totalDurationMinutes: Double
    var totalCalories: Double
    var totalDistanceMeters: Double
}

struct DailyHealthData {
    var date: Date
    var steps: Int
    var activeCalories: Double
    var exerciseMinutes: Double
    var standMinutes: Double
    var restingHeartRate: Double?
    var hrvSummary: HRVSummary?
    var heartRateSummary: HeartRateSummary?
    var sleep: SleepData?
    var vo2Max: Double?
    var oxygenSaturation: Double?
    var respiratoryRate: Double?
    var wristTemperature: Double?
    var bodyMass: Double?
    var bodyFatPercentage: Double?
    var distanceWalkingRunning: Double?
    var flightsClimbed: Int?
    var mindfulMinutes: Double?
    var workouts: WorkoutSummary
}

@Observable
final class HealthKitManager: HealthKitDataProvider {
    let exposedHealthStore = HKHealthStore()
    private var healthStore: HKHealthStore { exposedHealthStore }
    private(set) var isAuthorized = false
    private(set) var authorizationError: String?

    // All HealthKit types we read
    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.appleStandTime),
            HKQuantityType(.oxygenSaturation),
            HKQuantityType(.vo2Max),
            HKQuantityType(.respiratoryRate),
            HKCategoryType(.sleepAnalysis),
            HKQuantityType(.bodyMass),
            HKQuantityType(.bodyFatPercentage),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.flightsClimbed),
            HKCategoryType(.mindfulSession),
            HKObjectType.workoutType()
        ]
        if #available(iOS 17.0, *) {
            types.insert(HKQuantityType(.appleSleepingWristTemperature))
        }
        return types
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationError = "HealthKit is not available on this device"
            throw HealthKitError.notAvailable
        }
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
        isAuthorized = true
    }

    // MARK: - Step Count

    func fetchTodaySteps() async throws -> Int {
        let steps = try await fetchStatistic(
            type: HKQuantityType(.stepCount),
            start: Calendar.current.startOfDay(for: Date()),
            end: Date(),
            options: .cumulativeSum
        )
        return Int(steps?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
    }

    // MARK: - Active Calories

    func fetchTodayActiveCalories() async throws -> Double {
        let stats = try await fetchStatistic(
            type: HKQuantityType(.activeEnergyBurned),
            start: Calendar.current.startOfDay(for: Date()),
            end: Date(),
            options: .cumulativeSum
        )
        return stats?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
    }

    // MARK: - Exercise Minutes

    func fetchTodayExerciseMinutes() async throws -> Double {
        let stats = try await fetchStatistic(
            type: HKQuantityType(.appleExerciseTime),
            start: Calendar.current.startOfDay(for: Date()),
            end: Date(),
            options: .cumulativeSum
        )
        return stats?.sumQuantity()?.doubleValue(for: .minute()) ?? 0
    }

    // MARK: - Stand Minutes

    func fetchTodayStandMinutes() async throws -> Double {
        let stats = try await fetchStatistic(
            type: HKQuantityType(.appleStandTime),
            start: Calendar.current.startOfDay(for: Date()),
            end: Date(),
            options: .cumulativeSum
        )
        return stats?.sumQuantity()?.doubleValue(for: .minute()) ?? 0
    }

    // MARK: - Resting Heart Rate

    func fetchRestingHeartRate(for date: Date) async throws -> Double? {
        let samples = try await fetchSamples(
            type: HKQuantityType(.restingHeartRate),
            start: Calendar.current.startOfDay(for: date),
            end: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: date))!,
            limit: 1
        )
        return samples.first?.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
    }

    // MARK: - HRV (all daily samples)

    func fetchHRV(for date: Date) async throws -> Double? {
        let summary = try await fetchHRVSummary(for: date)
        return summary?.mean
    }

    func fetchHRVSummary(for date: Date) async throws -> HRVSummary? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let samples = try await fetchSamples(
            type: HKQuantityType(.heartRateVariabilitySDNN),
            start: start,
            end: end,
            limit: HKObjectQueryNoLimit
        )
        guard !samples.isEmpty else { return nil }
        let values = samples.map { $0.quantity.doubleValue(for: .secondUnit(with: .milli)) }
        return HRVSummary(
            mean: values.reduce(0, +) / Double(values.count),
            min: values.min()!,
            max: values.max()!,
            sampleCount: values.count
        )
    }

    // MARK: - Heart Rate (daily summary stats)

    func fetchHeartRateSummary(for date: Date) async throws -> HeartRateSummary? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let samples = try await fetchSamples(
            type: HKQuantityType(.heartRate),
            start: start,
            end: end,
            limit: HKObjectQueryNoLimit
        )
        guard !samples.isEmpty else { return nil }
        let values = samples.map { $0.quantity.doubleValue(for: bpmUnit) }
        return HeartRateSummary(
            mean: values.reduce(0, +) / Double(values.count),
            min: values.min()!,
            max: values.max()!
        )
    }

    // MARK: - Sleep Analysis

    func fetchSleepAnalysis(for date: Date) async throws -> SleepData? {
        let calendar = Calendar.current
        // Sleep usually starts the night before — look from 6 PM yesterday to noon today
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: date),
              let sleepStart = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday),
              let sleepEnd = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)
        else { return nil }

        let predicate = HKQuery.predicateForSamples(withStart: sleepStart, end: sleepEnd, options: .strictStartDate)
        let sleepType = HKCategoryType(.sleepAnalysis)

        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: results as? [HKCategorySample] ?? [])
                }
            }
            healthStore.execute(query)
        }

        guard !samples.isEmpty else { return nil }

        var deepMinutes = 0.0
        var remMinutes = 0.0
        var coreMinutes = 0.0
        var awakeMinutes = 0.0
        var earliestSleep: Date?
        var latestWake: Date?

        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60.0
            let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)

            switch value {
            case .asleepDeep:
                deepMinutes += duration
            case .asleepREM:
                remMinutes += duration
            case .asleepCore:
                coreMinutes += duration
            case .awake:
                awakeMinutes += duration
            case .asleepUnspecified, .inBed:
                coreMinutes += duration // Conservative: count as core
            default:
                break
            }

            if value != .awake && value != .inBed {
                if sample.startDate < (earliestSleep ?? .distantFuture) {
                    earliestSleep = sample.startDate
                }
                if sample.endDate > (latestWake ?? .distantPast) {
                    latestWake = sample.endDate
                }
            }
        }

        let totalSleep = deepMinutes + remMinutes + coreMinutes
        guard totalSleep > 0 else { return nil }

        return SleepData(
            totalMinutes: totalSleep,
            deepMinutes: deepMinutes,
            remMinutes: remMinutes,
            coreMinutes: coreMinutes,
            awakeMinutes: awakeMinutes,
            bedtime: earliestSleep,
            wakeTime: latestWake
        )
    }

    // MARK: - Full Daily Summary

    func fetchDailySummary(for date: Date) async throws -> DailyHealthData {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        // Cumulative metrics
        async let stepsResult = fetchCumulativeSum(type: .stepCount, start: start, end: end, unit: .count())
        async let caloriesResult = fetchCumulativeSum(type: .activeEnergyBurned, start: start, end: end, unit: .kilocalorie())
        async let exerciseResult = fetchCumulativeSum(type: .appleExerciseTime, start: start, end: end, unit: .minute())
        async let standResult = fetchCumulativeSum(type: .appleStandTime, start: start, end: end, unit: .minute())
        async let distanceResult = fetchCumulativeSum(type: .distanceWalkingRunning, start: start, end: end, unit: .meter())
        async let flightsResult = fetchCumulativeSum(type: .flightsClimbed, start: start, end: end, unit: .count())
        async let mindfulResult = fetchMindfulMinutes(start: start, end: end)

        // Cardiac
        async let rhrResult = fetchRestingHeartRate(for: date)
        async let hrvResult = fetchHRVSummary(for: date)
        async let hrResult = fetchHeartRateSummary(for: date)

        // Sleep
        async let sleepResult = fetchSleepAnalysis(for: date)

        // Body
        async let weightResult = fetchLatestSample(type: .bodyMass, for: date, unit: .gramUnit(with: .kilo))
        async let bodyFatResult = fetchLatestSample(type: .bodyFatPercentage, for: date, unit: .percent())

        // Metrics that were previously hardcoded to nil
        async let vo2Result = fetchLatestSample(type: .vo2Max, for: date, unit: HKUnit.literUnit(with: .milli).unitDivided(by: .gramUnit(with: .kilo).unitMultiplied(by: .minute())))
        async let spo2Result = fetchLatestSample(type: .oxygenSaturation, for: date, unit: .percent())
        async let respResult = fetchLatestSample(type: .respiratoryRate, for: date, unit: HKUnit.count().unitDivided(by: .minute()))
        async let tempResult = fetchWristTemperature(for: date)

        // Workouts
        async let workoutsResult = fetchWorkouts(for: date)

        let (steps, calories, exercise, stand, distance, flights, mindful,
             rhr, hrvSummary, hrSummary, sleep, weight, bodyFat,
             vo2, spo2, resp, temp, workouts) = try await (
            stepsResult, caloriesResult, exerciseResult, standResult,
            distanceResult, flightsResult, mindfulResult,
            rhrResult, hrvResult, hrResult, sleepResult,
            weightResult, bodyFatResult,
            vo2Result, spo2Result, respResult, tempResult, workoutsResult
        )

        // Build workout summary
        var totalWorkoutDuration = 0.0
        var totalWorkoutCalories = 0.0
        var totalWorkoutDistance = 0.0
        for w in workouts {
            totalWorkoutDuration += w.duration / 60.0
            totalWorkoutCalories += w.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
            totalWorkoutDistance += w.totalDistance?.doubleValue(for: .meter()) ?? 0
        }

        return DailyHealthData(
            date: start,
            steps: Int(steps),
            activeCalories: calories,
            exerciseMinutes: exercise,
            standMinutes: stand,
            restingHeartRate: rhr,
            hrvSummary: hrvSummary,
            heartRateSummary: hrSummary,
            sleep: sleep,
            vo2Max: vo2,
            oxygenSaturation: spo2,
            respiratoryRate: resp,
            wristTemperature: temp,
            bodyMass: weight,
            bodyFatPercentage: bodyFat,
            distanceWalkingRunning: distance > 0 ? distance : nil,
            flightsClimbed: flights > 0 ? Int(flights) : nil,
            mindfulMinutes: mindful > 0 ? mindful : nil,
            workouts: WorkoutSummary(
                count: workouts.count,
                types: workouts.map { $0.workoutActivityType.name },
                totalDurationMinutes: totalWorkoutDuration,
                totalCalories: totalWorkoutCalories,
                totalDistanceMeters: totalWorkoutDistance
            )
        )
    }

    // MARK: - Wrist Temperature

    private func fetchWristTemperature(for date: Date) async -> Double? {
        guard #available(iOS 17.0, *) else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        let samples = try? await fetchSamples(
            type: HKQuantityType(.appleSleepingWristTemperature),
            start: start,
            end: end,
            limit: 1
        )
        return samples?.first?.quantity.doubleValue(for: .degreeCelsius())
    }

    // MARK: - Historical Import

    func fetchHistoricalData(days: Int) async throws -> [DailyHealthData] {
        var results: [DailyHealthData] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let summary = try await fetchDailySummary(for: date)
            results.append(summary)
        }

        return results.reversed() // Chronological order
    }

    // MARK: - Private Helpers

    private func fetchStatistic(
        type: HKQuantityType,
        start: Date,
        end: Date,
        options: HKStatisticsOptions
    ) async throws -> HKStatistics? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: statistics)
                }
            }
            healthStore.execute(query)
        }
    }

    private func fetchSamples(
        type: HKQuantityType,
        start: Date,
        end: Date,
        limit: Int
    ) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: results as? [HKQuantitySample] ?? [])
                }
            }
            healthStore.execute(query)
        }
    }

    private func fetchCumulativeSum(
        type: HKQuantityTypeIdentifier,
        start: Date,
        end: Date,
        unit: HKUnit
    ) async throws -> Double {
        let stats = try await fetchStatistic(
            type: HKQuantityType(type),
            start: start,
            end: end,
            options: .cumulativeSum
        )
        return stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
    }

    private func fetchMindfulMinutes(start: Date, end: Date) async throws -> Double {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKCategoryType(.mindfulSession),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: results as? [HKCategorySample] ?? [])
                }
            }
            healthStore.execute(query)
        }
        return samples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 60.0 }
    }

    private func fetchLatestSample(
        type: HKQuantityTypeIdentifier,
        for date: Date,
        unit: HKUnit
    ) async throws -> Double? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        let samples = try await fetchSamples(
            type: HKQuantityType(type),
            start: start,
            end: end,
            limit: 1
        )
        return samples.first?.quantity.doubleValue(for: unit)
    }

    private func fetchWorkouts(for date: Date) async throws -> [HKWorkout] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: results as? [HKWorkout] ?? [])
                }
            }
            healthStore.execute(query)
        }
    }
}

// MARK: - Error Types

enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationDenied
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable: return "HealthKit is not available on this device"
        case .authorizationDenied: return "Health data access was denied"
        case .queryFailed(let msg): return "Health query failed: \(msg)"
        }
    }
}

// MARK: - Workout Type Name Helper

extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .walking: return "Walking"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Strength Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .hiking: return "Hiking"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .dance: return "Dance"
        case .pilates: return "Pilates"
        case .crossTraining: return "Cross Training"
        default: return "Other"
        }
    }
}
