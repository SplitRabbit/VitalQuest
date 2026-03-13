import SwiftUI
import SwiftData
import Charts

struct HomeView: View {
    @Environment(HealthKitManager.self) private var healthKitManager
    @Environment(ScoringEngine.self) private var scoringEngine
    @Environment(BaselineEngine.self) private var baselineEngine
    @Environment(XPEngine.self) private var xpEngine
    @Environment(StreakManager.self) private var streakManager
    @Environment(QuestEngine.self) private var questEngine
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = DashboardViewModel()
    @State private var expandedScore: String?
    @State private var appeared = false
    @State private var showConfetti = false

    private var mascotMood: MascotMood {
        guard let snap = viewModel.todaySnapshot else { return .thinking }
        let avg = [snap.recoveryScore, snap.sleepScore, snap.activityScore]
            .compactMap { $0 }
            .reduce(0, +) / max(1, Double([snap.recoveryScore, snap.sleepScore, snap.activityScore].compactMap { $0 }.count))
        switch avg {
        case 80...100: return .cheering
        case 60..<80: return .happy
        case 40..<60: return .thinking
        case 1..<40: return .tired
        default: return .sleepy
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedMeshBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        headerRow
                            .slideIn(appeared: appeared, delay: 0)

                        xpSection
                            .slideIn(appeared: appeared, delay: 0.05)

                        scoresSection
                            .slideIn(appeared: appeared, delay: 0.1)

                        metricsStrip
                            .slideIn(appeared: appeared, delay: 0.2)

                        recentChartsSection
                            .slideIn(appeared: appeared, delay: 0.25)

                        questsSection
                            .slideIn(appeared: appeared, delay: 0.3)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
                .refreshable {
                    await viewModel.refresh()
                }

                // Confetti overlay
                if showConfetti {
                    ConfettiBurst()
                        .allowsHitTesting(false)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileButton()
                }
            }
            .task {
                viewModel.configure(
                    modelContext: modelContext,
                    healthKitManager: healthKitManager,
                    scoringEngine: scoringEngine,
                    baselineEngine: baselineEngine,
                    xpEngine: xpEngine,
                    streakManager: streakManager,
                    questEngine: questEngine
                )
                await viewModel.refresh()

                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    appeared = true
                }

                // Confetti if great day
                if let snap = viewModel.todaySnapshot,
                   (snap.recoveryScore ?? 0) >= 85 {
                    showConfetti = true
                }
            }
        }
    }

    // MARK: - Header: greeting + mascot + streak

    private var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(greetingText)
                    .font(.vqTitle)
                    .foregroundStyle(Color.vqTextPrimary)
                Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.vqCaption)
                    .foregroundStyle(Color.vqTextSecondary.opacity(0.7))
            }
            Spacer()
            if let profile = viewModel.profile {
                StreakBadge(streak: profile.currentStreak, freezes: profile.streakFreezes, compact: true)
            }
            if viewModel.isLoading {
                ProgressView().tint(.vqCyan)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - XP bar

    private var xpSection: some View {
        Group {
            if let profile = viewModel.profile {
                XPBar(
                    level: profile.level,
                    progress: profile.levelProgress,
                    xpToNext: profile.xpToNextLevel,
                    title: profile.title
                )
            }
        }
    }

    // MARK: - Three scores as horizontal bar chart

    private var scoresSection: some View {
        let snap = viewModel.todaySnapshot
        let scores = [snap?.recoveryScore, snap?.sleepScore, snap?.activityScore].compactMap { $0 }
        let avgScore = scores.isEmpty ? 0.0 : scores.reduce(0, +) / Double(scores.count)
        let tier = DailySnapshot.scoreTier(avgScore)

        return VStack(spacing: 14) {
            // Mascot + speech
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 6) {
                    Mascot(mood: mascotMood, size: 36)
                    Text(mascotSpeech(tier))
                        .font(.vqBody)
                        .foregroundStyle(Color.vqTextSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.vqTextPrimary.opacity(0.04))
                )

                if avgScore >= 80 {
                    FloatingHearts(count: 3)
                        .offset(x: 10, y: -15)
                }
            }

            // Horizontal bar chart
            VStack(spacing: 12) {
                scoreBar("Recovery", score: snap?.recoveryScore, icon: "bolt.heart.fill",
                         color: .vqGreen, components: snap?.recoveryComponents)
                scoreBar("Sleep", score: snap?.sleepScore, icon: "moon.stars.fill",
                         color: .vqBlue, components: snap?.sleepComponents)
                scoreBar("Activity", score: snap?.activityScore, icon: "figure.run",
                         color: .vqPink, components: snap?.activityComponents)
            }
            .vqCard()
        }
    }

    private func scoreBar(_ label: String, score: Double?, icon: String,
                          color: Color, components: [String: Double]?) -> some View {
        let value = score ?? 0
        let isExpanded = expandedScore == label

        return VStack(spacing: 4) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    expandedScore = isExpanded ? nil : label
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(color)
                        .frame(width: 24)

                    Text(label)
                        .font(.vqCaption)
                        .foregroundStyle(Color.vqTextSecondary)
                        .frame(width: 62, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.vqTextPrimary.opacity(0.06))

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [color, color.opacity(0.6)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, geo.size.width * value / 100))
                                .shadow(color: color.opacity(0.3), radius: 4)
                        }
                    }
                    .frame(height: 14)
                    .clipShape(Capsule())

                    Text("\(Int(value))")
                        .font(.vqSubheadline)
                        .foregroundStyle(DailySnapshot.scoreTier(value).color)
                        .frame(width: 32, alignment: .trailing)
                        .contentTransition(.numericText(value: value))

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.vqTextSecondary.opacity(0.4))
                }
            }
            .buttonStyle(.plain)

            if isExpanded, let comps = components {
                VStack(spacing: 6) {
                    ForEach(comps.sorted(by: { $0.key < $1.key }), id: \.key) { key, val in
                        if key != "total" && key != "status" {
                            ScoreComponentRow(
                                label: formatComponentName(key),
                                value: val,
                                weight: "",
                                color: color
                            )
                        }
                    }
                }
                .padding(.leading, 34)
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Today's key metrics

    private var metricsStrip: some View {
        let snap = viewModel.todaySnapshot
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let snap {
                    MetricPill(icon: "figure.walk", label: "Steps", value: formatNumber(snap.steps), color: .vqCyan)
                    MetricPill(icon: "flame.fill", label: "Cal", value: "\(Int(snap.activeCalories))", color: .vqPink)
                    MetricPill(icon: "figure.run", label: "Move", value: "\(Int(snap.exerciseMinutes))m", color: .vqGreen)
                    if let rhr = snap.restingHeartRate {
                        MetricPill(icon: "heart.fill", label: "RHR", value: "\(Int(rhr))", color: .vqOrange)
                    }
                    if let hrv = snap.hrvSDNN {
                        MetricPill(icon: "waveform.path.ecg", label: "HRV", value: "\(Int(hrv))", color: .vqBlue)
                    }
                    if let sleep = snap.sleepDurationMinutes {
                        let h = Int(sleep) / 60, m = Int(sleep) % 60
                        MetricPill(icon: "moon.fill", label: "Sleep", value: "\(h)h\(m)m", color: .vqBlue)
                    }
                }
            }
        }
    }

    // MARK: - Recent measurement charts

    private var recentChartsSection: some View {
        let snaps = viewModel.recentSnapshots

        return VStack(spacing: 12) {
            // Resting Heart Rate
            MiniTrendChart(
                title: "Resting Heart Rate",
                icon: "heart.fill",
                color: .vqOrange,
                unit: "bpm",
                data: snaps.compactMap { s in
                    s.restingHeartRate.map { (s.date, $0) }
                },
                latestValue: snaps.last?.restingHeartRate
            )

            // HRV
            MiniTrendChart(
                title: "Heart Rate Variability",
                icon: "waveform.path.ecg",
                color: .vqPurple,
                unit: "ms",
                data: snaps.compactMap { s in
                    s.hrvSDNN.map { (s.date, $0) }
                },
                latestValue: snaps.last?.hrvSDNN
            )

            // Steps
            MiniTrendChart(
                title: "Steps",
                icon: "figure.walk",
                color: .vqCyan,
                unit: "",
                data: snaps.map { (s: DailySnapshot) -> (Date, Double) in (s.date, Double(s.steps)) },
                latestValue: snaps.last.map { Double($0.steps) },
                useBars: true
            )

            // Sleep Duration
            MiniTrendChart(
                title: "Sleep",
                icon: "moon.stars.fill",
                color: .vqBlue,
                unit: "hrs",
                data: snaps.compactMap { s in
                    s.sleepDurationMinutes.map { (s.date, $0 / 60.0) }
                },
                latestValue: snaps.last?.sleepDurationMinutes.map { $0 / 60.0 }
            )

            // Active Calories
            MiniTrendChart(
                title: "Active Calories",
                icon: "flame.fill",
                color: .vqPink,
                unit: "kcal",
                data: snaps.map { (s: DailySnapshot) -> (Date, Double) in (s.date, s.activeCalories) },
                latestValue: snaps.last.map { $0.activeCalories },
                useBars: true
            )

            // Exercise Minutes
            MiniTrendChart(
                title: "Exercise",
                icon: "figure.run",
                color: .vqGreen,
                unit: "min",
                data: snaps.map { (s: DailySnapshot) -> (Date, Double) in (s.date, s.exerciseMinutes) },
                latestValue: snaps.last.map { $0.exerciseMinutes },
                useBars: true
            )
        }
    }

    // MARK: - Active quests

    private var questsSection: some View {
        Group {
            if !viewModel.activeQuests.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Quests")
                            .font(.vqHeadline)
                            .foregroundStyle(Color.vqTextPrimary)
                        Spacer()
                        Mascot(mood: .happy, size: 28)
                    }

                    ForEach(Array(viewModel.activeQuests.prefix(3).enumerated()), id: \.element.id) { index, quest in
                        CompactQuestRow(quest: quest)
                            .slideIn(appeared: appeared, delay: 0.3 + Double(index) * 0.08)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
        default: return "Night Owl"
        }
    }

    private func mascotSpeech(_ tier: ScoreTier) -> String {
        switch tier {
        case .excellent: return "You're amazing today! Let's gooo!"
        case .good: return "Looking good! Keep it up!"
        case .fair: return "Not bad — a walk might help!"
        case .low: return "Rest up, I believe in you!"
        }
    }

    private func formatNumber(_ n: Int) -> String {
        n >= 1000 ? String(format: "%.1fK", Double(n) / 1000.0) : "\(n)"
    }

    private func formatComponentName(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// MARK: - Slide-In Animation Modifier

struct SlideInModifier: ViewModifier {
    let appeared: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .offset(y: appeared ? 0 : 30)
            .opacity(appeared ? 1 : 0)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.75).delay(delay),
                value: appeared
            )
    }
}

