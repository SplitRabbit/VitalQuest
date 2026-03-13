import Foundation
import SwiftData

// MARK: - DataExportable Protocol

protocol DataExportable {
    static var csvHeader: String { get }
    var csvRow: String { get }
}

// MARK: - DataExportService

@Observable
final class DataExportService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Export Snapshots as CSV

    func exportSnapshots(from startDate: Date? = nil, to endDate: Date? = nil) throws -> URL {
        var descriptor = FetchDescriptor<DailySnapshot>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )

        if let start = startDate, let end = endDate {
            descriptor.predicate = #Predicate<DailySnapshot> { snap in
                snap.date >= start && snap.date <= end
            }
        } else if let start = startDate {
            descriptor.predicate = #Predicate<DailySnapshot> { snap in
                snap.date >= start
            }
        } else if let end = endDate {
            descriptor.predicate = #Predicate<DailySnapshot> { snap in
                snap.date <= end
            }
        }

        let snapshots = try modelContext.fetch(descriptor)
        var csv = DailySnapshot.csvHeader + "\n"
        for snapshot in snapshots {
            csv += snapshot.csvRow + "\n"
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshots.csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Export Baselines as JSON

    func exportBaselines() throws -> URL {
        let descriptor = FetchDescriptor<MetricBaseline>(
            sortBy: [SortDescriptor(\.metricName)]
        )
        let baselines = try modelContext.fetch(descriptor)

        var export: [[String: Any]] = []
        for baseline in baselines {
            var entry: [String: Any] = [
                "metricName": baseline.metricName,
                "ewmaValue": baseline.ewmaValue,
                "ewmaVariance": baseline.ewmaVariance,
                "ewmaAlpha": baseline.ewmaAlpha,
                "ewmaSampleCount": baseline.ewmaSampleCount,
                "longTermMean": baseline.longTermMean,
                "longTermStdDev": baseline.longTermStdDev,
                "longTermSampleCount": baseline.longTermSampleCount,
                "sortedHistory": baseline.sortedHistory,
                "lastUpdated": Self.iso8601Formatter.string(from: baseline.lastUpdated)
            ]
            entry["historyDates"] = baseline.historyDates.map {
                Self.iso8601Formatter.string(from: $0)
            }
            export.append(entry)
        }

        let data = try JSONSerialization.data(withJSONObject: export, options: [.prettyPrinted, .sortedKeys])
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("baselines.json")
        try data.write(to: url)
        return url
    }

    // MARK: - Export Profile as JSON

    func exportProfile() throws -> URL {
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = try modelContext.fetch(descriptor).first else {
            throw ExportError.noProfile
        }

        let export: [String: Any] = [
            "totalXP": profile.totalXP,
            "level": profile.level,
            "currentStreak": profile.currentStreak,
            "longestStreak": profile.longestStreak,
            "streakFreezes": profile.streakFreezes,
            "totalStreakFreezesUsed": profile.totalStreakFreezesUsed,
            "totalQuestsCompleted": profile.totalQuestsCompleted,
            "totalWorkouts": profile.totalWorkouts,
            "totalDaysTracked": profile.totalDaysTracked,
            "joinDate": Self.iso8601Formatter.string(from: profile.joinDate),
            "stepGoal": profile.stepGoal,
            "calorieGoal": profile.calorieGoal,
            "sleepGoalHours": profile.sleepGoalHours,
            "exerciseGoalMinutes": profile.exerciseGoalMinutes,
            "enabledOptionalMetrics": profile.enabledOptionalMetrics
        ]

        let data = try JSONSerialization.data(withJSONObject: export, options: [.prettyPrinted, .sortedKeys])
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("profile.json")
        try data.write(to: url)
        return url
    }

    // MARK: - Export Bundle

    func exportBundle() throws -> URL {
        let bundleDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("VitalQuestExport_\(Self.fileDateFormatter.string(from: Date()))")
        try FileManager.default.createDirectory(at: bundleDir, withIntermediateDirectories: true)

        // Export all files into bundle directory
        let snapshotsURL = try exportSnapshots()
        let baselinesURL = try exportBaselines()
        let profileURL = try exportProfile()

        let fm = FileManager.default
        let destSnapshots = bundleDir.appendingPathComponent("snapshots.csv")
        let destBaselines = bundleDir.appendingPathComponent("baselines.json")
        let destProfile = bundleDir.appendingPathComponent("profile.json")

        // Remove existing if re-exporting
        try? fm.removeItem(at: destSnapshots)
        try? fm.removeItem(at: destBaselines)
        try? fm.removeItem(at: destProfile)

        try fm.moveItem(at: snapshotsURL, to: destSnapshots)
        try fm.moveItem(at: baselinesURL, to: destBaselines)
        try fm.moveItem(at: profileURL, to: destProfile)

        // Write metadata
        let snapshotCount = try modelContext.fetchCount(FetchDescriptor<DailySnapshot>())
        let allSnapshots = try modelContext.fetch(
            FetchDescriptor<DailySnapshot>(sortBy: [SortDescriptor(\.date, order: .forward)])
        )
        let dateRange: [String: String] = {
            guard let first = allSnapshots.first, let last = allSnapshots.last else { return [:] }
            return [
                "start": Self.iso8601Formatter.string(from: first.date),
                "end": Self.iso8601Formatter.string(from: last.date)
            ]
        }()

        let metadata: [String: Any] = [
            "exportDate": Self.iso8601Formatter.string(from: Date()),
            "dayCount": snapshotCount,
            "dateRange": dateRange,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]
        let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
        try metadataData.write(to: bundleDir.appendingPathComponent("metadata.json"))

        return bundleDir
    }

    // MARK: - Share Bundle

    func shareBundle() throws -> URL {
        try exportBundle()
    }

    // MARK: - Helpers

    enum ExportError: LocalizedError {
        case noProfile

        var errorDescription: String? {
            switch self {
            case .noProfile: return "No user profile found to export."
            }
        }
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let fileDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmmss"
        return f
    }()
}

