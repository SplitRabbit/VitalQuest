import SwiftUI
import SwiftData
import Charts

struct HomeView: View {
    @Environment(HealthKitManager.self) private var healthKitManager
    @Environment(MockHealthKitManager.self) private var mockHealthKitManager
    @Environment(ScoringEngine.self) private var scoringEngine
    @Environment(BaselineEngine.self) private var baselineEngine
    @Environment(XPEngine.self) private var xpEngine
    @Environment(StreakManager.self) private var streakManager
    @Environment(QuestEngine.self) private var questEngine
    @Environment(RawSampleCollector.self) private var rawSampleCollector
    @Environment(FeedService.self) private var feedService
    @Environment(\.modelContext) private var modelContext

    private var activeProvider: HealthKitDataProvider {
        #if targetEnvironment(simulator)
        return mockHealthKitManager
        #else
        return healthKitManager
        #endif
    }

    @State private var viewModel = DashboardViewModel()
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

    private var dayScore: Double {
        guard let snap = viewModel.todaySnapshot else { return 50 }
        let scores = [snap.recoveryScore, snap.sleepScore, snap.activityScore].compactMap { $0 }
        guard !scores.isEmpty else { return 50 }
        return scores.reduce(0, +) / Double(scores.count)
    }

    @State private var showMetricPicker = false
    @State private var showSproutChat = false
    @State private var cachedSproutMessage: String?
    @State private var selectedScoreType: ScoreDetailView.ScoreType?
    @State private var selectedMetricCard: MetricCardData?
    @State private var selectedQuest: Quest?

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedMeshBackground(score: dayScore)

