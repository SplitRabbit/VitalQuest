import SwiftUI
import SwiftData
import Charts

struct MetricDetailView: View {
    let metricID: String
    let title: String
    let icon: String
    let color: Color
    let unit: String
    let higherIsBetter: Bool
    let recentSnapshots: [DailySnapshot]

    @Environment(\.dismiss) private var dismiss

    private var allData: [(date: Date, value: Double)] {
        let extractor = metricExtractor
        return recentSnapshots.compactMap { snap in
            extractor(snap).map { (snap.date, $0) }
        }.sorted { $0.date < $1.date }
    }

    private var latestValue: Double? {
        allData.last?.value
    }

    private var average: Double? {
        let vals = allData.map(\.value)
        guard !vals.isEmpty else { return nil }
        return vals.reduce(0, +) / Double(vals.count)
    }

    private var minimum: Double? {
        allData.map(\.value).min()
    }

    private var maximum: Double? {
        allData.map(\.value).max()
    }

    private var trendDirection: String {
        guard allData.count >= 3 else { return "—" }
        let recent = Array(allData.suffix(3))
        let older = Array(allData.prefix(max(allData.count - 3, 1)))
        let recentAvg = recent.map(\.value).reduce(0, +) / Double(recent.count)
        let olderAvg = older.map(\.value).reduce(0, +) / Double(older.count)
        let diff = recentAvg - olderAvg
        let threshold = olderAvg * 0.03
        if abs(diff) < threshold { return "Stable" }
        if higherIsBetter {
            return diff > 0 ? "Improving" : "Declining"
        } else {
            return diff < 0 ? "Improving" : "Increasing"
        }
    }

