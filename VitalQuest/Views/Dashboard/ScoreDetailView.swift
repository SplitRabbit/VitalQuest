import SwiftUI
import SwiftData
import Charts

struct ScoreDetailView: View {
    let scoreType: ScoreType
    let snapshot: DailySnapshot?
    let recentSnapshots: [DailySnapshot]

    enum ScoreType: String, Identifiable {
        var id: String { rawValue }
        case recovery = "Recovery"
        case sleep = "Sleep"
        case activity = "Activity"

        var icon: String {
            switch self {
            case .recovery: "bolt.heart.fill"
            case .sleep: "moon.stars.fill"
            case .activity: "figure.run"
            }
        }

        var color: Color {
            switch self {
            case .recovery: .vqGreen
            case .sleep: .vqBlue
            case .activity: .vqPink
            }
        }

        var description: String {
            switch self {
            case .recovery: "How well your body has recovered and is ready for the day ahead."
            case .sleep: "Quality and duration of your sleep, including stage balance."
            case .activity: "Your movement, exercise, and overall physical activity."
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    private var score: Double {
        guard let snap = snapshot else { return 0 }
        switch scoreType {
        case .recovery: return snap.recoveryScore ?? 0
        case .sleep: return snap.sleepScore ?? 0
        case .activity: return snap.activityScore ?? 0
        }
    }

    private var components: [String: Double] {
        guard let snap = snapshot else { return [:] }
        switch scoreType {
        case .recovery: return snap.recoveryComponents
        case .sleep: return snap.sleepComponents
        case .activity: return snap.activityComponents
        }
    }

    private var tier: ScoreTier {
        DailySnapshot.scoreTier(score)
    }

    private var trendData: [(date: Date, value: Double)] {
        recentSnapshots.compactMap { snap in
            let val: Double? = switch scoreType {
            case .recovery: snap.recoveryScore
            case .sleep: snap.sleepScore
            case .activity: snap.activityScore
            }
            guard let v = val else { return nil }
            return (snap.date, v)
        }.sorted { $0.date < $1.date }
    }

    private var avgScore: Double {
        let vals = trendData.map(\.value)
        guard !vals.isEmpty else { return 0 }
        return vals.reduce(0, +) / Double(vals.count)
    }

    private var relatedMetrics: [(label: String, value: String, icon: String, color: Color)] {
        guard let snap = snapshot else { return [] }
        switch scoreType {
        case .recovery:
            var metrics: [(String, String, String, Color)] = []
            if let hrv = snap.hrvSDNN { metrics.append(("HRV", "\(Int(hrv)) ms", "waveform.path.ecg", .vqPurple)) }
            if let rhr = snap.restingHeartRate { metrics.append(("Resting HR", "\(Int(rhr)) bpm", "heart.fill", .vqOrange)) }
            if let sleep = snap.sleepDurationMinutes { metrics.append(("Sleep", "\(Int(sleep / 60))h \(Int(sleep) % 60)m", "moon.fill", .vqBlue)) }
            return metrics
        case .sleep:
            var metrics: [(String, String, String, Color)] = []
            if let dur = snap.sleepDurationMinutes { metrics.append(("Duration", "\(Int(dur / 60))h \(Int(dur) % 60)m", "clock.fill", .vqBlue)) }
            if let deep = snap.deepSleepMinutes { metrics.append(("Deep Sleep", "\(Int(deep))m", "zzz", .vqPurple)) }
            if let rem = snap.remSleepMinutes { metrics.append(("REM", "\(Int(rem))m", "brain.fill", .vqPink)) }
            if let awake = snap.awakeMinutes { metrics.append(("Awake", "\(Int(awake))m", "eye.fill", .vqOrange)) }
            if let bed = snap.bedtime { metrics.append(("Bedtime", bed.formatted(.dateTime.hour().minute()), "bed.double.fill", .vqCyan)) }
            if let wake = snap.wakeTime { metrics.append(("Wake Time", wake.formatted(.dateTime.hour().minute()), "sunrise.fill", .vqGreen)) }
            return metrics
        case .activity:
            var metrics: [(String, String, String, Color)] = []
            metrics.append(("Steps", formatNumber(snap.steps), "figure.walk", .vqCyan))
            metrics.append(("Calories", "\(Int(snap.activeCalories)) kcal", "flame.fill", .vqPink))
            metrics.append(("Exercise", "\(Int(snap.exerciseMinutes))m", "figure.run", .vqGreen))
            metrics.append(("Stand", "\(Int(snap.standMinutes))m", "figure.stand", .vqOrange))
            if snap.workoutCount > 0 { metrics.append(("Workouts", "\(snap.workoutCount)", "dumbbell.fill", .vqPurple)) }
            if let dist = snap.distanceWalkingRunning { metrics.append(("Distance", String(format: "%.1f km", dist / 1000), "point.bottomleft.forward.to.point.topright.scurvepath.fill", .vqBlue)) }
            return metrics
        }
    }

    private var componentWeights: [String: String] {
        switch scoreType {
        case .recovery:
            return ["hrv_percentile": "30%", "rhr_percentile": "25%", "sleep_quality": "25%", "hrv_trend": "10%", "strain_impact": "10%"]
        case .sleep:
            return ["duration": "30%", "deep_sleep": "20%", "rem_sleep": "15%", "consistency": "15%", "nighttime_hrv": "10%", "sleep_latency": "10%"]
        case .activity:
            return ["calories": "25%", "steps": "20%", "exercise": "20%", "variety": "15%", "consistency": "20%"]
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedMeshBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // Score ring
                        scoreHeader

                        // Component breakdown
                        componentSection

                        // Trend chart
                        trendSection

                        // Related metrics
                        relatedMetricsSection

                        // Tips
                        tipsSection
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(scoreType.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(scoreType.color)
                }
            }
        }
    }

    // MARK: - Score Header

    private var scoreHeader: some View {
        VStack(spacing: 16) {
            ScoreRing(score: score, label: scoreType.rawValue, gradientColors: [scoreType.color, scoreType.color.opacity(0.6)], size: 140, lineWidth: 20, showLabel: false)
                .padding(.top, 8)

            Text(tier.label)
                .font(.vqHeadline)
                .foregroundStyle(scoreType.color)

            Text(scoreType.description)
                .font(.vqCaption)
                .foregroundStyle(Color.vqTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if avgScore > 0 {
                HStack(spacing: 16) {
                    StatPill(label: "Today", value: "\(Int(score))", color: scoreType.color)
                    StatPill(label: "7-Day Avg", value: "\(Int(avgScore))", color: scoreType.color.opacity(0.7))
                    if let best = trendData.map(\.value).max() {
                        StatPill(label: "Best", value: "\(Int(best))", color: .vqGreen)
                    }
                }
            }
        }
        .vqCard()
    }

    // MARK: - Components

    private var componentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Score Breakdown")
                .font(.vqHeadline)
                .foregroundStyle(Color.vqTextPrimary)

            if components.isEmpty {
                Text("No component data available yet.")
                    .font(.vqCaption)
                    .foregroundStyle(Color.vqTextSecondary.opacity(0.6))
            } else {
                ForEach(sortedComponents, id: \.key) { key, value in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(formatComponentName(key))
                                    .font(.vqCaption)
                                    .foregroundStyle(Color.vqTextPrimary)
                                Spacer()
                                if let weight = componentWeights[key] {
                                    Text(weight)
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.vqTextSecondary.opacity(0.5))
                                }
                                Text("\(Int(value))")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(componentColor(value))
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.vqTextPrimary.opacity(0.06))
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [componentColor(value), componentColor(value).opacity(0.5)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * min(value / 100, 1.0))
                                }
                            }
                            .frame(height: 8)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .vqCard()
    }

