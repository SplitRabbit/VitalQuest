import SwiftUI
import SwiftData
import Charts

struct ScoresView: View {
    @Query(sort: \DailySnapshot.date, order: .reverse) private var snapshots: [DailySnapshot]

    @State private var selectedScore: ScoreType = .recovery

    enum ScoreType: String, CaseIterable {
        case recovery = "Recovery"
        case sleep = "Sleep"
        case activity = "Activity"


        var color: Color {
            switch self {
            case .recovery: .vqGreen
            case .sleep: .vqPurple
            case .activity: .vqPink

            }
        }

        var gradientColors: [Color] {
            switch self {
            case .recovery: Color.recoveryGradientColors
            case .sleep: Color.sleepGradientColors
            case .activity: Color.activityGradientColors

            }
        }

        var icon: String {
            switch self {
            case .recovery: "bolt.heart.fill"
            case .sleep: "moon.stars.fill"
            case .activity: "figure.run"

            }
        }
    }

    private var todaySnapshot: DailySnapshot? { snapshots.first }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedMeshBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // Score type picker
                        scorePicker

                        // Big score display
                        bigScoreDisplay

                        // Component breakdown
                        componentBreakdown

                        // 7-day trend chart
                        trendChart

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Scores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Score Picker

    private var scorePicker: some View {
        HStack(spacing: 8) {
            ForEach(ScoreType.allCases, id: \.self) { type in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedScore = type
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: type.icon)
                            .font(.system(size: 16, weight: .semibold))
                        Text(type.rawValue)
                            .font(.vqCaption)
                    }
                    .foregroundStyle(selectedScore == type ? Color.vqTextPrimary : Color.vqTextSecondary.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(selectedScore == type ? type.color.opacity(0.25) : .clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(selectedScore == type ? type.color.opacity(0.5) : .clear, lineWidth: 1)
                    )
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Big Score

    private var bigScoreDisplay: some View {
        let score = currentScore(todaySnapshot)
        let tier = DailySnapshot.scoreTier(score)

        return VStack(spacing: 8) {
            ScoreRing(
                score: score,
                label: selectedScore.rawValue,
                gradientColors: selectedScore.gradientColors,
                size: 180, lineWidth: 14
            )

            Text(tier.label)
                .font(.vqHeadline)
                .foregroundStyle(tier.color)

            Text(scoreDescription(for: selectedScore, tier: tier))
                .font(.vqBody)
                .foregroundStyle(Color.vqTextSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .vqGlowCard(color: selectedScore.color)
    }

    // MARK: - Component Breakdown

    private var componentBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Components")
                .font(.vqHeadline)
                .foregroundStyle(Color.vqTextPrimary)

            let components = currentComponents(todaySnapshot)
            ForEach(components.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                if key != "total" && key != "status" {
                    ScoreComponentRow(
                        label: formatComponentName(key),
                        value: value,
                        weight: componentWeight(key, for: selectedScore),
                        color: selectedScore.color
                    )
                }
            }

            if components.isEmpty {
                Text("No data yet — wear your Apple Watch and check back!")
                    .font(.vqBody)
                    .foregroundStyle(Color.vqTextSecondary.opacity(0.6))
                    .padding(.vertical, 8)
            }
        }
        .vqCard()
    }

    // MARK: - Trend Chart

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("7-Day Trend")
                .font(.vqHeadline)
                .foregroundStyle(Color.vqTextPrimary)

            let data = recentData(days: 7)

            if data.isEmpty {
                Text("Keep tracking to see trends!")
                    .font(.vqBody)
                    .foregroundStyle(Color.vqTextSecondary.opacity(0.6))
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(data, id: \.date) { point in
                    LineMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Score", point.score)
                    )
                    .foregroundStyle(selectedScore.color.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Score", point.score)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [selectedScore.color.opacity(0.3), selectedScore.color.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Score", point.score)
                    )
                    .foregroundStyle(selectedScore.color)
                    .symbolSize(30)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisValueLabel()
                            .foregroundStyle(Color.vqTextSecondary.opacity(0.6))
                        AxisGridLine()
                            .foregroundStyle(Color.vqTextPrimary.opacity(0.04))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                            .foregroundStyle(Color.vqTextSecondary.opacity(0.6))
                    }
                }
                .frame(height: 180)
            }
        }
        .vqCard()
    }

    // MARK: - Helpers

    private func currentScore(_ snapshot: DailySnapshot?) -> Double {
        guard let snap = snapshot else { return 0 }
        switch selectedScore {
        case .recovery: return snap.recoveryScore ?? 0
        case .sleep: return snap.sleepScore ?? 0
        case .activity: return snap.activityScore ?? 0
        }
    }

    private func currentComponents(_ snapshot: DailySnapshot?) -> [String: Double] {
        guard let snap = snapshot else { return [:] }
        switch selectedScore {
        case .recovery: return snap.recoveryComponents
        case .sleep: return snap.sleepComponents
        case .activity: return snap.activityComponents
        }
    }

    struct ChartPoint {
        let date: Date
        let score: Double
    }

    private func recentData(days: Int) -> [ChartPoint] {
        snapshots.prefix(days).reversed().compactMap { snap in
            let score = currentScore(snap)
            return score > 0 ? ChartPoint(date: snap.date, score: score) : nil
        }
    }

    private func formatComponentName(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func componentWeight(_ key: String, for type: ScoreType) -> String {
        let weights: [String: String]
        switch type {
        case .recovery:
            weights = ["hrv_percentile": "30%", "rhr_percentile": "25%", "sleep_quality": "25%", "hrv_trend": "10%", "strain_impact": "10%"]
        case .sleep:
            weights = ["duration": "30%", "deep_sleep": "20%", "rem_sleep": "15%", "consistency": "15%", "nighttime_hrv": "10%", "sleep_latency": "10%"]
        case .activity:
            weights = ["calories": "25%", "steps": "20%", "exercise": "20%", "variety": "15%", "consistency": "20%"]
        }
        return weights[key] ?? ""
    }

    private func scoreDescription(for type: ScoreType, tier: ScoreTier) -> String {
        switch (type, tier) {
        case (.recovery, .excellent): return "Your body is fully recharged. Go crush it!"
        case (.recovery, .good): return "Solid recovery. You're ready for a good day."
        case (.recovery, .fair): return "Take it a bit easy today."
        case (.recovery, .low): return "Your body needs rest. Prioritize recovery."
        case (.sleep, .excellent): return "Amazing sleep! You're a sleep champion."
        case (.sleep, .good): return "Good rest. Keep up the bedtime routine."
        case (.sleep, .fair): return "Decent sleep, but there's room to improve."
        case (.sleep, .low): return "Rough night. Try winding down earlier."
        case (.activity, .excellent): return "You're on fire! Incredible movement today."
        case (.activity, .good): return "Great activity level. Keep moving!"
        case (.activity, .fair): return "Some movement today. A walk could help."
        case (.activity, .low): return "Time to get moving! Every step counts."
        }
    }
}

#Preview {
    ScoresView()
        .modelContainer(for: DailySnapshot.self, inMemory: true)
        .withMockEnvironment()
}