                ScrollView {
                    VStack(spacing: 16) {
                        // Top bar: streak left, date center, profile right
                        ZStack {
                            // Center: date navigator
                            DateNavigator(
                                date: viewModel.selectedDate,
                                isToday: viewModel.isToday,
                                onPrevious: {
                                    viewModel.goToPreviousDay()
                                    Task { await viewModel.refresh() }
                                },
                                onNext: {
                                    viewModel.goToNextDay()
                                    Task { await viewModel.refresh() }
                                },
                                onToday: {
                                    viewModel.goToToday()
                                    Task { await viewModel.refresh() }
                                }
                            )

                            // Left + Right
                            HStack {
                                if let profile = viewModel.profile {
                                    StreakBadge(streak: profile.currentStreak, freezes: profile.streakFreezes, compact: true)
                                }
                                Spacer()
                                HStack(spacing: 8) {
                                    if viewModel.isLoading {
                                        ProgressView().tint(.vqCyan)
                                    }
                                    ProfileButton()
                                }
                            }
                        }
                        .padding(.top, 8)

                        // Greeting
                        HStack {
                            Text(greetingText)
                                .font(.vqTitle)
                                .foregroundStyle(Color.vqTextPrimary)
                            Spacer()
                        }

                        scoresSection
                            .slideIn(appeared: appeared, delay: 0)

                        recentChartsSection
                            .slideIn(appeared: appeared, delay: 0.1)

                        DailyLogCard()
                            .slideIn(appeared: appeared, delay: 0.2)

                        questsSection
                            .slideIn(appeared: appeared, delay: 0.3)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .refreshable {
                    await viewModel.refresh()
                    updateSproutMessage()
                }
                .gesture(
                    DragGesture(minimumDistance: 50)
                        .onEnded { value in
                            // Horizontal swipe to change day (only if more horizontal than vertical)
                            guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                            if value.translation.width < -50 {
                                // Swipe left = next day
                                viewModel.goToNextDay()
                                Task { await viewModel.refresh() }
                            } else if value.translation.width > 50 {
                                // Swipe right = previous day
                                viewModel.goToPreviousDay()
                                Task { await viewModel.refresh() }
                            }
                        }
                )

                // Confetti overlay
                if showConfetti {
                    ConfettiBurst()
                        .allowsHitTesting(false)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showMetricPicker) {
                MetricPickerSheet(profile: viewModel.profile, snapshots: viewModel.recentSnapshots)
            }
            .sheet(isPresented: $showSproutChat) {
                SproutChatView(snapshot: viewModel.todaySnapshot)
            }
            .sheet(item: $selectedScoreType) { scoreType in
                ScoreDetailView(
                    scoreType: scoreType,
                    snapshot: viewModel.todaySnapshot,
                    recentSnapshots: viewModel.recentSnapshots
                )
            }
            .sheet(item: $selectedMetricCard) { card in
                MetricDetailView(
                    metricID: card.id,
                    title: card.title,
                    icon: card.icon,
                    color: card.color,
                    unit: card.unit,
                    higherIsBetter: card.higherIsBetter,
                    recentSnapshots: viewModel.recentSnapshots
                )
            }
            .sheet(item: $selectedQuest) { quest in
                QuestDetailView(quest: quest)
            }
            .onChange(of: viewModel.selectedDate) { _, _ in
                appeared = false
                cachedSproutMessage = nil
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    appeared = true
                }
            }
            .task {
                viewModel.configure(
                    modelContext: modelContext,
                    healthKitManager: activeProvider,
                    scoringEngine: scoringEngine,
                    baselineEngine: baselineEngine,
                    xpEngine: xpEngine,
                    streakManager: streakManager,
                    questEngine: questEngine,
                    rawSampleCollector: rawSampleCollector,
                    feedService: feedService
                )
                await viewModel.refresh()
                updateSproutMessage()

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

    // MARK: - Three scores as horizontal bar chart

    private var scoresSection: some View {
        let snap = viewModel.todaySnapshot
        let scores = [snap?.recoveryScore, snap?.sleepScore, snap?.activityScore].compactMap { $0 }
        let avgScore = scores.isEmpty ? 0.0 : scores.reduce(0, +) / Double(scores.count)

        return VStack(spacing: 14) {
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

            // Mascot + speech (tappable to open chat)
            ZStack(alignment: .topTrailing) {
                Button {
                    showSproutChat = true
                } label: {
                    HStack(spacing: 6) {
                        Mascot(mood: mascotMood, size: 36)
                        Text(sproutMessage)
                            .font(.vqBody)
                            .foregroundStyle(Color.vqTextSecondary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.vqTextPrimary.opacity(0.04))
                    )
                }
                .buttonStyle(.plain)

                if avgScore >= 80 {
                    FloatingHearts(count: 3)
                        .offset(x: 10, y: -15)
                }
            }
        }
    }

    private func scoreBar(_ label: String, score: Double?, icon: String,
                          color: Color, components: [String: Double]?) -> some View {
        let value = score ?? 0

        return Button {
            switch label {
            case "Recovery": selectedScoreType = .recovery
            case "Sleep": selectedScoreType = .sleep
            case "Activity": selectedScoreType = .activity
            default: break
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

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.vqTextSecondary.opacity(0.4))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Metric cards with connected icon strip

    private var metricCards: [MetricCardData] {
        let snaps = viewModel.recentSnapshots
        let enabledOptional = Set(viewModel.profile?.enabledOptionalMetrics ?? [])

        // Build all possible cards, then filter to only those with data
        var candidates: [MetricCardData] = []

        // Default cards
        let weightData = snaps.compactMap { s in s.bodyMass.map { (s.date, $0) } }
        if !weightData.isEmpty {
            candidates.append(MetricCardData(
                id: "weight", title: "Weight", icon: "scalemass.fill", color: .vqGreen, unit: "kg",
                data: weightData, latestValue: snaps.last?.bodyMass, useBars: false, higherIsBetter: false
            ))
        }

        let rhrData = snaps.compactMap { s in s.restingHeartRate.map { (s.date, $0) } }
        if !rhrData.isEmpty {
            candidates.append(MetricCardData(
                id: "rhr", title: "Resting Heart Rate", icon: "heart.fill", color: .vqOrange, unit: "bpm",
                data: rhrData, latestValue: snaps.last?.restingHeartRate, useBars: false, higherIsBetter: false
            ))
        }

        let hrvData = snaps.compactMap { s in s.hrvSDNN.map { (s.date, $0) } }
        if !hrvData.isEmpty {
            candidates.append(MetricCardData(
                id: "hrv", title: "Heart Rate Variability", icon: "waveform.path.ecg", color: .vqPurple, unit: "ms",
                data: hrvData, latestValue: snaps.last?.hrvSDNN, useBars: false
            ))
        }

        let stepsData = snaps.filter { $0.steps > 0 }.map { ($0.date, Double($0.steps)) }
        if !stepsData.isEmpty {
            candidates.append(MetricCardData(
                id: "steps", title: "Steps", icon: "figure.walk", color: .vqCyan, unit: "",
                data: stepsData, latestValue: snaps.last.map { Double($0.steps) }, useBars: true
            ))
        }

        let sleepData = snaps.compactMap { s in s.sleepDurationMinutes.map { (s.date, $0 / 60.0) } }
        if !sleepData.isEmpty {
            candidates.append(MetricCardData(
                id: "sleep", title: "Sleep", icon: "moon.stars.fill", color: .vqBlue, unit: "hrs",
                data: sleepData, latestValue: snaps.last?.sleepDurationMinutes.map { $0 / 60.0 }, useBars: false
            ))
        }

        let calData = snaps.filter { $0.activeCalories > 0 }.map { ($0.date, $0.activeCalories) }
        if !calData.isEmpty {
            candidates.append(MetricCardData(
                id: "calories", title: "Active Calories", icon: "flame.fill", color: .vqPink, unit: "kcal",
                data: calData, latestValue: snaps.last.map { $0.activeCalories }, useBars: true
            ))
        }

        let exData = snaps.filter { $0.exerciseMinutes > 0 }.map { ($0.date, $0.exerciseMinutes) }
        if !exData.isEmpty {
            candidates.append(MetricCardData(
                id: "exercise", title: "Exercise", icon: "figure.run", color: .vqGreen, unit: "min",
                data: exData, latestValue: snaps.last.map { $0.exerciseMinutes }, useBars: true
            ))
        }

        // Optional cards (user-enabled, only if data exists)
        if enabledOptional.contains("distance") {
            let data = snaps.compactMap { s in s.distanceWalkingRunning.map { (s.date, $0 / 1000.0) } }
            if !data.isEmpty {
                candidates.append(MetricCardData(
                    id: "distance", title: "Distance", icon: "figure.walk.motion", color: .vqCyan, unit: "km",
                    data: data, latestValue: snaps.last?.distanceWalkingRunning.map { $0 / 1000.0 }, useBars: false
                ))
            }
        }
        if enabledOptional.contains("flights") {
            let data = snaps.compactMap { s in s.flightsClimbed.map { (s.date, Double($0)) } }
            if !data.isEmpty {
                candidates.append(MetricCardData(
                    id: "flights", title: "Flights Climbed", icon: "figure.stairs", color: .vqOrange, unit: "",
                    data: data, latestValue: snaps.last?.flightsClimbed.map { Double($0) }, useBars: true
                ))
            }
        }
        if enabledOptional.contains("bodyFat") {
            let data = snaps.compactMap { s in s.bodyFatPercentage.map { (s.date, $0 * 100) } }
            if !data.isEmpty {
                candidates.append(MetricCardData(
                    id: "bodyFat", title: "Body Fat", icon: "percent", color: .vqPink, unit: "%",
                    data: data, latestValue: snaps.last?.bodyFatPercentage.map { $0 * 100 }, useBars: false, higherIsBetter: false
                ))
            }
        }
        if enabledOptional.contains("mindful") {
            let data = snaps.compactMap { s in s.mindfulMinutes.map { (s.date, $0) } }
            if !data.isEmpty {
                candidates.append(MetricCardData(
                    id: "mindful", title: "Mindful Minutes", icon: "brain.head.profile.fill", color: .vqPurple, unit: "min",
                    data: data, latestValue: snaps.last?.mindfulMinutes, useBars: true
                ))
            }
        }
        if enabledOptional.contains("vo2Max") {
            let data = snaps.compactMap { s in s.vo2Max.map { (s.date, $0) } }
            if !data.isEmpty {
                candidates.append(MetricCardData(
                    id: "vo2Max", title: "VO2 Max", icon: "lungs.fill", color: .vqBlue, unit: "mL/kg/min",
                    data: data, latestValue: snaps.last?.vo2Max, useBars: false
                ))
            }
        }
        if enabledOptional.contains("spo2") {
            let data = snaps.compactMap { s in s.oxygenSaturation.map { (s.date, $0 * 100) } }
            if !data.isEmpty {
                candidates.append(MetricCardData(
                    id: "spo2", title: "Blood Oxygen", icon: "drop.fill", color: .vqOrange, unit: "%",
                    data: data, latestValue: snaps.last?.oxygenSaturation.map { $0 * 100 }, useBars: false
                ))
            }
        }

        return candidates
    }

    @ViewBuilder
    private var recentChartsSection: some View {
        let cards = metricCards
        if !cards.isEmpty {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Metrics")
                    .font(.vqHeadline)
                    .foregroundStyle(Color.vqTextPrimary)
                Spacer()
                Button {
                    showMetricPicker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.vqGreen)
                        .symbolRenderingMode(.hierarchical)
                }
            }

            MetricCardCarousel(cards: cards, autoRotate: true) { card in
                    selectedMetricCard = card
                }
                .frame(height: 220)
        }
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
                        Button {
                            selectedQuest = quest
                        } label: {
                            CompactQuestRow(quest: quest)
                        }
                        .buttonStyle(.plain)
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
        default: return "Good Evening"
        }
    }

    private var sproutMessage: String {
        if let cached = cachedSproutMessage {
            return cached
        }
        return "Hey! I'm Nudge. Let's do this together!"
    }

    private func updateSproutMessage() {
        let snap = viewModel.todaySnapshot
        let recovery = snap?.recoveryScore ?? 0
        let sleep = snap?.sleepScore ?? 0
        let activity = snap?.activityScore ?? 0
        let trends = SproutDialogue.buildContext(from: viewModel.recentSnapshots)
        cachedSproutMessage = SproutDialogue.pick(recovery: recovery, sleep: sleep, activity: activity, trends: trends)
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

// MARK: - Metric Trend

enum CardTrend {
    case good, neutral, bad

    var color: Color {
        switch self {
        case .good: .vqGreen
        case .neutral: .vqOrange
        case .bad: .vqPink
        }
    }

    var arrow: String {
        switch self {
        case .good: "arrow.up.right"
        case .neutral: "arrow.right"
        case .bad: "arrow.down.right"
        }
    }
}

// MARK: - Metric Card Data

struct MetricCardData: Identifiable {
    let id: String
    let title: String
    let icon: String
    let color: Color
    let unit: String
    let data: [(Date, Double)]
    let latestValue: Double?
    var useBars: Bool = false
    /// Whether higher values are better (true) or lower is better (false, e.g. RHR, weight)
    var higherIsBetter: Bool = true

    /// Compact display value for the icon strip
    var compactValue: String {
        guard let val = latestValue else { return "--" }
        if val >= 10000 { return String(format: "%.0fK", val / 1000) }
        if val >= 1000 { return String(format: "%.1fK", val / 1000) }
        if val == val.rounded() || val >= 100 { return "\(Int(val))" }
        return String(format: "%.1f", val)
    }

    /// Trend based on last 2 data points relative to 7-day average
    var trend: CardTrend {
        guard data.count >= 2, let latest = latestValue else { return .neutral }
        let avg = data.map(\.1).reduce(0, +) / Double(data.count)
        guard avg > 0 else { return .neutral }
        let pctChange = (latest - avg) / avg

        if higherIsBetter {
            if pctChange > 0.05 { return .good }
            if pctChange < -0.05 { return .bad }
        } else {
            if pctChange < -0.02 { return .good }
            if pctChange > 0.05 { return .bad }
        }
        return .neutral
    }
}

// MARK: - Swipeable Card Carousel with Connected Icon Strip

struct MetricCardCarousel: View {
    let cards: [MetricCardData]
    var autoRotate: Bool = false
    var onCardTap: ((MetricCardData) -> Void)?

    @State private var currentIndex: Int = 0
    @GestureState private var dragOffset: CGFloat = 0
    @State private var autoRotateTimer: Timer?
    @State private var userInteracting = false

    var body: some View {
        VStack(spacing: 10) {
            // Connected icon strip with values and trend colors
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                            let isSelected = index == currentIndex
                            let trendColor = card.trend.color

                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    currentIndex = index
                                }
                                resetAutoRotate()
                            } label: {
                                VStack(spacing: 2) {
                                    Image(systemName: card.icon)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(trendColor.opacity(isSelected ? 1 : 0.7))

                                    Text(card.compactValue)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(trendColor.opacity(isSelected ? 1 : 0.7))

                                    HStack(spacing: 1) {
                                        Image(systemName: card.trend.arrow)
                                            .font(.system(size: 7, weight: .bold))
                                            .foregroundStyle(trendColor.opacity(isSelected ? 1 : 0.5))
                                        Text(shortLabel(card.title))
                                            .font(.system(size: 8, weight: .medium, design: .rounded))
                                            .foregroundStyle(trendColor.opacity(isSelected ? 1 : 0.5))
                                    }
                                }
                                .frame(width: 56, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(trendColor.opacity(isSelected ? 0.12 : 0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(trendColor.opacity(isSelected ? 0.3 : 0.1), lineWidth: 1)
                                )
                            }
                            .id(index)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .onChange(of: currentIndex) { _, newIndex in
                    withAnimation(.spring(response: 0.3)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }

            // Card carousel
            GeometryReader { geo in
                let cardWidth = geo.size.width * 0.82
                let spacing: CGFloat = 12
                let totalCardWidth = cardWidth + spacing
                let xOffset = -CGFloat(currentIndex) * totalCardWidth + dragOffset
                    + (geo.size.width - cardWidth) / 2

                HStack(spacing: spacing) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        let distance = abs(CGFloat(index) - CGFloat(currentIndex) - dragOffset / totalCardWidth)
                        let scale = max(0.88, 1 - distance * 0.08)
                        let cardOpacity = max(0.5, 1 - distance * 0.3)

                        MetricCard(card: card)
                            .frame(width: cardWidth)
                            .scaleEffect(scale)
                            .opacity(cardOpacity)
                            .rotation3DEffect(
                                .degrees(Double(CGFloat(index) - CGFloat(currentIndex) - dragOffset / totalCardWidth) * -5),
                                axis: (x: 0, y: 1, z: 0),
                                perspective: 0.5
                            )
                            .onTapGesture {
                                if index == currentIndex {
                                    onCardTap?(card)
                                } else {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        currentIndex = index
                                    }
                                    resetAutoRotate()
                                }
                            }
                    }
                }
                .offset(x: xOffset)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentIndex)
                .animation(.interactiveSpring(), value: dragOffset)
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation.width
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 40
                            if value.translation.width < -threshold && currentIndex < cards.count - 1 {
                                currentIndex += 1
                            } else if value.translation.width > threshold && currentIndex > 0 {
                                currentIndex -= 1
                            }
                            resetAutoRotate()
                        }
                )
            }
        }
        .onAppear {
            if autoRotate { startAutoRotate() }
        }
        .onDisappear {
            autoRotateTimer?.invalidate()
        }
    }

    private func shortLabel(_ title: String) -> String {
        switch title {
        case "Resting Heart Rate": return "RHR"
        case "Heart Rate Variability": return "HRV"
        case "Active Calories": return "Cal"
        case "Mindful Minutes": return "Mind"
        case "Blood Oxygen": return "SpO2"
        case "Flights Climbed": return "Flights"
        case "Body Fat": return "Fat %"
        default: return title
        }
    }

    private func startAutoRotate() {
        autoRotateTimer?.invalidate()
        autoRotateTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                currentIndex = (currentIndex + 1) % max(1, cards.count)
            }
        }
    }

    private func resetAutoRotate() {
        guard autoRotate else { return }
        autoRotateTimer?.invalidate()
        // Restart after a pause
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            startAutoRotate()
        }
    }
}