extension View {
    func slideIn(appeared: Bool, delay: Double = 0) -> some View {
        modifier(SlideInModifier(appeared: appeared, delay: delay))
    }
}

// MARK: - Compact Quest Row

struct CompactQuestRow: View {
    let quest: Quest

    @State private var animatedProgress: Double = 0
    @State private var completePop = false

    private var questColor: Color {
        switch quest.type {
        case .daily: .vqCyan
        case .weekly: .vqGreen
        case .epic: .vqYellow
        }
    }

    private var questIcon: String {
        switch quest.metric {
        case "steps": "figure.walk"
        case "activeCalories": "flame.fill"
        case "exerciseMinutes": "figure.run"
        case "standMinutes": "figure.stand"
        case "sleepScore": "moon.stars.fill"
        case "recoveryScore": "bolt.heart.fill"
        default: "scroll.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Animated icon
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(questColor.opacity(0.15))
                    .frame(width: 38, height: 38)

                Image(systemName: quest.status == .completed ? "checkmark" : questIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(quest.status == .completed ? Color.vqGreen : questColor)
                    .scaleEffect(completePop ? 1.3 : 1.0)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(quest.title)
                    .font(.vqQuestTitle)
                    .foregroundStyle(Color.vqTextPrimary)
                    .lineLimit(1)
                    .strikethrough(quest.status == .completed, color: Color.vqTextSecondary.opacity(0.4))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.vqTextPrimary.opacity(0.06))
                        Capsule()
                            .fill(
                                quest.status == .completed
                                    ? Color.vqGreen
                                    : questColor.opacity(0.8)
                            )
                            .frame(width: max(0, geo.size.width * animatedProgress))
                    }
                }
                .frame(height: 6)
                .clipShape(Capsule())
            }

            Text("\(Int(quest.progress * 100))%")
                .font(.vqCaption)
                .foregroundStyle(quest.status == .completed ? Color.vqGreen : questColor)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.vqCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    quest.status == .completed ? Color.vqGreen.opacity(0.3) : questColor.opacity(0.15),
                    lineWidth: 1
                )
        )
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
                animatedProgress = quest.progress
            }
            if quest.status == .completed {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.4).delay(0.3)) {
                    completePop = true
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.5)) {
                    completePop = false
                }
            }
        }
    }
}