    // MARK: - Trend

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Trend")
                .font(.vqHeadline)
                .foregroundStyle(Color.vqTextPrimary)

            if trendData.isEmpty {
                Text("Not enough data yet.")
                    .font(.vqCaption)
                    .foregroundStyle(Color.vqTextSecondary.opacity(0.6))
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(trendData, id: \.date) { point in
                    LineMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Score", point.value)
                    )
                    .foregroundStyle(scoreType.color)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Score", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [scoreType.color.opacity(0.3), scoreType.color.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Score", point.value)
                    )
                    .foregroundStyle(scoreType.color)
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
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                            .foregroundStyle(Color.vqTextSecondary.opacity(0.6))
                    }
                }
                .frame(height: 160)
            }
        }
        .vqCard()
    }

    // MARK: - Related Metrics

    private var relatedMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Metrics")
                .font(.vqHeadline)
                .foregroundStyle(Color.vqTextPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(relatedMetrics, id: \.label) { metric in
                    HStack(spacing: 8) {
                        Image(systemName: metric.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(metric.color)
                            .frame(width: 28, height: 28)
                            .background(metric.color.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(metric.label)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.vqTextSecondary)
                            Text(metric.value)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.vqTextPrimary)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.vqTextPrimary.opacity(0.03))
                    )
                }
            }
        }
        .vqCard()
    }

    // MARK: - Tips

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Mascot(mood: score >= 70 ? .happy : .thinking, size: 28)
                Text("Nudge's Take")
                    .font(.vqHeadline)
                    .foregroundStyle(Color.vqTextPrimary)
            }

            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.vqGreen)
                        .padding(.top, 2)
                    Text(tip)
                        .font(.vqCaption)
                        .foregroundStyle(Color.vqTextSecondary)
                }
            }
        }
        .vqCard()
    }

    // MARK: - Helpers

    private var sortedComponents: [(key: String, value: Double)] {
        components
            .filter { $0.key != "total" && $0.key != "status" }
            .sorted { $0.value > $1.value }
    }

    private func componentColor(_ value: Double) -> Color {
        switch value {
        case 80...100: .vqGreen
        case 60..<80: scoreType.color
        case 40..<60: .vqOrange
        default: .vqPink
        }
    }

    private func formatComponentName(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func formatNumber(_ n: Int) -> String {
        n >= 1000 ? String(format: "%.1fK", Double(n) / 1000.0) : "\(n)"
    }

    private var tips: [String] {
        switch scoreType {
        case .recovery:
            if score >= 80 { return ["Your body is well-recovered. Great day for a challenging workout!", "Keep up the good sleep habits that got you here."] }
            if score >= 60 { return ["Moderate intensity today would be ideal.", "Focus on hydration and quality nutrition."] }
            return ["Take it easy today — your body needs time to recover.", "Prioritize sleep tonight and avoid intense exercise."]
        case .sleep:
            if score >= 80 { return ["Excellent sleep! This fuels everything else.", "Keep your bedtime consistent to maintain this."] }
            if score >= 60 { return ["Decent sleep, but there's room to improve.", "Try winding down 30 minutes earlier tonight."] }
            return ["Sleep needs attention — avoid screens before bed.", "A consistent bedtime routine could help a lot."]
        case .activity:
            if score >= 80 { return ["Amazing activity level! You're crushing your goals.", "Make sure to balance this with proper recovery."] }
            if score >= 60 { return ["Good movement today. A short walk could push this higher.", "Try to hit your exercise minutes target."] }
            return ["Let's get moving! Even a 10-minute walk helps.", "Small bursts of activity throughout the day add up."]
        }
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color.vqTextSecondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.08))
        )
    }
}
