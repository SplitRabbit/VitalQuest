import Foundation
import Observation

/// Computes Recovery, Sleep, and Activity scores from health data + baselines.
@Observable
final class ScoringEngine {
    private let baselineEngine: BaselineEngine

    init(baselineEngine: BaselineEngine) {
        self.baselineEngine = baselineEngine
    }

    // MARK: - Recovery Score (0-100)

    struct RecoveryResult {
        var score: Double
        var components: [String: Double]
    }

    func computeRecoveryScore(
        hrvSDNN: Double?,
        restingHeartRate: Double?,
        sleepScore: Double?,
        recentHRVValues: [Double],  // Last 3 days for trend
        previousDayStrain: Double?  // Activity score from yesterday
    ) -> RecoveryResult {
        var components: [String: Double] = [:]
        var totalWeight = 0.0
        var weightedSum = 0.0

        // HRV vs baseline (30%)
        if let hrv = hrvSDNN {
            let lnHRV = Statistics.lnTransform(hrv)
            let pct = baselineEngine.percentile(value: lnHRV, for: MetricBaseline.hrvSDNN)
            components["hrv_percentile"] = pct
            weightedSum += pct * 0.30
            totalWeight += 0.30
        }

        // Resting HR vs baseline (25%) — lower is better
        if let rhr = restingHeartRate {
            let pct = baselineEngine.invertedPercentile(value: rhr, for: MetricBaseline.restingHeartRate)
            components["rhr_percentile"] = pct
            weightedSum += pct * 0.25
            totalWeight += 0.25
        }

        // Sleep quality (25%)
        if let sleep = sleepScore {
            components["sleep_quality"] = sleep
            weightedSum += sleep * 0.25
            totalWeight += 0.25
        }

        // 3-day HRV trend (10%)
        if recentHRVValues.count >= 2 {
            let lnValues = recentHRVValues.map { Statistics.lnTransform($0) }
            let slope = Statistics.linearSlope(values: lnValues)
            // Normalize slope: positive slope = good, map to 0-100
            let trendScore = Statistics.clamp01Score(50 + slope * 500)
            components["hrv_trend"] = trendScore
            weightedSum += trendScore * 0.10
            totalWeight += 0.10
        }

        // Previous day strain — inverted (10%)
        if let strain = previousDayStrain {
            let invertedStrain = 100.0 - strain * 0.5 // High activity partially reduces recovery
            let strainScore = Statistics.clamp01Score(invertedStrain)
            components["strain_impact"] = strainScore
            weightedSum += strainScore * 0.10
            totalWeight += 0.10
        }

        // Normalize by actual weights used (graceful degradation)
        let score = totalWeight > 0 ? Statistics.clamp01Score(weightedSum / totalWeight) : 50
        components["total"] = score
        return RecoveryResult(score: score, components: components)
    }

    // MARK: - Sleep Score (0-100)

    struct SleepResult {
        var score: Double
        var components: [String: Double]
    }

    func computeSleepScore(
        sleep: SleepData?,
        targetHours: Double = 8.0,
        recentBedtimes: [Date],  // Last 7 days for consistency
        nighttimeHRV: Double? = nil
    ) -> SleepResult {
        guard let sleep = sleep, sleep.totalMinutes > 0 else {
            return SleepResult(score: 0, components: ["status": -1]) // No data
        }

        var components: [String: Double] = [:]
        let totalHours = sleep.totalMinutes / 60.0

        // Duration adequacy (30%) — Gaussian centered on target
        let durationScore = Statistics.gaussianScore(value: totalHours, target: targetHours, sigma: 1.5)
        components["duration"] = durationScore

        // Deep sleep ratio (20%)
        let deepRatio = sleep.deepMinutes / sleep.totalMinutes
        let deepPct = baselineEngine.hasBaseline(for: MetricBaseline.deepSleepRatio)
            ? baselineEngine.percentile(value: deepRatio, for: MetricBaseline.deepSleepRatio)
            : Statistics.gaussianScore(value: deepRatio, target: 0.175, sigma: 0.05) // Target 15-20%
        components["deep_sleep"] = deepPct

        // REM ratio (15%)
        let remRatio = sleep.remMinutes / sleep.totalMinutes
        let remPct = baselineEngine.hasBaseline(for: MetricBaseline.remSleepRatio)
            ? baselineEngine.percentile(value: remRatio, for: MetricBaseline.remSleepRatio)
            : Statistics.gaussianScore(value: remRatio, target: 0.225, sigma: 0.05) // Target 20-25%
        components["rem_sleep"] = remPct

        // Bedtime consistency (15%)
        var consistencyScore = 75.0 // Default if not enough data
        if recentBedtimes.count >= 3 {
            let bedtimeMinutes = recentBedtimes.map { minutesSinceMidnight($0) }
            let stdDev = Statistics.stdDev(values: bedtimeMinutes)
            // < 15 min stddev = excellent, > 90 min = poor
            consistencyScore = Statistics.clamp01Score(100 - (stdDev - 15) * (100.0 / 75.0))
        }
        components["consistency"] = consistencyScore

        // Nighttime HRV (10%)
        var hrvScore = 50.0
        if let hrv = nighttimeHRV {
            let lnHRV = Statistics.lnTransform(hrv)
            hrvScore = baselineEngine.hasBaseline(for: MetricBaseline.hrvSDNN)
                ? baselineEngine.percentile(value: lnHRV, for: MetricBaseline.hrvSDNN)
                : 50
        }
        components["nighttime_hrv"] = hrvScore

        // Time to sleep (10%)
        var latencyScore = 70.0 // Default
        if sleep.awakeMinutes > 0 {
            // <10 min = great, 10-20 = good, >30 = poor
            latencyScore = Statistics.clamp01Score(100 - (sleep.awakeMinutes - 10) * 3)
        }
        components["sleep_latency"] = latencyScore

        let score = Statistics.clamp01Score(
            durationScore * 0.30 +
            deepPct * 0.20 +
            remPct * 0.15 +
            consistencyScore * 0.15 +
            hrvScore * 0.10 +
            latencyScore * 0.10
        )

        components["total"] = score
        return SleepResult(score: score, components: components)
    }