// MARK: - Mini Trend Chart

struct MiniTrendChart: View {
    let title: String
    let icon: String
    let color: Color
    let unit: String
    let data: [(Date, Double)]
    let latestValue: Double?
    var useBars: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)

                Text(title)
                    .font(.vqCaption)
                    .foregroundStyle(Color.vqTextSecondary)

                Spacer()

                if let val = latestValue {
                    Text(formatChartValue(val) + (unit.isEmpty ? "" : " \(unit)"))
                        .font(.vqSubheadline)
                        .foregroundStyle(Color.vqTextPrimary)
                }
            }

            // Chart
            if data.count >= 2 {
                Chart(data, id: \.0) { point in
                    if useBars {
                        BarMark(
                            x: .value("Day", point.0, unit: .day),
                            y: .value("Value", point.1)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [color, color.opacity(0.5)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(4)
                    } else {
                        LineMark(
                            x: .value("Day", point.0, unit: .day),
                            y: .value("Value", point.1)
                        )
                        .foregroundStyle(color.gradient)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Day", point.0, unit: .day),
                            y: .value("Value", point.1)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [color.opacity(0.2), color.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                            .foregroundStyle(Color.vqTextSecondary.opacity(0.5))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                        AxisValueLabel()
                            .foregroundStyle(Color.vqTextSecondary.opacity(0.4))
                    }
                }
                .frame(height: 100)
            } else {
                Text("Not enough data yet")
                    .font(.vqCaption)
                    .foregroundStyle(Color.vqTextSecondary.opacity(0.5))
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
            }
        }
        .vqCard()
    }

    private func formatChartValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fK", value / 1000)
        }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }
}

#Preview {
    HomeView()
        .withMockEnvironment()
}
