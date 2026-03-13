import SwiftUI
import SwiftData

struct QuestsView: View {
    @Query(sort: \Quest.assignedDate, order: .reverse) private var allQuests: [Quest]

    private var activeQuests: [Quest] { allQuests.filter { $0.status == .active } }
    private var completedQuests: [Quest] { allQuests.filter { $0.status == .completed } }

    @State private var selectedSegment = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedMeshBackground()

                VStack(spacing: 0) {
                    // Segmented picker
                    HStack(spacing: 4) {
                        segmentButton("Active", count: activeQuests.count, index: 0, color: .vqCyan)
                        segmentButton("Completed", count: completedQuests.count, index: 1, color: .vqGreen)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if selectedSegment == 0 {
                                if activeQuests.isEmpty {
                                    emptyState
                                } else {
                                    // Group by type
                                    let daily = activeQuests.filter { $0.type == .daily }
                                    let weekly = activeQuests.filter { $0.type == .weekly }
                                    let epic = activeQuests.filter { $0.type == .epic }

                                    if !daily.isEmpty {
                                        questSection("Daily Quests", quests: daily, icon: "sun.max.fill", color: .vqCyan)
                                    }
                                    if !weekly.isEmpty {
                                        questSection("Weekly Quests", quests: weekly, icon: "calendar", color: .vqPurple)
                                    }
                                    if !epic.isEmpty {
                                        questSection("Epic Quests", quests: epic, icon: "crown.fill", color: .vqYellow)
                                    }
                                }
                            } else {
                                if completedQuests.isEmpty {
                                    completedEmptyState
                                } else {
                                    ForEach(completedQuests.prefix(20), id: \.id) { quest in
                                        QuestCard(quest: quest)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Quests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Subviews

    private func segmentButton(_ title: String, count: Int, index: Int, color: Color) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedSegment = index
            }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.vqSubheadline)
                if count > 0 {
                    Text("\(count)")
                        .font(.vqCaption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(selectedSegment == index ? color : Color.vqTextPrimary.opacity(0.10))
                        )
                }
            }
            .foregroundStyle(selectedSegment == index ? Color.vqTextPrimary : Color.vqTextSecondary.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(selectedSegment == index ? color.opacity(0.2) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(selectedSegment == index ? color.opacity(0.4) : Color.vqTextPrimary.opacity(0.04), lineWidth: 1)
            )
        }
    }

    private func questSection(_ title: String, quests: [Quest], icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.vqSubheadline)
                    .foregroundStyle(Color.vqTextSecondary)
            }
            .padding(.top, 4)

            ForEach(quests, id: \.id) { quest in
                QuestCard(quest: quest)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "scroll")
                .font(.system(size: 48))
                .foregroundStyle(Color.vqCyan.opacity(0.4))

            Text("No Active Quests")
                .font(.vqHeadline)
                .foregroundStyle(Color.vqTextSecondary)

            Text("New quests appear each day at midnight.\nKeep adventuring!")
                .font(.vqBody)
                .foregroundStyle(Color.vqTextSecondary.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var completedEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color.vqGreen.opacity(0.4))

            Text("No Completed Quests Yet")
                .font(.vqHeadline)
                .foregroundStyle(Color.vqTextSecondary)

            Text("Complete your first quest to see it here!")
                .font(.vqBody)
                .foregroundStyle(Color.vqTextSecondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

#Preview {
    QuestsView()
        .modelContainer(for: Quest.self, inMemory: true)
        .withMockEnvironment()
}
