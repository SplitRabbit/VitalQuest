import Foundation
import HealthKit

/// Fetches raw HealthKit samples and ingests them into the RawSampleStore.
/// Runs at utility priority alongside the main UI refresh — does not block scoring.
@Observable
final class RawSampleCollector {

    private let healthStore: HKHealthStore
    private let store: RawSampleStore

    private(set) var isCollecting = false
    private(set) var lastCollectionDate: Date?
    private(set) var lastCollectionCounts: [String: Int] = [:]

    init(healthStore: HKHealthStore, store: RawSampleStore) {
        self.healthStore = healthStore
        self.store = store
    }

    // MARK: - Metric Types

    static let quantityMetrics: [(type: HKQuantityTypeIdentifier, metricType: String, unit: HKUnit, unitLabel: String)] = [
        (.heartRate, "heart_rate", HKUnit.count().unitDivided(by: .minute()), "bpm"),
        (.heartRateVariabilitySDNN, "hrv", .secondUnit(with: .milli), "ms"),
        (.restingHeartRate, "resting_heart_rate", HKUnit.count().unitDivided(by: .minute()), "bpm"),
        (.oxygenSaturation, "spo2", .percent(), "percent"),
        (.respiratoryRate, "respiratory_rate", HKUnit.count().unitDivided(by: .minute()), "brpm"),
        (.bodyMass, "body_mass", .gramUnit(with: .kilo), "kg"),
        (.stepCount, "steps", .count(), "count"),
        (.activeEnergyBurned, "active_calories", .kilocalorie(), "kcal"),
        (.distanceWalkingRunning, "distance", .meter(), "m"),
    ]

    // MARK: - Collect for a Single Day

    /// Fetch all raw samples for a given day and ingest into both databases.
    func collectRawSamples(for date: Date) async {
        guard !isCollecting else { return }
        isCollecting = true
        defer {
            isCollecting = false
            lastCollectionDate = date
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        var counts: [String: Int] = [:]

        // Quantity samples (HR, HRV, RHR, SpO2, etc.)
        for metric in Self.quantityMetrics {
            let records = await fetchQuantityRecords(
                type: HKQuantityType(metric.type),
                metricType: metric.metricType,
                unit: metric.unit,
                unitLabel: metric.unitLabel,
                start: start,
                end: end
            )
            store.ingest(records)
            counts[metric.metricType] = records.count
        }

        // Sleep stages
        let sleepRecords = await fetchSleepRecords(start: start, end: end)
        store.ingest(sleepRecords)
        counts["sleep_stage"] = sleepRecords.count

        // Workouts
        let workoutRecords = await fetchWorkoutRecords(start: start, end: end)
        store.ingest(workoutRecords)
        counts["workout"] = workoutRecords.count

        // Wrist temperature (iOS 17+)
        if #available(iOS 17.0, *) {
            let tempRecords = await fetchQuantityRecords(
                type: HKQuantityType(.appleSleepingWristTemperature),
                metricType: "wrist_temperature",
                unit: .degreeCelsius(),
                unitLabel: "celsius",
                start: start,
                end: end
            )
            store.ingest(tempRecords)
            counts["wrist_temperature"] = tempRecords.count
        }

        lastCollectionCounts = counts

        // Prune transactional DB after collection
        store.pruneTransactional()
        store.enforceWarehouseSizeLimit()
    }

    // MARK: - Backfill Historical Data

    /// Backfill raw samples for the specified number of past days.
    /// Calls progress callback with (completed, total) for UI updates.
    func backfill(days: Int, progress: ((Int, Int) -> Void)? = nil) async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for offset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            await collectRawSamples(for: date)
            progress?(offset + 1, days)
        }
    }

    // MARK: - HealthKit Fetch Helpers

    private func fetchQuantityRecords(
        type: HKQuantityType,
        metricType: String,
        unit: HKUnit,
        unitLabel: String,
        start: Date,
        end: Date
    ) async -> [RawSampleStore.SampleRecord] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let samples: [HKQuantitySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, _ in
                continuation.resume(returning: results as? [HKQuantitySample] ?? [])
            }
            healthStore.execute(query)
        }

        return samples.map { sample in
            RawSampleStore.SampleRecord(
                id: sample.uuid.uuidString,
                metricType: metricType,
                startDate: sample.startDate,
                endDate: sample.endDate,
                value: sample.quantity.doubleValue(for: unit),
                valueUnit: unitLabel,
                sourceName: sample.sourceRevision.source.name,
                sourceBundle: sample.sourceRevision.source.bundleIdentifier,
                deviceName: sample.device?.name,
                deviceModel: sample.device?.model,
                metadataJSON: nil
            )
        }
    }

    private func fetchSleepRecords(start: Date, end: Date) async -> [RawSampleStore.SampleRecord] {
        // Sleep window: 6 PM previous day to noon target day
        let calendar = Calendar.current
        guard let sleepStart = calendar.date(bySettingHour: 18, minute: 0, second: 0,
                                              of: calendar.date(byAdding: .day, value: -1, to: start) ?? start),
              let sleepEnd = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: end)
        else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: sleepStart, end: sleepEnd, options: .strictStartDate)

        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKCategoryType(.sleepAnalysis),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, _ in
                continuation.resume(returning: results as? [HKCategorySample] ?? [])
            }
            healthStore.execute(query)
        }

        return samples.map { sample in
            let stageName: String
            switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
            case .asleepDeep: stageName = "deep"
            case .asleepREM: stageName = "rem"
            case .asleepCore: stageName = "core"
            case .awake: stageName = "awake"
            case .inBed: stageName = "in_bed"
            case .asleepUnspecified: stageName = "unspecified"
            default: stageName = "unknown"
            }

            return RawSampleStore.SampleRecord(
                id: sample.uuid.uuidString,
                metricType: "sleep_stage",
                startDate: sample.startDate,
                endDate: sample.endDate,
                value: Double(sample.value),
                valueUnit: "category",
                sourceName: sample.sourceRevision.source.name,
                sourceBundle: sample.sourceRevision.source.bundleIdentifier,
                deviceName: sample.device?.name,
                deviceModel: sample.device?.model,
                metadataJSON: "{\"stage\":\"\(stageName)\"}"
            )
        }
    }

    private func fetchWorkoutRecords(start: Date, end: Date) async -> [RawSampleStore.SampleRecord] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let samples: [HKWorkout] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, _ in
                continuation.resume(returning: results as? [HKWorkout] ?? [])
            }
            healthStore.execute(query)
        }

        return samples.map { workout in
            let durationMin = workout.duration / 60.0
            let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
            let distance = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
            let activityType = workout.workoutActivityType.name

            let metadata = """
            {"activity_type":"\(activityType)","duration_min":\(String(format: "%.1f", durationMin)),\
            "calories":\(String(format: "%.1f", calories)),"distance_m":\(String(format: "%.1f", distance))}
            """

            return RawSampleStore.SampleRecord(
                id: workout.uuid.uuidString,
                metricType: "workout",
                startDate: workout.startDate,
                endDate: workout.endDate,
                value: Double(workout.workoutActivityType.rawValue),
                valueUnit: "activity_type",
                sourceName: workout.sourceRevision.source.name,
                sourceBundle: workout.sourceRevision.source.bundleIdentifier,
                deviceName: workout.device?.name,
                deviceModel: workout.device?.model,
                metadataJSON: metadata
            )
        }
    }
}