// MARK: - CSV Helpers

private func csvEscape(_ value: String) -> String {
    if value.contains(",") || value.contains("\"") || value.contains("\n") {
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    return value
}

private func optionalString(_ value: Double?) -> String {
    guard let v = value else { return "" }
    return String(format: "%.2f", v)
}

private func optionalIntString(_ value: Int?) -> String {
    guard let v = value else { return "" }
    return String(v)
}

private func optionalDateString(_ value: Date?) -> String {
    guard let v = value else { return "" }
    return ISO8601DateFormatter().string(from: v)
}

private func componentsString(_ dict: [String: Double], keys: [String]) -> [String] {
    keys.map { key in optionalString(dict[key]) }
}

// MARK: - DailySnapshot + DataExportable

extension DailySnapshot: DataExportable {

    static let recoveryComponentKeys = [
        "hrv_percentile", "rhr_percentile", "sleep_quality", "hrv_trend", "strain_impact"
    ]
    static let sleepComponentKeys = [
        "duration", "deep_sleep", "rem_sleep", "consistency", "nighttime_hrv", "sleep_latency"
    ]
    static let activityComponentKeys = [
        "calories", "steps", "exercise", "variety", "consistency"
    ]

    static var csvHeader: String {
        let raw = [
            "date", "steps", "active_calories", "exercise_minutes", "stand_minutes",
            "resting_heart_rate", "hrv_sdnn", "sleep_duration_minutes",
            "deep_sleep_minutes", "rem_sleep_minutes", "core_sleep_minutes",
            "awake_minutes", "bedtime", "wake_time",
            "vo2_max", "oxygen_saturation", "respiratory_rate",
            "wrist_temperature", "body_mass", "body_fat_percentage",
            "distance_walking_running", "flights_climbed", "mindful_minutes",
            "workout_count", "workout_types"
        ]
        let scores = ["recovery_score", "sleep_score", "activity_score"]
        let recoveryComp = recoveryComponentKeys.map { "recovery_\($0)" }
        let sleepComp = sleepComponentKeys.map { "sleep_\($0)" }
        let activityComp = activityComponentKeys.map { "activity_\($0)" }
        let gamification = ["xp_earned", "quests_completed", "checked_in"]
        let metadata = ["data_completeness", "last_updated"]

        return (raw + scores + recoveryComp + sleepComp + activityComp + gamification + metadata)
            .joined(separator: ",")
    }

    var csvRow: String {
        let raw: [String] = [
            dateString,
            String(steps),
            String(format: "%.2f", activeCalories),
            String(format: "%.2f", exerciseMinutes),
            String(format: "%.2f", standMinutes),
            optionalString(restingHeartRate),
            optionalString(hrvSDNN),
            optionalString(sleepDurationMinutes),
            optionalString(deepSleepMinutes),
            optionalString(remSleepMinutes),
            optionalString(coreSleepMinutes),
            optionalString(awakeMinutes),
            optionalDateString(bedtime),
            optionalDateString(wakeTime),
            optionalString(vo2Max),
            optionalString(oxygenSaturation),
            optionalString(respiratoryRate),
            optionalString(wristTemperature),
            optionalString(bodyMass),
            optionalString(bodyFatPercentage),
            optionalString(distanceWalkingRunning),
            optionalIntString(flightsClimbed),
            optionalString(mindfulMinutes),
            String(workoutCount),
            csvEscape(workoutTypes.joined(separator: ";"))
        ]
        let scores: [String] = [
            optionalString(recoveryScore),
            optionalString(sleepScore),
            optionalString(activityScore)
        ]
        let recoveryComp = componentsString(recoveryComponents, keys: Self.recoveryComponentKeys)
        let sleepComp = componentsString(sleepComponents, keys: Self.sleepComponentKeys)
        let activityComp = componentsString(activityComponents, keys: Self.activityComponentKeys)
        let gamification: [String] = [
            String(xpEarned),
            String(questsCompleted),
            checkedIn ? "true" : "false"
        ]
        let metadata: [String] = [
            String(format: "%.3f", dataCompleteness),
            ISO8601DateFormatter().string(from: lastUpdated)
        ]

        return (raw + scores + recoveryComp + sleepComp + activityComp + gamification + metadata)
            .joined(separator: ",")
    }
}
