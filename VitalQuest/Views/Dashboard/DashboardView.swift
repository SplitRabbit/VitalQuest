import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(HealthKitManager.self) private var healthKitManager
    @Environment(ScoringEngine.self) private var scoringEngine
    @Environment(BaselineEngine.self) private var baselineEngine
    @Environment(XPEngine.self) private var xpEngine
    @Environment(StreakManager.self) private var streakManager
    @Environment(QuestEngine.self) private var questEngine
    @Environment(RawSampleCollector.self) private var rawSampleCollector
    @Environment(FeedService.self) private var feedService
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = DashboardViewModel()
    @State private var showingAuthPrompt = false

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedMeshBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        // Greeting header
                        greetingHeader

                        // XP Bar
                        if let profile = viewModel.profile {
                            XPBar(
                                level: profile.level,
                                progress: profile.levelProgress,
                                xpToNext: profile.xpToNextLevel,
                                title: profile.title
                            )
                        }

                        // Score rings grid
                        scoreRingsSection

                        // Streak + quick metrics
                        HStack(spacing: 12) {
                            if let profile = viewModel.profile {
                                StreakBadge(streak: profile.currentStreak, freezes: profile.streakFreezes)
                            }
                            Spacer()
                            if viewModel.xpGainedThisSession > 0 {
                                XPGainBubble(amount: viewModel.xpGainedThisSession, source: "Today")
                            }
                        }

                        // Today's metrics pills
                        if let snap = viewModel.todaySnapshot {
                            metricsRow(snap)
                        }

                        // Active quests
                        if !viewModel.activeQuests.isEmpty {
                            questsSection
                        }

                        // Achievement unlocks
                        if !viewModel.recentUnlocks.isEmpty {
                            unlockBanner
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal)
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .task {
                viewModel.configure(
                    modelContext: modelContext,
                    healthKitManager: healthKitManager,
                    scoringEngine: scoringEngine,
                    baselineEngine: baselineEngine,
                    xpEngine: xpEngine,
                    streakManager: streakManager,
                    questEngine: questEngine,
                    rawSampleCollector: rawSampleCollector,
                    feedService: feedService
                )
                await viewModel.refresh()
            }
            .alert("Health Data Access", isPresented: $showingAuthPrompt) {
                Button("Open Settings", role: .none) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Later", role: .cancel) {}
            } message: {
                Text("Nudge needs access to your health data to calculate scores. Please enable access in Settings.")
            }
        }
    }

    // MARK: - Subviews

    private var greetingHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(.vqTitle)
                    .foregroundStyle(Color.vqTextPrimary)
                Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.vqBody)
                    .foregroundStyle(Color.vqTextSecondary.opacity(0.7))
            }
            Spacer()
            if viewModel.isLoading {
                ProgressView()
                    .tint(.vqCyan)
            }
        }
        .padding(.top, 8)
    }

    private var scoreRingsSection: some View {
        let snap = viewModel.todaySnapshot
        return VStack(spacing: 12) {
            HStack(spacing: 16) {
                ScoreRing(
                    score: snap?.recoveryScore ?? 0,
                    label: "Recovery",
                    gradientColors: Color.recoveryGradientColors,
                    size: 140, lineWidth: 12
                )
                ScoreRing(
                    score: snap?.sleepScore ?? 0,
                    label: "Sleep",
                    gradientColors: Color.sleepGradientColors,
                    size: 140, lineWidth: 12
                )
            }
            HStack(spacing: 16) {
                ScoreRing(
                    score: snap?.activityScore ?? 0,
                    label: "Activity",
                    gradientColors: Color.activityGradientColors,
                    size: 140, lineWidth: 12
                )
            }
        }
        .vqCard()
    }

    private func metricsRow(_ snap: DailySnapshot) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                MetricPill(icon: "figure.walk", label: "Steps", value: formatNumber(snap.steps), color: .vqCyan)
                MetricPill(icon: "flame.fill", label: "Calories", value: "\(Int(snap.activeCalories))", color: .vqPink)
                MetricPill(icon: "figure.run", label: "Exercise", value: "\(Int(snap.exerciseMinutes))m", color: .vqGreen)
                if let rhr = snap.restingHeartRate {
                    MetricPill(icon: "heart.fill", label: "RHR", value: "\(Int(rhr))", color: .vqOrange)
                }
                if let hrv = snap.hrvSDNN {
                    MetricPill(icon: "waveform.path.ecg", label: "HRV", value: "\(Int(hrv))", color: .vqPurple)
                }
                if let sleep = snap.sleepDurationMinutes {
                    let hours = Int(sleep) / 60
                    let mins = Int(sleep) % 60
                    MetricPill(icon: "moon.fill", label: "Sleep", value: "\(hours)h\(mins)m", color: .vqBlue)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var questsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "scroll.fill")
                    .foregroundStyle(Color.vqCyan)
                Text("Active Quests")
                    .font(.vqHeadline)
                    .foregroundStyle(Color.vqTextPrimary)
                Spacer()
            }

            ForEach(viewModel.activeQuests.prefix(3), id: \.id) { quest in
                QuestCard(quest: quest)
            }
        }
    }

    private var unlockBanner: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(Color.vqYellow)
                Text("Achievement Unlocked!")
                    .font(.vqHeadline)
                    .foregroundStyle(Color.vqYellow)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.vqYellow.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.vqYellow.opacity(0.3), lineWidth: 1.5)
            )
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

    private func formatNumber(_ n: Int) -> String {
        if n >= 1000 {
            return String(format: "%.1fK", Double(n) / 1000.0)
        }
        return "\(n)"
    }
}

#Preview {
    DashboardView()
        .withMockEnvironment()
}