    // MARK: - Activity Score (0-100)

    struct ActivityResult {
        var score: Double
        var components: [String: Double]
    }

    func computeActivityScore(
        steps: Int,
        activeCalories: Double,
        exerciseMinutes: Double,
        workoutTypes: [String],
        recentActiveDays: Int,    // Active days out of last 7
        calorieGoal: Double = 500,
        stepGoal: Int = 10000
    ) -> ActivityResult {
        var components: [String: Double] = [:]

        // Calories vs goal (25%)
        let calorieScore = calorieGoal > 0
            ? Statistics.clamp01Score((activeCalories / calorieGoal) * 100) : 0
        components["calories"] = calorieScore

        // Steps percentile (20%)
        let stepScore: Double
        if baselineEngine.hasBaseline(for: MetricBaseline.steps) {
            stepScore = baselineEngine.percentile(value: Double(steps), for: MetricBaseline.steps)
        } else {
            stepScore = stepGoal > 0
                ? Statistics.clamp01Score(Double(steps) / Double(stepGoal) * 100) : 0
        }
        components["steps"] = stepScore

        // Exercise minutes vs WHO target (20%)
        // 150 min/week = ~21.4 min/day
        let dailyTarget = 150.0 / 7.0
        let exerciseScore = Statistics.clamp01Score((exerciseMinutes / dailyTarget) * 100)
        components["exercise"] = exerciseScore

        // Workout variety (15%) — distinct types in recent period
        let uniqueTypes = Set(workoutTypes).count
        let varietyScore: Double = switch uniqueTypes {
        case 0: 0
        case 1: 40
        case 2: 65
        case 3: 80
        case 4: 90
        default: 100
        }
        components["variety"] = varietyScore

        // Consistency (20%) — active days out of 7
        let consistencyScore = Statistics.clamp01Score(Double(recentActiveDays) / 7.0 * 100)
        components["consistency"] = consistencyScore

        let score = Statistics.clamp01Score(
            calorieScore * 0.25 +
            stepScore * 0.20 +
            exerciseScore * 0.20 +
            varietyScore * 0.15 +
            consistencyScore * 0.20
        )

        components["total"] = score
        return ActivityResult(score: score, components: components)
    }

    // MARK: - Full Pipeline

    /// Compute all scores for a daily snapshot, updating it in place.
    func computeAllScores(
        for snapshot: DailySnapshot,
        healthData: DailyHealthData,
        previousDaySnapshot: DailySnapshot?,
        recentHRVValues: [Double],
        recentBedtimes: [Date],
        recentActiveDays: Int,
        profile: UserProfile
    ) {
        // Sleep Score
        let sleepResult = computeSleepScore(
            sleep: healthData.sleep,
            targetHours: profile.sleepGoalHours,
            recentBedtimes: recentBedtimes,
            nighttimeHRV: healthData.hrvSummary?.mean
        )
        snapshot.sleepScore = sleepResult.score
        snapshot.sleepComponents = sleepResult.components

        // Recovery Score
        let recoveryResult = computeRecoveryScore(
            hrvSDNN: healthData.hrvSummary?.mean,
            restingHeartRate: healthData.restingHeartRate,
            sleepScore: sleepResult.score,
            recentHRVValues: recentHRVValues,
            previousDayStrain: previousDaySnapshot?.activityScore
        )
        snapshot.recoveryScore = recoveryResult.score
        snapshot.recoveryComponents = recoveryResult.components

        // Activity Score
        let activityResult = computeActivityScore(
            steps: healthData.steps,
            activeCalories: healthData.activeCalories,
            exerciseMinutes: healthData.exerciseMinutes,
            workoutTypes: healthData.workouts.types,
            recentActiveDays: recentActiveDays,
            calorieGoal: profile.calorieGoal,
            stepGoal: profile.stepGoal
        )
        snapshot.activityScore = activityResult.score
        snapshot.activityComponents = activityResult.components

        // Compute data completeness
        var available = 0
        let total = 7 // steps, calories, exercise, rhr, hrv, sleep, workouts
        if healthData.steps > 0 { available += 1 }
        if healthData.activeCalories > 0 { available += 1 }
        if healthData.exerciseMinutes > 0 { available += 1 }
        if healthData.restingHeartRate != nil { available += 1 }
        if healthData.hrvSummary != nil { available += 1 }
        if healthData.sleep != nil { available += 1 }
        if healthData.workouts.count > 0 { available += 1 }
        snapshot.dataCompleteness = Double(available) / Double(total)
    }

    // MARK: - Private

    private func minutesSinceMidnight(_ date: Date) -> Double {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        var minutes = Double(components.hour ?? 0) * 60 + Double(components.minute ?? 0)
        // Wrap late-night times (after midnight) to negative for consistency calc
        if minutes < 360 { minutes += 1440 } // Before 6 AM → treat as previous night
        return minutes
    }
}
