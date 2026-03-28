import Foundation
import CoreML
#if canImport(CreateML)
import CreateML
#endif
import TabularData

// MARK: - Model Types

enum MLModelType: String, CaseIterable {
    case recoveryPredictor
    case sleepForecaster

    var fileName: String {
        switch self {
        case .recoveryPredictor: return "RecoveryPredictor.mlmodel"
        case .sleepForecaster: return "SleepForecaster.mlmodel"
        }
    }

    var compiledFileName: String {
        switch self {
        case .recoveryPredictor: return "RecoveryPredictor.mlmodelc"
        case .sleepForecaster: return "SleepForecaster.mlmodelc"
        }
    }

    var targetColumn: String {
        switch self {
        case .recoveryPredictor: return "nextDayRecovery"
        case .sleepForecaster: return "sleepScore"
        }
    }

    var featureColumns: [String] {
        switch self {
        case .recoveryPredictor:
            return [
                "sleepDurationMinutes", "deepSleepRatio", "remSleepRatio",
                "hrvSDNN", "restingHeartRate", "activityScore",
                "exerciseMinutes", "steps", "activeCalories",
                "sleepScore", "awakeMinutes", "dataCompleteness"
            ]
        case .sleepForecaster:
            return [
                "activityScore", "exerciseMinutes", "steps",
                "activeCalories", "previousSleepScore", "dayOfWeek",
                "standMinutes"
            ]
        }
    }

    /// Minimum snapshots needed before training is worthwhile
    var minimumSamples: Int { 30 }
}

// MARK: - Training Status

enum TrainingStatus: Equatable {
    case notTrained
    case notAvailable // CreateML not available (e.g. simulator)
    case training
    case trained(Date)
    case failed(String)
}

// MARK: - MLModelManager

@Observable
final class MLModelManager {
    private(set) var models: [MLModelType: MLModel] = [:]
    private(set) var status: [MLModelType: TrainingStatus] = [:]
    private(set) var lastTrainingMetrics: [MLModelType: TrainingMetrics] = [:]

    private let modelsDirectory: URL

    struct TrainingMetrics {
        let rmse: Double
        let sampleCount: Int
        let trainedAt: Date
    }

