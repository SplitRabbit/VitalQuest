import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var profiles: [UserProfile]
    @Query private var achievements: [Achievement]
    @Environment(StreakManager.self) private var streakManager

    private var profile: UserProfile? { profiles.first }

    @State private var selectedCategory: AchievementCategory?

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedMeshBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // Level card
                        levelCard

                        // Stats grid
                        statsGrid

                        // Streak section
                        streakSection

                        // Achievements
                        achievementsSection

                        // Settings
                        settingsSection

                        // Disclaimer
                        disclaimerSection

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Level Card

    private var levelCard: some View {
        VStack(spacing: 16) {
            // Mascot as avatar
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.vqGreen.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 70
                        )
                    )
                    .frame(width: 130, height: 130)

                Mascot(mood: .cheering, size: 80)

                // Level badge
                ZStack {
                    Circle()
                        .fill(LinearGradient.brand)
                        .frame(width: 36, height: 36)
                        .shadow(color: .vqGreen.opacity(0.5), radius: 8)

                    Text("\(profile?.level ?? 1)")
                        .font(.vqLevel)
                        .foregroundStyle(Color.vqTextPrimary)
                }
                .offset(x: 40, y: 35)
            }

            Text(profile?.title ?? "Novice")
                .font(.vqTitle)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.vqGreen, .vqCyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            if let profile {
                XPBar(
                    level: profile.level,
                    progress: profile.levelProgress,
                    xpToNext: profile.xpToNextLevel,
                    title: "\(profile.totalXP) Total XP"
                )
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Stats

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            statCell(icon: "calendar", label: "Days Tracked", value: "\(profile?.totalDaysTracked ?? 0)", color: .vqCyan)
            statCell(icon: "checkmark.circle", label: "Quests Done", value: "\(profile?.totalQuestsCompleted ?? 0)", color: .vqGreen)
            statCell(icon: "flame.fill", label: "Best Streak", value: "\(profile?.longestStreak ?? 0)", color: .vqOrange)
            statCell(icon: "sparkles", label: "Total XP", value: formatXP(profile?.totalXP ?? 0), color: .vqYellow)
        }
    }

    private func statCell(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)

            Text(value)
                .font(.vqScoreSmall)
                .foregroundStyle(Color.vqTextPrimary)

            Text(label)
                .font(.vqCaption)
                .foregroundStyle(Color.vqTextSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .vqGlowCard(color: color, padding: 12)
    }

    // MARK: - Streak

    private var streakSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Streak")
                .font(.vqHeadline)
                .foregroundStyle(Color.vqTextPrimary)

            if let profile {
                StreakBadge(streak: profile.currentStreak, freezes: profile.streakFreezes)

                HStack {
                    Text("Joined \(profile.joinDate.formatted(.dateTime.month().day().year()))")
                        .font(.vqCaption)
                        .foregroundStyle(Color.vqTextSecondary.opacity(0.6))

                    Spacer()

                    if profile.streakFreezes < 3 {
                        Button("Buy Freeze (500 XP)") {
                            _ = streakManager.purchaseStreakFreeze(profile: profile)
                        }
                        .font(.vqCaption)
                        .foregroundStyle(Color.vqCyan)
                        .disabled(profile.totalXP < 500)
                        .opacity(profile.totalXP < 500 ? 0.4 : 1.0)
                    }
                }
            }
        }
        .vqCard()
    }

    // MARK: - Achievements

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Achievements")
                    .font(.vqHeadline)
                    .foregroundStyle(Color.vqTextPrimary)
                Spacer()
                let unlocked = achievements.filter(\.isUnlocked).count
                Text("\(unlocked)/\(achievements.count)")
                    .font(.vqCaption)
                    .foregroundStyle(Color.vqYellow)
            }

            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    categoryChip(nil, label: "All")
                    ForEach(AchievementCategory.allCases, id: \.self) { cat in
                        categoryChip(cat, label: cat.label)
                    }
                }
            }

            // Achievement grid
            let filtered = filteredAchievements
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(filtered, id: \.id) { achievement in
                    achievementBadge(achievement)
                }
            }
        }
        .vqCard()
    }

    private func categoryChip(_ category: AchievementCategory?, label: String) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            withAnimation(.spring(response: 0.3)) {
                selectedCategory = category
            }
        } label: {
            Text(label)
                .font(.vqCaption)
                .foregroundStyle(isSelected ? Color.vqTextPrimary : Color.vqTextSecondary.opacity(0.6))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.vqPurple.opacity(0.3) : Color.vqTextPrimary.opacity(0.04))
                )
        }
    }

    private var filteredAchievements: [Achievement] {
        if let cat = selectedCategory {
            return achievements.filter { $0.category == cat }
        }
        return achievements
    }

    private func achievementBadge(_ achievement: Achievement) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked
                        ? achievement.category.color.opacity(0.2)
                        : Color.vqTextPrimary.opacity(0.03))
                    .frame(width: 52, height: 52)

                if achievement.isUnlocked {
                    Circle()
                        .stroke(achievement.category.color.opacity(0.4), lineWidth: 2)
                        .frame(width: 52, height: 52)
                }

                Image(systemName: achievement.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(achievement.isUnlocked
                        ? achievement.category.color
                        : Color.vqTextSecondary.opacity(0.2))
            }

            Text(achievement.title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(achievement.isUnlocked ? Color.vqTextPrimary : Color.vqTextSecondary.opacity(0.4))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Goals")
                .font(.vqHeadline)
                .foregroundStyle(Color.vqTextPrimary)

            if let profile {
                goalRow(icon: "figure.walk", label: "Step Goal", value: "\(profile.stepGoal)", color: .vqCyan)
                goalRow(icon: "flame.fill", label: "Calorie Goal", value: "\(Int(profile.calorieGoal)) kcal", color: .vqPink)
                goalRow(icon: "moon.fill", label: "Sleep Goal", value: "\(Int(profile.sleepGoalHours))h", color: .vqPurple)
                goalRow(icon: "figure.run", label: "Exercise Goal", value: "\(Int(profile.exerciseGoalMinutes)) min", color: .vqGreen)
            }

            NavigationLink {
                ActivitiesView()
            } label: {
                HStack {
                    Image(systemName: "figure.mixed.cardio")
                        .foregroundStyle(Color.vqPink)
                        .frame(width: 24)
                    Text("Manage Activities")
                        .font(.vqBody)
                        .foregroundStyle(Color.vqTextSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.vqTextSecondary.opacity(0.3))
                }
            }
        }
        .vqCard()
    }

    private func goalRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .font(.vqBody)
                .foregroundStyle(Color.vqTextSecondary)
            Spacer()
            Text(value)
                .font(.vqSubheadline)
                .foregroundStyle(Color.vqTextPrimary)
        }
    }

    // MARK: - Disclaimer

    private var disclaimerSection: some View {
        Text("Not a medical device. Not intended to diagnose, treat, cure, or prevent any disease. Consult a healthcare provider for medical advice.")
            .font(.system(size: 11, design: .rounded))
            .foregroundStyle(Color.vqTextSecondary.opacity(0.35))
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .padding(.top, 8)
    }

    // MARK: - Helpers

    private func formatXP(_ xp: Int) -> String {
        if xp >= 1000 {
            return String(format: "%.1fK", Double(xp) / 1000.0)
        }
        return "\(xp)"
    }
}

private extension AchievementCategory {
    var color: Color {
        switch self {
        case .streak: .vqOrange
        case .score: .vqYellow
        case .activity: .vqPink
        case .dataNerd: .vqCyan
        case .level: .vqPurple
        }
    }
}

#Preview {
    ProfileView()
        .withMockEnvironment()
}
