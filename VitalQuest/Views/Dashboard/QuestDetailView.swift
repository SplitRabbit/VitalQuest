import SwiftUI

struct QuestDetailView: View {
    let quest: Quest

    @Environment(\.dismiss) private var dismiss

    private var typeColor: Color {
        switch quest.type {
        case .daily: .vqCyan
        case .weekly: Color.vqGreen
        case .epic: .vqPurple
        }
    }

    private var typeLabel: String {
        switch quest.type {
        case .daily: "Daily Quest"
        case .weekly: "Weekly Quest"
        case .epic: "Epic Quest"
        }
    }

    private var typeIcon: String {
        switch quest.type {
        case .daily: "sun.max.fill"
        case .weekly: "calendar"
        case .epic: "shield.fill"
        }
    }

    private var progressPercent: Double {
        min(quest.progress * 100, 100)
    }

    private var timeRemaining: String {
        let now = Date()
        guard quest.deadline > now else { return "Expired" }
        let interval = quest.deadline.timeIntervalSince(now)
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours >= 24 {
            let days = hours / 24
            return "\(days)d \(hours % 24)h left"
        }
        return "\(hours)h \(minutes)m left"
    }

    private var isCompleted: Bool {
        quest.status == .completed
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedMeshBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // Hero
                        questHero

                        // Progress
                        progressSection

                        // Details
                        detailsSection

                        // Flavor text
                        if !quest.flavorText.isEmpty {
                            flavorSection
                        }

                        // Reward
                        rewardSection
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Quest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(typeColor)
                }
            }
        }
    }

    // MARK: - Hero

    private var questHero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(typeColor.opacity(0.15))
                    .frame(width: 72, height: 72)

                if isCompleted {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(Color.vqGreen)
                } else {
                    Image(systemName: typeIcon)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(typeColor)
                }
            }

            Text(quest.title)
                .font(.vqTitle)
                .foregroundStyle(Color.vqTextPrimary)
                .multilineTextAlignment(.center)

            Text(typeLabel)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(typeColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(typeColor.opacity(0.12))
                .clipShape(Capsule())

            if isCompleted {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.vqGreen)
                    Text("Completed!")
                        .font(.vqCaption)
                        .foregroundStyle(Color.vqGreen)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .vqCard()
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: 14) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.vqTextPrimary.opacity(0.06), lineWidth: 10)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: min(quest.progress, 1.0))
                    .stroke(
                        AngularGradient(
                            colors: [typeColor, typeColor.opacity(0.6), typeColor],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(Int(progressPercent))%")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.vqTextPrimary)
                }
            }

            // Current / Target
            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text(formatMetricValue(quest.currentValue))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(typeColor)
                    Text("Current")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.vqTextSecondary)
                }

                Rectangle()
                    .fill(Color.vqTextPrimary.opacity(0.08))
                    .frame(width: 1, height: 30)

                VStack(spacing: 2) {
                    Text(formatMetricValue(quest.targetValue))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.vqTextPrimary)
                    Text("Target")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.vqTextSecondary)
                }

                Rectangle()
                    .fill(Color.vqTextPrimary.opacity(0.08))
                    .frame(width: 1, height: 30)

                VStack(spacing: 2) {
                    Text(formatMetricValue(max(quest.targetValue - quest.currentValue, 0)))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.vqOrange)
                    Text("Remaining")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.vqTextSecondary)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.vqTextPrimary.opacity(0.06))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [typeColor, typeColor.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * min(quest.progress, 1.0))
                        .shadow(color: typeColor.opacity(0.4), radius: 4, y: 2)
                }
            }
            .frame(height: 10)
            .clipShape(Capsule())
        }
        .vqCard()
    }

    // MARK: - Details

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Details")
                .font(.vqHeadline)
                .foregroundStyle(Color.vqTextPrimary)

            DetailRow(icon: "target", label: "Metric", value: quest.metric.capitalized)
            DetailRow(icon: "calendar", label: "Assigned", value: quest.assignedDate.formatted(.dateTime.month().day()))
            DetailRow(icon: "clock.fill", label: "Deadline", value: quest.deadline.formatted(.dateTime.month().day().hour().minute()))
            DetailRow(icon: "timer", label: "Time Left", value: timeRemaining)
            DetailRow(icon: "flag.fill", label: "Status", value: quest.status.rawValue.capitalized)
            if let completed = quest.completedDate {
                DetailRow(icon: "checkmark.circle.fill", label: "Completed", value: completed.formatted(.dateTime.month().day().hour().minute()))
            }
        }
        .vqCard()
    }

    // MARK: - Flavor Text

    private var flavorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Mascot(mood: isCompleted ? .cheering : .happy, size: 28)
                Text("Quest Lore")
                    .font(.vqHeadline)
                    .foregroundStyle(Color.vqTextPrimary)
            }

            Text(quest.flavorText)
                .font(.vqBody)
                .foregroundStyle(Color.vqTextSecondary)
                .italic()
        }
        .vqCard()
    }

    // MARK: - Reward

    private var rewardSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.system(size: 24))
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text("Reward")
                    .font(.vqCaption)
                    .foregroundStyle(Color.vqTextSecondary)
                Text("+\(quest.xpReward) XP")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.vqTextPrimary)
            }

            Spacer()

            if isCompleted {
                Text("Claimed!")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.vqGreen)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.vqGreen.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .vqGlowCard(color: .yellow.opacity(0.6))
    }

    // MARK: - Helpers

    private func formatMetricValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fK", value / 1000)
        }
        if value == value.rounded() {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.vqTextSecondary.opacity(0.5))
                .frame(width: 20)
            Text(label)
                .font(.vqCaption)
                .foregroundStyle(Color.vqTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.vqTextPrimary)
        }
        .padding(.vertical, 2)
    }
}
