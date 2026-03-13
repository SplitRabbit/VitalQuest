import Foundation

// MARK: - Trend Analysis

struct MetricTrend: Identifiable {
    let id = UUID()
    let metric: String
    let window: Int // days
    let slope: Double
    let direction: TrendDirection
    let magnitude: Double // slope relative to stddev

    enum TrendDirection: String, Codable {
        case improving, stable, declining
    }
}

// MARK: - Anomaly Detection

struct Anomaly: Identifiable {
    let id = UUID()
    let metric: String
    let value: Double
    let zScore: Double
    let direction: AnomalyDirection
    let date: Date

    enum AnomalyDirection: String, Codable {
        case above, below
    }
}

// MARK: - Personal Records

struct PersonalBest: Identifiable {
    let id = UUID()
    let metric: String
    let highValue: Double
    let highDate: Date
    let lowValue: Double
    let lowDate: Date
}

// MARK: - Correlation Matrix

struct CorrelationMatrix {
    let metrics: [String]
    let values: [[Double]] // metrics.count × metrics.count

    func value(for metricA: String, and metricB: String) -> Double? {
        guard let i = metrics.firstIndex(of: metricA),
              let j = metrics.firstIndex(of: metricB) else { return nil }
        return values[i][j]
    }
}

// MARK: - Insights

enum InsightType: String, Codable {
    case trend, correlation, anomaly, prediction, milestone
}

struct Insight: Identifiable {
    let id: UUID
    let type: InsightType
    let title: String
    let detail: String
    let metric: String?
    let severity: InsightSeverity
    let date: Date
    let relatedMetrics: [String]

    enum InsightSeverity: String, Codable {
        case info, notable, important
    }

    init(
        type: InsightType,
        title: String,
        detail: String,
        metric: String? = nil,
        severity: InsightSeverity = .info,
        date: Date = Date(),
        relatedMetrics: [String] = []
    ) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.detail = detail
        self.metric = metric
        self.severity = severity
        self.date = date
        self.relatedMetrics = relatedMetrics
    }
}
