import SwiftUI
import SwiftData
import Charts

struct HistoryView: View {
    @Query(sort: \DailySnapshot.date, order: .reverse) private var snapshots: [DailySnapshot]

    @State private var selectedMetric: HistoryMetric = .recovery
    @State private var selectedSnapshot: DailySnapshot?

    enum HistoryMetric: String, CaseIterable {
        case recovery = "Recovery"
        case sleep = "Sleep"
        case activity = "Activity"
        case steps = "Steps"
        case hrv = "HRV"
        case rhr = "Resting HR"

        var color: Color {
            switch self {
            case .recovery: .vqGreen
            case .sleep: .vqPurple
            case .activity: .vqPink
            case .steps: .vqBlue
            case .hrv: .vqOrange
            case .rhr: .vqPink
            }
        }

        var icon: String {
            switch self {
            case .recovery: "bolt.heart.fill"
            case .sleep: "moon.stars.fill"
            case .activity: "figure.run"
            case .steps: "figure.walk"
            case .hrv: "waveform.path.ecg"
            case .rhr: "heart.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedMeshBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // Metric picker
                        metricPicker

                        // Trend chart
                        trendChartSection

                        // Calendar heat map
                        calendarHeatMap

                        // Day detail (when selected)
                        if let snap = selectedSnapshot {
                            dayDetailCard(snap)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileButton()
                }
            }
        }
    }

    // MARK: - Metric Picker

