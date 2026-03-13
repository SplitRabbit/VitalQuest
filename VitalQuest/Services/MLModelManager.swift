import Foundation
import CoreML

// MARK: - Model Types

enum MLModelType: String, CaseIterable {
    case recoveryPredictor
    case sleepForecaster
    case anomalyDetector

    var modelFileName: String {
        switch self {
        case .recoveryPredictor: return "RecoveryPredictor"
        case .sleepForecaster: return "SleepForecaster"
        case .anomalyDetector: return "AnomalyDetector"
        }
    }
}

// MARK: - Feature Structs

struct RecoveryFeatures {
    let sleepDurationMinutes: Double
    let deepSleepRatio: Double
    let remSleepRatio: Double
    let hrvSDNN: Double
    let restingHeartRate: Double
    let activityScore: Double
    let exerciseMinutes: Double
    let steps: Double
    let activeCalories: Double
    let sleepScore: Double
    let awakeMinutes: Double
    let dataCompleteness: Double

    init(from snapshot: DailySnapshot) {
        self.sleepDurationMinutes = snapshot.sleepDurationMinutes ?? 0
        let totalSleep = snapshot.sleepDurationMinutes ?? 1
        self.deepSleepRatio = (snapshot.deepSleepMinutes ?? 0) / max(totalSleep, 1)
        self.remSleepRatio = (snapshot.remSleepMinutes ?? 0) / max(totalSleep, 1)
        self.hrvSDNN = snapshot.hrvSDNN ?? 0
        self.restingHeartRate = snapshot.restingHeartRate ?? 0
        self.activityScore = snapshot.activityScore ?? 0
        self.exerciseMinutes = snapshot.exerciseMinutes
        self.steps = Double(snapshot.steps)
        self.activeCalories = snapshot.activeCalories
        self.sleepScore = snapshot.sleepScore ?? 0
        self.awakeMinutes = snapshot.awakeMinutes ?? 0
        self.dataCompleteness = snapshot.dataCompleteness
    }

    func toMLMultiArray() throws -> MLMultiArray {
        let array = try MLMultiArray(shape: [12], dataType: .double)
        let values = [
            sleepDurationMinutes, deepSleepRatio, remSleepRatio, hrvSDNN,
            restingHeartRate, activityScore, exerciseMinutes, steps,
            activeCalories, sleepScore, awakeMinutes, dataCompleteness
        ]
        for (i, val) in values.enumerated() {
            array[i] = NSNumber(value: val)
        }
        return array
    }
}

struct SleepFeatures {
    let activityScore: Double
    let exerciseMinutes: Double
    let steps: Double
    let activeCalories: Double
    let previousSleepScore: Double
    let dayOfWeek: Double // 1-7
    let standMinutes: Double

    init(from snapshot: DailySnapshot, previousSleepScore: Double? = nil) {
        self.activityScore = snapshot.activityScore ?? 0
        self.exerciseMinutes = snapshot.exerciseMinutes
        self.steps = Double(snapshot.steps)
        self.activeCalories = snapshot.activeCalories
        self.previousSleepScore = previousSleepScore ?? (snapshot.sleepScore ?? 0)
        self.dayOfWeek = Double(Calendar.current.component(.weekday, from: snapshot.date))
        self.standMinutes = snapshot.standMinutes
    }

    func toMLMultiArray() throws -> MLMultiArray {
        let array = try MLMultiArray(shape: [7], dataType: .double)
        let values = [
            activityScore, exerciseMinutes, steps, activeCalories,
            previousSleepScore, dayOfWeek, standMinutes
        ]
        for (i, val) in values.enumerated() {
            array[i] = NSNumber(value: val)
        }
        return array
    }
}

// MARK: - MLModelManager

@Observable
final class MLModelManager {
    private var loadedModels: [MLModelType: MLModel] = [:]

    init() {}

    // MARK: - Model Loading

    func loadModels() {
        for type in MLModelType.allCases {
            loadModel(type)
        }
    }

    private func loadModel(_ type: MLModelType) {
        guard let url = Bundle.main.url(forResource: type.modelFileName, withExtension: "mlmodelc") else {
            // No model compiled yet — this is expected before Python training
            return
        }
        do {
            let model = try MLModel(contentsOf: url)
            loadedModels[type] = model
        } catch {
            print("Failed to load \(type.modelFileName): \(error.localizedDescription)")
        }
    }

    func isModelAvailable(_ type: MLModelType) -> Bool {
        loadedModels[type] != nil
    }

    // MARK: - Predictions

    func predictRecovery(from snapshot: DailySnapshot) -> Double? {
        guard let model = loadedModels[.recoveryPredictor] else { return nil }

        do {
            let features = RecoveryFeatures(from: snapshot)
            let input = try MLDictionaryFeatureProvider(dictionary: [
                "input": features.toMLMultiArray()
            ])
            let output = try model.prediction(from: input)
            return output.featureValue(for: "target")?.doubleValue
        } catch {
            print("Recovery prediction failed: \(error.localizedDescription)")
            return nil
        }
    }

    func predictSleep(from snapshot: DailySnapshot, previousSleepScore: Double? = nil) -> Double? {
        guard let model = loadedModels[.sleepForecaster] else { return nil }

        do {
            let features = SleepFeatures(from: snapshot, previousSleepScore: previousSleepScore)
            let input = try MLDictionaryFeatureProvider(dictionary: [
                "input": features.toMLMultiArray()
            ])
            let output = try model.prediction(from: input)
            return output.featureValue(for: "target")?.doubleValue
        } catch {
            print("Sleep prediction failed: \(error.localizedDescription)")
            return nil
        }
    }
}