    private var trendColor: Color {
        switch trendDirection {
        case "Improving": return .vqGreen
        case "Declining", "Increasing": return .vqOrange
        default: return Color.vqTextSecondary
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedMeshBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // Current value hero
                        currentValueSection

                        // Stats row
                        statsSection

                        // Chart
                        chartSection

                        // Daily breakdown
                        dailyBreakdownSection

                        // Context
                        contextSection
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(color)
                }
            }
        }
    }

    // MARK: - Current Value

    private var currentValueSection: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(color)
                .padding(16)
                .background(color.opacity(0.12))
                .clipShape(Circle())

            if let val = latestValue {
                Text(formatValue(val))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.vqTextPrimary)
                Text(unit)
                    .font(.vqCaption)
                    .foregroundStyle(Color.vqTextSecondary)
            } else {
                Text("No Data")
                    .font(.vqHeadline)
                    .foregroundStyle(Color.vqTextSecondary.opacity(0.5))
            }

            HStack(spacing: 4) {
                Image(systemName: trendDirection == "Improving" ? "arrow.up.right" :
                        trendDirection == "Declining" || trendDirection == "Increasing" ? "arrow.down.right" : "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                Text(trendDirection)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(trendColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(trendColor.opacity(0.12))
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .vqCard()
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 10) {
            if let avg = average {
                StatPill(label: "Average", value: formatValue(avg), color: color)
            }
            if let min = minimum {
                StatPill(label: "Low", value: formatValue(min), color: .vqOrange)
            }
            if let max = maximum {
                StatPill(label: "High", value: formatValue(max), color: .vqGreen)
            }
        }
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trend")
                .font(.vqHeadline)
                .foregroundStyle(Color.vqTextPrimary)

            if allData.count < 2 {
                Text("Need more data to show trends.")
                    .font(.vqCaption)
                    .foregroundStyle(Color.vqTextSecondary.opacity(0.6))
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(allData, id: \.date) { point in
                    BarMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, color.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(6)
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .foregroundStyle(Color.vqTextSecondary.opacity(0.6))
                        AxisGridLine()
                            .foregroundStyle(Color.vqTextPrimary.opacity(0.04))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                            .foregroundStyle(Color.vqTextSecondary.opacity(0.6))
                    }
                }
                .frame(height: 180)
            }
        }
        .vqCard()
    }

    // MARK: - Daily Breakdown

    private var dailyBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily Values")
                .font(.vqHeadline)
                .foregroundStyle(Color.vqTextPrimary)

            ForEach(allData.reversed().prefix(7), id: \.date) { point in
                HStack {
                    Text(point.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.vqCaption)
                        .foregroundStyle(Color.vqTextSecondary)
                    Spacer()
                    Text(formatValue(point.value))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.vqTextPrimary)
                    Text(unit)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Color.vqTextSecondary.opacity(0.5))
                        .frame(width: 36, alignment: .leading)
                }
                .padding(.vertical, 4)

                if point.date != allData.reversed().prefix(7).last?.date {
                    Divider().background(Color.vqTextPrimary.opacity(0.04))
                }
            }
        }
        .vqCard()
    }

    // MARK: - Context

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Mascot(mood: .happy, size: 24)
                Text("About \(title)")
                    .font(.vqHeadline)
                    .foregroundStyle(Color.vqTextPrimary)
            }

            Text(metricContext)
                .font(.vqCaption)
                .foregroundStyle(Color.vqTextSecondary)
        }
        .vqCard()
    }

    // MARK: - Helpers

    private var metricExtractor: (DailySnapshot) -> Double? {
        switch metricID {
        case "weight": return { $0.bodyMass }
        case "rhr": return { $0.restingHeartRate }
        case "hrv": return { $0.hrvSDNN }
        case "steps": return { Double($0.steps) }
        case "sleep": return { $0.sleepDurationMinutes.map { $0 / 60.0 } }
        case "calories": return { $0.activeCalories }
        case "exercise": return { $0.exerciseMinutes }
        case "distance": return { $0.distanceWalkingRunning.map { $0 / 1000.0 } }
        case "flights": return { $0.flightsClimbed.map { Double($0) } }
        case "bodyFat": return { $0.bodyFatPercentage.map { $0 * 100 } }
        case "mindful": return { $0.mindfulMinutes }
        case "vo2Max": return { $0.vo2Max }
        case "spo2": return { $0.oxygenSaturation.map { $0 * 100 } }
        default: return { _ in nil }
        }
    }

    private func formatValue(_ value: Double) -> String {
        switch metricID {
        case "steps": return "\(Int(value))"
        case "calories": return "\(Int(value))"
        case "exercise", "mindful": return "\(Int(value))"
        case "flights": return "\(Int(value))"
        case "sleep": return String(format: "%.1f", value)
        case "weight": return String(format: "%.1f", value)
        case "bodyFat", "spo2": return String(format: "%.1f", value)
        case "hrv": return "\(Int(value))"
        case "rhr": return "\(Int(value))"
        case "distance": return String(format: "%.1f", value)
        case "vo2Max": return String(format: "%.1f", value)
        default: return String(format: "%.1f", value)
        }
    }

    private var metricContext: String {
        switch metricID {
        case "weight": return "Track your weight over time to spot trends. Small fluctuations day-to-day are normal — focus on the weekly average."
        case "rhr": return "Resting heart rate reflects cardiovascular fitness. Lower is generally better. Elevated RHR can indicate stress, illness, or overtraining."
        case "hrv": return "Heart Rate Variability (HRV) measures the variation between heartbeats. Higher HRV generally indicates better recovery and fitness."
        case "steps": return "Daily steps are a simple measure of overall movement. The WHO recommends 8,000-10,000 steps per day for health benefits."
        case "sleep": return "Sleep duration and quality are foundational to recovery. Most adults need 7-9 hours per night."
        case "calories": return "Active calories represent energy burned through movement and exercise, excluding your basal metabolic rate."
        case "exercise": return "The WHO recommends at least 150 minutes of moderate exercise per week, or about 21 minutes per day."
        case "distance": return "Walking and running distance gives a sense of your overall movement volume beyond just step count."
        case "flights": return "Flights climbed measures your vertical movement. Climbing stairs is great for cardiovascular health."
        case "bodyFat": return "Body fat percentage is a more nuanced measure than weight alone. Healthy ranges vary by age and sex."
        case "mindful": return "Mindfulness and meditation can reduce stress, improve sleep, and boost overall well-being."
        case "vo2Max": return "VO2 Max is your body's maximum oxygen consumption during exercise — a strong predictor of cardiovascular fitness and longevity."
        case "spo2": return "Blood oxygen saturation (SpO2) measures how much oxygen your blood carries. Normal range is 95-100%."
        default: return "Track this metric over time to identify patterns and trends in your health data."
        }
    }
}