    private var metricPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(HistoryMetric.allCases, id: \.self) { metric in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedMetric = metric
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: metric.icon)
                                .font(.system(size: 12, weight: .semibold))
                            Text(metric.rawValue)
                                .font(.vqCaption)
                        }
                        .foregroundStyle(selectedMetric == metric ? Color.vqTextPrimary : Color.vqTextSecondary.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedMetric == metric ? metric.color.opacity(0.25) : Color.vqTextPrimary.opacity(0.04))
                        )
                        .overlay(
                            Capsule()
                                .stroke(selectedMetric == metric ? metric.color.opacity(0.5) : .clear, lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Chart

    private var trendChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("7-Day Trend")
                    .font(.vqHeadline)
                    .foregroundStyle(Color.vqTextPrimary)
                Spacer()
                if let avg = averageValue(days: 7) {
                    Text("Avg: \(formatValue(avg))")
                        .font(.vqCaption)
                        .foregroundStyle(selectedMetric.color)
                }
            }

            let data = chartData(days: 7)
            if data.isEmpty {
                VStack(spacing: 12) {
                    Mascot(mood: .thinking, size: 50)
                    Text("Start tracking to see your trends!")
                        .font(.vqBody)
                        .foregroundStyle(Color.vqTextSecondary.opacity(0.6))
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            } else {
                Chart(data, id: \.date) { point in
                    BarMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [selectedMetric.color, selectedMetric.color.opacity(0.5)],
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
                .frame(height: 200)
            }
        }
        .vqCard()
    }

    // MARK: - Calendar Heat Map

    private var calendarHeatMap: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 28 Days")
                .font(.vqHeadline)
                .foregroundStyle(Color.vqTextPrimary)

            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let days = (0..<28).map { offset in
                calendar.date(byAdding: .day, value: -offset, to: today)!
            }.reversed()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(days), id: \.self) { date in
                    let snapshot = snapshotFor(date: date)
                    let value = snapshot.flatMap { metricValue($0) } ?? 0

                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(heatColor(value: value))
                        .frame(height: 32)
                        .overlay {
                            if calendar.isDateInToday(date) {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.vqTextSecondary.opacity(0.7), lineWidth: 1.5)
                            }
                        }
                        .overlay {
                            Text("\(calendar.component(.day, from: date))")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.vqTextPrimary.opacity(value > 0 ? 0.8 : 0.3))
                        }
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                selectedSnapshot = snapshot
                            }
                        }
                }
            }

            // Legend
            HStack(spacing: 4) {
                Text("Low")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.vqTextSecondary.opacity(0.6))
                ForEach([0.2, 0.4, 0.6, 0.8, 1.0], id: \.self) { intensity in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(selectedMetric.color.opacity(intensity))
                        .frame(width: 14, height: 14)
                }
                Text("High")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.vqTextSecondary.opacity(0.6))
            }
        }
        .vqCard()
    }

    // MARK: - Day Detail

    private func dayDetailCard(_ snap: DailySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(snap.date.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.vqHeadline)
                    .foregroundStyle(Color.vqTextPrimary)
                Spacer()
                Button {
                    withAnimation { selectedSnapshot = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.vqTextSecondary.opacity(0.6))
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                if let r = snap.recoveryScore {
                    ScoreBadge(score: r, label: "Recovery", icon: "bolt.heart.fill", color: .vqGreen)
                }
                if let s = snap.sleepScore {
                    ScoreBadge(score: s, label: "Sleep", icon: "moon.stars.fill", color: .vqPurple)
                }
                if let a = snap.activityScore {
                    ScoreBadge(score: a, label: "Activity", icon: "figure.run", color: .vqPink)
                }
            }

            Divider().background(Color.vqTextPrimary.opacity(0.08))

            MetricRow(icon: "figure.walk", label: "Steps", value: "\(snap.steps)", color: .vqCyan)
            MetricRow(icon: "flame.fill", label: "Calories", value: "\(Int(snap.activeCalories)) kcal", color: .vqPink)
            if let sleep = snap.sleepDurationMinutes {
                MetricRow(icon: "moon.fill", label: "Sleep", value: "\(Int(sleep / 60))h \(Int(sleep) % 60)m", color: .vqBlue)
            }
            if let rhr = snap.restingHeartRate {
                MetricRow(icon: "heart.fill", label: "Resting HR", value: "\(Int(rhr)) bpm", color: .vqOrange)
            }
            if let hrv = snap.hrvSDNN {
                MetricRow(icon: "waveform.path.ecg", label: "HRV", value: "\(Int(hrv)) ms", color: .vqPurple)
            }
        }
        .vqGlowCard(color: selectedMetric.color)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Helpers

    struct ChartPoint {
        let date: Date
        let value: Double
    }

    private func metricValue(_ snap: DailySnapshot) -> Double? {
        switch selectedMetric {
        case .recovery: return snap.recoveryScore
        case .sleep: return snap.sleepScore
        case .activity: return snap.activityScore
        case .steps: return Double(snap.steps)
        case .hrv: return snap.hrvSDNN
        case .rhr: return snap.restingHeartRate
        }
    }

    private func chartData(days: Int) -> [ChartPoint] {
        snapshots.prefix(days).reversed().compactMap { snap in
            guard let value = metricValue(snap) else { return nil }
            return ChartPoint(date: snap.date, value: value)
        }
    }

    private func averageValue(days: Int) -> Double? {
        let values = snapshots.prefix(days).compactMap { metricValue($0) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func formatValue(_ value: Double) -> String {
        switch selectedMetric {
        case .steps: return "\(Int(value))"
        case .hrv: return "\(Int(value)) ms"
        case .rhr: return "\(Int(value)) bpm"
        default: return "\(Int(value))"
        }
    }

    private func snapshotFor(date: Date) -> DailySnapshot? {
        let calendar = Calendar.current
        return snapshots.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func heatColor(value: Double) -> Color {
        guard value > 0 else { return Color.vqTextPrimary.opacity(0.03) }
        let maxVal: Double = switch selectedMetric {
        case .steps: 15000
        case .hrv: 80
        case .rhr: 100
        default: 100
        }
        let intensity = min(value / maxVal, 1.0)
        return selectedMetric.color.opacity(0.15 + intensity * 0.75)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: DailySnapshot.self, inMemory: true)
        .withMockEnvironment()
}