// MARK: - Single Metric Card

struct MetricCard: View {
    let card: MetricCardData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: card.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(card.color)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(card.color.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(card.title)
                        .font(.vqSubheadline)
                        .foregroundStyle(Color.vqTextPrimary)
                    if let val = card.latestValue {
                        Text(formatValue(val) + (card.unit.isEmpty ? "" : " \(card.unit)"))
                            .font(.vqScoreSmall)
                            .foregroundStyle(card.color)
                    }
                }

                Spacer()
            }

            // Chart
            if card.data.count >= 2 {
                Chart(card.data, id: \.0) { point in
                    if card.useBars {
                        BarMark(
                            x: .value("Day", point.0, unit: .day),
                            y: .value("Value", point.1)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [card.color, card.color.opacity(0.4)],
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
                        .foregroundStyle(card.color.gradient)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Day", point.0, unit: .day),
                            y: .value("Value", point.1)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [card.color.opacity(0.2), card.color.opacity(0.0)],
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
            } else {
                Text("Not enough data yet")
                    .font(.vqCaption)
                    .foregroundStyle(Color.vqTextSecondary.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.vqCardBackground)
                .shadow(color: card.color.opacity(0.12), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(card.color.opacity(0.2), lineWidth: 1)
        )
    }

    private func formatValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fK", value / 1000)
        }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }
}

