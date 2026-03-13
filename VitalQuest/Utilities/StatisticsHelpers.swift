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
        guard sigma > 0 else { return value == target ? 100.0 : 0.0 }
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

    /// Pearson correlation coefficient between two equal-length arrays
    static func pearsonCorrelation(x: [Double], y: [Double]) -> Double {
        let n = min(x.count, y.count)
        guard n >= 2 else { return 0 }
        let xMean = sma(values: Array(x.prefix(n)))
        let yMean = sma(values: Array(y.prefix(n)))
        var numerator = 0.0
        var denomX = 0.0
        var denomY = 0.0
        for i in 0..<n {
            let dx = x[i] - xMean
            let dy = y[i] - yMean
            numerator += dx * dy
            denomX += dx * dx
            denomY += dy * dy
        }
        let denom = sqrt(denomX * denomY)
        guard denom > 0 else { return 0 }
        return numerator / denom
    }

    /// Moving average with given window size
    static func movingAverage(values: [Double], window: Int) -> [Double] {
        guard window > 0, !values.isEmpty else { return [] }
        let w = min(window, values.count)
        var result: [Double] = []
        var sum = 0.0

        for i in 0..<values.count {
            sum += values[i]
            if i >= w {
                sum -= values[i - w]
            }
            let count = min(i + 1, w)
            result.append(sum / Double(count))
        }

        return result
    }

    /// Autocorrelation at a given lag
    static func autocorrelation(values: [Double], lag: Int) -> Double {
        guard lag > 0, values.count > lag else { return 0 }
        let x = Array(values.dropLast(lag))
        let y = Array(values.dropFirst(lag))
        return pearsonCorrelation(x: x, y: y)
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
