import Foundation

enum Statistics {
    /// Z-score: how many standard deviations from the mean
    static func zScore(value: Double, mean: Double, stdDev: Double) -> Double {
        guard stdDev > 0 else { return 0 }
        return (value - mean) / stdDev
    }

    /// Percentile rank using sorted-array bisection (0-100)
    static func percentileRank(value: Double, in sortedValues: [Double]) -> Double {
        guard !sortedValues.isEmpty else { return 50 }
        // Binary search for insertion point
        var low = 0
        var high = sortedValues.count
        while low < high {
            let mid = (low + high) / 2
            if sortedValues[mid] < value {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return (Double(low) / Double(sortedValues.count)) * 100.0
    }

    /// Inverted percentile (lower value = higher percentile, e.g., resting HR)
    static func invertedPercentileRank(value: Double, in sortedValues: [Double]) -> Double {
        100.0 - percentileRank(value: value, in: sortedValues)
    }

    /// EWMA update: newValue with smoothing factor alpha
    static func ewmaUpdate(previous: Double, newValue: Double, alpha: Double) -> Double {
        alpha * newValue + (1.0 - alpha) * previous
    }

    /// EWMA variance update (for confidence intervals)
    static func ewmaVarianceUpdate(previousVariance: Double, newValue: Double, ewma: Double, alpha: Double) -> Double {
        let diff = newValue - ewma
        return (1.0 - alpha) * (previousVariance + alpha * diff * diff)
    }

    /// Simple moving average
    static func sma(values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Standard deviation
    static func stdDev(values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = sma(values: values)
        let sumSquares = values.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) }
        return sqrt(sumSquares / Double(values.count - 1))
    }

    /// Linear regression slope on an array of values (equally spaced)
    static func linearSlope(values: [Double]) -> Double {
        let n = Double(values.count)
        guard n >= 2 else { return 0 }
        let xMean = (n - 1) / 2.0
        let yMean = sma(values: values)
        var numerator = 0.0
        var denominator = 0.0
        for (i, y) in values.enumerated() {
            let x = Double(i)
            numerator += (x - xMean) * (y - yMean)
            denominator += (x - xMean) * (x - xMean)
        }
        guard denominator > 0 else { return 0 }
        return numerator / denominator
    }

    /// Gaussian score centered on target with given width (sigma)
    /// Returns 0-100 where 100 = exactly on target
    static func gaussianScore(value: Double, target: Double, sigma: Double) -> Double {
        let z = (value - target) / sigma
        return 100.0 * exp(-0.5 * z * z)
    }

    /// Clamp a value to 0-100
    static func clamp01Score(_ value: Double) -> Double {
        min(100, max(0, value))
    }

    /// Natural log transform (for HRV SDNN normalization)
    static func lnTransform(_ value: Double) -> Double {
        guard value > 0 else { return 0 }
        return log(value)
    }

    /// Insert a value into a sorted array, maintaining sort order.
    /// Trims to maxCount by removing oldest entries based on paired dates array.
    static func insertSorted(
        value: Double,
        date: Date,
        into values: inout [Double],
        dates: inout [Date],
        maxCount: Int = 90
    ) {
        // Find insertion point in sorted values
        var low = 0
        var high = values.count
        while low < high {
            let mid = (low + high) / 2
            if values[mid] < value {
                low = mid + 1
            } else {
                high = mid
            }
        }
        values.insert(value, at: low)
        dates.insert(date, at: low)

        // Trim oldest if over capacity
        while values.count > maxCount {
            if let oldestIdx = dates.enumerated().min(by: { $0.element < $1.element })?.offset {
                values.remove(at: oldestIdx)
                dates.remove(at: oldestIdx)
            }
        }
    }
}