// MARK: - Date Navigator

struct DateNavigator: View {
    let date: Date
    let isToday: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.vqTextSecondary)
            }

            VStack(spacing: 1) {
                if isToday {
                    Text("Today")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.vqTextPrimary)
                } else {
                    Button(action: onToday) {
                        Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.vqTextPrimary)
                    }
                }

                Text(date.formatted(.dateTime.month(.wide).day().year()))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.vqTextSecondary.opacity(0.6))
            }

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isToday ? Color.vqTextSecondary.opacity(0.2) : Color.vqTextSecondary)
            }
            .disabled(isToday)
        }
    }
}

// MARK: - Metric Picker Sheet

struct MetricPickerSheet: View {
    let profile: UserProfile?
    let snapshots: [DailySnapshot]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let allOptionalMetrics: [(id: String, title: String, icon: String, color: Color, description: String, hasData: ([DailySnapshot]) -> Bool)] = [
        ("distance", "Distance", "figure.walk.motion", .vqCyan, "Walking + running distance", { $0.contains { $0.distanceWalkingRunning != nil } }),
        ("flights", "Flights Climbed", "figure.stairs", .vqOrange, "Stair flights per day", { $0.contains { $0.flightsClimbed != nil } }),
        ("bodyFat", "Body Fat %", "percent", .vqPink, "Body fat percentage", { $0.contains { $0.bodyFatPercentage != nil } }),
        ("mindful", "Mindful Minutes", "brain.head.profile.fill", .vqPurple, "Meditation & mindfulness", { $0.contains { $0.mindfulMinutes != nil } }),
        ("vo2Max", "VO2 Max", "lungs.fill", .vqBlue, "Cardio fitness level", { $0.contains { $0.vo2Max != nil } }),
        ("spo2", "Blood Oxygen", "drop.fill", .vqOrange, "Overnight SpO2 levels", { $0.contains { $0.oxygenSaturation != nil } }),
    ]

