import SwiftUI

/// RPG-styled quest card with progress bar and flavor text
struct QuestCard: View {
    let quest: Quest

    @State private var animatedProgress: Double = 0

    private var questColor: Color {
        switch quest.type {
        case .daily: .vqCyan
        case .weekly: .vqPurple
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

    private var typeLabel: String {
        switch quest.type {
        case .daily: "DAILY"
        case .weekly: "WEEKLY"
        case .epic: "EPIC"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: type badge + XP reward
            HStack {
                Text(typeLabel)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(questColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(questColor.opacity(0.15))
                    )

                Spacer()

                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                    Text("+\(quest.xpReward) XP")
                        .font(.vqXP)
                }
                .foregroundStyle(Color.vqYellow)
            }

            // Quest title with icon
            HStack(spacing: 8) {
                Image(systemName: questIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(questColor)
                    .frame(width: 28)

                Text(quest.title)
                    .font(.vqQuestTitle)
                    .foregroundStyle(Color.vqTextPrimary)
            }

            // Flavor text
            Text(quest.flavorText)
                .font(.vqQuestFlavor)
                .foregroundStyle(Color.vqTextSecondary.opacity(0.7))
                .lineLimit(2)

            // Progress bar
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.vqTextPrimary.opacity(0.06))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [questColor, questColor.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, geo.size.width * animatedProgress))
                            .shadow(color: questColor.opacity(0.4), radius: 4)
                    }
                }
                .frame(height: 8)
                .clipShape(Capsule())

                HStack {
                    Text(formatProgress(quest.currentValue, quest.targetValue, quest.metric))
                        .font(.vqCaption)
                        .foregroundStyle(Color.vqTextSecondary.opacity(0.7))
                    Spacer()
                    Text("\(Int(quest.progress * 100))%")
                        .font(.vqCaption)
                        .foregroundStyle(questColor)
                }
            }
        }
        .vqGlowCard(color: quest.status == .completed ? .vqGreen : questColor)
        .opacity(quest.status == .completed ? 0.7 : 1.0)
        .overlay {
            if quest.status == .completed {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.vqGreen.opacity(0.08))
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.vqGreen)
                        Text("COMPLETE")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.vqGreen)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animatedProgress = quest.progress
            }
        }
    }

    private func formatProgress(_ current: Double, _ target: Double, _ metric: String) -> String {
        switch metric {
        case "steps":
            return "\(Int(current)) / \(Int(target)) steps"
        case "activeCalories":
            return "\(Int(current)) / \(Int(target)) cal"
        case "exerciseMinutes":
            return "\(Int(current)) / \(Int(target)) min"
        case "standMinutes":
            return "\(Int(current)) / \(Int(target)) min"
        case "sleepScore", "recoveryScore", "activityScore":
            return "\(Int(current)) / \(Int(target))"
        default:
            return "\(Int(current)) / \(Int(target))"
        }
    }
}

#Preview("Quest Cards") {
    ZStack {
        AnimatedMeshBackground()
        ScrollView {
            VStack(spacing: 12) {
                QuestCard(quest: {
                    let q = Quest(title: "March to the Market", flavorText: "The village needs supplies — trek to the merchant before sundown.", type: .daily, metric: "steps", targetValue: 8000, xpReward: 30, deadline: Date().addingTimeInterval(86400))
                    q.currentValue = 5200
                    return q
                }())

                QuestCard(quest: {
                    let q = Quest(title: "The Burning Path", flavorText: "Channel your inner fire and burn through your calorie target.", type: .daily, metric: "activeCalories", targetValue: 400, xpReward: 30, deadline: Date().addingTimeInterval(86400))
                    q.currentValue = 400
                    q.status = .completed
                    return q
                }())

                QuestCard(quest: {
                    let q = Quest(title: "Training Grounds", flavorText: "Report to the training grounds for your daily exercise.", type: .weekly, metric: "exerciseMinutes", targetValue: 150, xpReward: 100, deadline: Date().addingTimeInterval(604800))
                    q.currentValue = 45
                    return q
                }())
            }
            .padding()
        }
    }
}