    /// Whether on-device training is supported on this platform
    static var isTrainingAvailable: Bool {
        #if canImport(CreateML)
        return true
        #else
        return false
        #endif
    }

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        modelsDirectory = docs.appendingPathComponent("MLModels", isDirectory: true)
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        let initialStatus: TrainingStatus = Self.isTrainingAvailable ? .notTrained : .notAvailable
        for type in MLModelType.allCases {
            status[type] = initialStatus
        }
    }

    // MARK: - Load Previously Trained Models

    func loadSavedModels() {
        for type in MLModelType.allCases {
            let compiledURL = modelsDirectory.appendingPathComponent(type.compiledFileName)
            let sourceURL = modelsDirectory.appendingPathComponent(type.fileName)

            if FileManager.default.fileExists(atPath: compiledURL.path) {
                loadCompiledModel(type, from: compiledURL)
            } else if FileManager.default.fileExists(atPath: sourceURL.path) {
                compileAndLoadModel(type, from: sourceURL)
            }
        }
    }

    private func loadCompiledModel(_ type: MLModelType, from url: URL) {
        do {
            let model = try MLModel(contentsOf: url)
            models[type] = model
            let modified = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? Date()
            status[type] = .trained(modified)
        } catch {
            print("Failed to load \(type.rawValue): \(error.localizedDescription)")
        }
    }

    private func compileAndLoadModel(_ type: MLModelType, from url: URL) {
        do {
            let compiledURL = try MLModel.compileModel(at: url)
            // Move compiled model to persistent location
            let destURL = modelsDirectory.appendingPathComponent(type.compiledFileName)
            try? FileManager.default.removeItem(at: destURL)
            try FileManager.default.moveItem(at: compiledURL, to: destURL)
            loadCompiledModel(type, from: destURL)
        } catch {
            print("Failed to compile \(type.rawValue): \(error.localizedDescription)")
        }
    }

    func isModelAvailable(_ type: MLModelType) -> Bool {
        models[type] != nil
    }

    // MARK: - On-Device Training (CreateML, physical device only)

    #if canImport(CreateML)
    func trainAll(snapshots: [DailySnapshot]) async {
        await trainRecoveryModel(snapshots: snapshots)
        await trainSleepModel(snapshots: snapshots)
    }

    func trainRecoveryModel(snapshots: [DailySnapshot]) async {
        let type = MLModelType.recoveryPredictor
        let sorted = snapshots.sorted { $0.date < $1.date }
        guard sorted.count >= type.minimumSamples else {
            status[type] = .failed("Need \(type.minimumSamples) days, have \(sorted.count)")
            return
        }

        status[type] = .training

        do {
            let dataFrame = buildRecoveryDataFrame(from: sorted)
            guard dataFrame.rows.count >= type.minimumSamples else {
                status[type] = .failed("Insufficient complete data rows")
                return
            }

            let model = try MLBoostedTreeRegressor(
                trainingData: dataFrame,
                targetColumn: type.targetColumn,
                featureColumns: type.featureColumns,
                parameters: .init(
                    maxDepth: 4,
                    maxIterations: 200,
                    minLossReduction: 0.01
                )
            )

            let metrics = TrainingMetrics(
                rmse: model.trainingMetrics.rootMeanSquaredError,
                sampleCount: dataFrame.rows.count,
                trainedAt: Date()
            )
            lastTrainingMetrics[type] = metrics

            try saveAndLoad(model: model, type: type)
            status[type] = .trained(Date())
        } catch {
            status[type] = .failed(error.localizedDescription)
        }
    }

    func trainSleepModel(snapshots: [DailySnapshot]) async {
        let type = MLModelType.sleepForecaster
        let sorted = snapshots.sorted { $0.date < $1.date }
        guard sorted.count >= type.minimumSamples else {
            status[type] = .failed("Need \(type.minimumSamples) days, have \(sorted.count)")
            return
        }

        status[type] = .training

        do {
            let dataFrame = buildSleepDataFrame(from: sorted)
            guard dataFrame.rows.count >= type.minimumSamples else {
                status[type] = .failed("Insufficient complete data rows")
                return
            }

            let model = try MLBoostedTreeRegressor(
                trainingData: dataFrame,
                targetColumn: type.targetColumn,
                featureColumns: type.featureColumns,
                parameters: .init(
                    maxDepth: 4,
                    maxIterations: 200,
                    minLossReduction: 0.01
                )
            )

            let metrics = TrainingMetrics(
                rmse: model.trainingMetrics.rootMeanSquaredError,
                sampleCount: dataFrame.rows.count,
                trainedAt: Date()
            )
            lastTrainingMetrics[type] = metrics

            try saveAndLoad(model: model, type: type)
            status[type] = .trained(Date())
        } catch {
            status[type] = .failed(error.localizedDescription)
        }
    }

    private func saveAndLoad(model: MLBoostedTreeRegressor, type: MLModelType) throws {
        let sourceURL = modelsDirectory.appendingPathComponent(type.fileName)
        try model.write(to: sourceURL)

        let compiledURL = try MLModel.compileModel(at: sourceURL)
        let destURL = modelsDirectory.appendingPathComponent(type.compiledFileName)
        try? FileManager.default.removeItem(at: destURL)
        try FileManager.default.moveItem(at: compiledURL, to: destURL)

        let coreMLModel = try MLModel(contentsOf: destURL)
        models[type] = coreMLModel
    }
    #else
    func trainAll(snapshots: [DailySnapshot]) async {
        for type in MLModelType.allCases {
            status[type] = .notAvailable
        }
    }

    func trainRecoveryModel(snapshots: [DailySnapshot]) async {
        status[.recoveryPredictor] = .notAvailable
    }

    func trainSleepModel(snapshots: [DailySnapshot]) async {
        status[.sleepForecaster] = .notAvailable
    }
    #endif

    // MARK: - DataFrame Construction

    private func buildRecoveryDataFrame(from sorted: [DailySnapshot]) -> DataFrame {
        var sleepDuration: [Double] = []
        var deepRatio: [Double] = []
        var remRatio: [Double] = []
        var hrv: [Double] = []
        var rhr: [Double] = []
        var activity: [Double] = []
        var exercise: [Double] = []
        var steps: [Double] = []
        var calories: [Double] = []
        var sleep: [Double] = []
        var awake: [Double] = []
        var completeness: [Double] = []
        var nextRecovery: [Double] = []

        for i in 0..<(sorted.count - 1) {
            let snap = sorted[i]
            let next = sorted[i + 1]

            guard let dur = snap.sleepDurationMinutes, dur > 0,
                  let deep = snap.deepSleepMinutes,
                  let rem = snap.remSleepMinutes,
                  let h = snap.hrvSDNN,
                  let r = snap.restingHeartRate,
                  let actScore = snap.activityScore,
                  let slpScore = snap.sleepScore,
                  let nextRec = next.recoveryScore else { continue }

            sleepDuration.append(dur)
            deepRatio.append(deep / dur)
            remRatio.append(rem / dur)
            hrv.append(h)
            rhr.append(r)
            activity.append(actScore)
            exercise.append(snap.exerciseMinutes)
            steps.append(Double(snap.steps))
            calories.append(snap.activeCalories)
            sleep.append(slpScore)
            awake.append(snap.awakeMinutes ?? 0)
            completeness.append(snap.dataCompleteness)
            nextRecovery.append(nextRec)
        }

        var df = DataFrame()
        df.append(column: Column(name: "sleepDurationMinutes", contents: sleepDuration))
        df.append(column: Column(name: "deepSleepRatio", contents: deepRatio))
        df.append(column: Column(name: "remSleepRatio", contents: remRatio))
        df.append(column: Column(name: "hrvSDNN", contents: hrv))
        df.append(column: Column(name: "restingHeartRate", contents: rhr))
        df.append(column: Column(name: "activityScore", contents: activity))
        df.append(column: Column(name: "exerciseMinutes", contents: exercise))
        df.append(column: Column(name: "steps", contents: steps))
        df.append(column: Column(name: "activeCalories", contents: calories))
        df.append(column: Column(name: "sleepScore", contents: sleep))
        df.append(column: Column(name: "awakeMinutes", contents: awake))
        df.append(column: Column(name: "dataCompleteness", contents: completeness))
        df.append(column: Column(name: "nextDayRecovery", contents: nextRecovery))
        return df
    }

    private func buildSleepDataFrame(from sorted: [DailySnapshot]) -> DataFrame {
        var activity: [Double] = []
        var exercise: [Double] = []
        var steps: [Double] = []
        var calories: [Double] = []
        var prevSleep: [Double] = []
        var dow: [Double] = []
        var stand: [Double] = []
        var sleepTarget: [Double] = []

        for i in 0..<sorted.count {
            let snap = sorted[i]

            guard let actScore = snap.activityScore,
                  let slpScore = snap.sleepScore else { continue }

            activity.append(actScore)
            exercise.append(snap.exerciseMinutes)
            steps.append(Double(snap.steps))
            calories.append(snap.activeCalories)
            prevSleep.append(i > 0 ? (sorted[i - 1].sleepScore ?? slpScore) : slpScore)
            dow.append(Double(Calendar.current.component(.weekday, from: snap.date)))
            stand.append(snap.standMinutes)
            sleepTarget.append(slpScore)
        }

        var df = DataFrame()
        df.append(column: Column(name: "activityScore", contents: activity))
        df.append(column: Column(name: "exerciseMinutes", contents: exercise))
        df.append(column: Column(name: "steps", contents: steps))
        df.append(column: Column(name: "activeCalories", contents: calories))
        df.append(column: Column(name: "previousSleepScore", contents: prevSleep))
        df.append(column: Column(name: "dayOfWeek", contents: dow))
        df.append(column: Column(name: "standMinutes", contents: stand))
        df.append(column: Column(name: "sleepScore", contents: sleepTarget))
        return df
    }

    // MARK: - Predictions

    func predictRecovery(from snapshot: DailySnapshot) -> Double? {
        guard let model = models[.recoveryPredictor] else { return nil }

        guard let dur = snapshot.sleepDurationMinutes, dur > 0,
              let deep = snapshot.deepSleepMinutes,
              let rem = snapshot.remSleepMinutes,
              let h = snapshot.hrvSDNN,
              let r = snapshot.restingHeartRate,
              let actScore = snapshot.activityScore,
              let slpScore = snapshot.sleepScore else { return nil }

        do {
            let input = try MLDictionaryFeatureProvider(dictionary: [
                "sleepDurationMinutes": dur,
                "deepSleepRatio": deep / dur,
                "remSleepRatio": rem / dur,
                "hrvSDNN": h,
                "restingHeartRate": r,
                "activityScore": actScore,
                "exerciseMinutes": snapshot.exerciseMinutes,
                "steps": Double(snapshot.steps),
                "activeCalories": snapshot.activeCalories,
                "sleepScore": slpScore,
                "awakeMinutes": snapshot.awakeMinutes ?? 0.0,
                "dataCompleteness": snapshot.dataCompleteness
            ] as [String: NSNumber])
            let output = try model.prediction(from: input)
            return output.featureValue(for: "nextDayRecovery")?.doubleValue
        } catch {
            print("Recovery prediction failed: \(error.localizedDescription)")
            return nil
        }
    }

    func predictSleep(from snapshot: DailySnapshot, previousSleepScore: Double? = nil) -> Double? {
        guard let model = models[.sleepForecaster] else { return nil }

        guard let actScore = snapshot.activityScore else { return nil }

        let prevSleep = previousSleepScore ?? snapshot.sleepScore ?? 0

        do {
            let input = try MLDictionaryFeatureProvider(dictionary: [
                "activityScore": actScore,
                "exerciseMinutes": snapshot.exerciseMinutes,
                "steps": Double(snapshot.steps),
                "activeCalories": snapshot.activeCalories,
                "previousSleepScore": prevSleep,
                "dayOfWeek": Double(Calendar.current.component(.weekday, from: snapshot.date)),
                "standMinutes": snapshot.standMinutes
            ] as [String: NSNumber])
            let output = try model.prediction(from: input)
            return output.featureValue(for: "sleepScore")?.doubleValue
        } catch {
            print("Sleep prediction failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Retraining Policy

    func shouldRetrain(_ type: MLModelType, currentSnapshotCount: Int) -> Bool {
        switch status[type] {
        case .notTrained, .failed:
            return currentSnapshotCount >= type.minimumSamples
        case .trained(let date):
            let weekOld = Date().timeIntervalSince(date) > 7 * 24 * 3600
            if let metrics = lastTrainingMetrics[type] {
                let significantNewData = currentSnapshotCount > Int(Double(metrics.sampleCount) * 1.2)
                return weekOld || significantNewData
            }
            return weekOld
        case .training, .notAvailable:
            return false
        case .none:
            return currentSnapshotCount >= type.minimumSamples
        }
    }
}