    private var availableMetrics: [(id: String, title: String, icon: String, color: Color, description: String)] {
        allOptionalMetrics
            .filter { $0.hasData(snapshots) }
            .map { ($0.id, $0.title, $0.icon, $0.color, $0.description) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedMeshBackground()

                List {
                    Section {
                        if availableMetrics.isEmpty {
                            Text("No additional metric data found yet. Wear your Apple Watch to collect more data.")
                                .font(.vqCaption)
                                .foregroundStyle(Color.vqTextSecondary.opacity(0.6))
                                .padding(.vertical, 8)
                        }
                        ForEach(availableMetrics, id: \.id) { metric in
                            let isEnabled = profile?.enabledOptionalMetrics.contains(metric.id) ?? false
                            Button {
                                toggleMetric(metric.id)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: metric.icon)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(metric.color)
                                        .frame(width: 34, height: 34)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(metric.color.opacity(0.12))
                                        )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(metric.title)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(Color.vqTextPrimary)
                                        Text(metric.description)
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.vqTextSecondary.opacity(0.7))
                                    }

                                    Spacer()

                                    Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundStyle(isEnabled ? Color.vqGreen : Color.vqTextSecondary.opacity(0.3))
                                }
                            }
                        }
                    } header: {
                        Text("Available Metrics")
                    } footer: {
                        Text("Toggle metrics to add or remove them from your dashboard cards.")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Metrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.vqGreen)
                }
            }
        }
    }

    private func toggleMetric(_ id: String) {
        guard let profile else { return }
        if let index = profile.enabledOptionalMetrics.firstIndex(of: id) {
            profile.enabledOptionalMetrics.remove(at: index)
        } else {
            profile.enabledOptionalMetrics.append(id)
        }
        try? modelContext.save()
    }
}

#Preview {
    HomeView()
        .withMockEnvironment()
}
