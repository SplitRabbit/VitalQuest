import SwiftUI
import SwiftData

/// Compact inline daily log card for the home dashboard
struct DailyLogCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.date, order: .reverse) private var allEntries: [JournalEntry]

    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var todayEntry: JournalEntry? {
        allEntries.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    private struct Factor: Identifiable {
        let id: String
        let icon: String
        let label: String
        let keyPath: WritableKeyPath<JournalEntry, Bool>
    }

    private let factors: [Factor] = [
        Factor(id: "coffee", icon: "cup.and.saucer.fill", label: "Coffee", keyPath: \.hadCoffee),
        Factor(id: "alcohol", icon: "wineglass.fill", label: "Alcohol", keyPath: \.hadAlcohol),
        Factor(id: "hydrated", icon: "drop.fill", label: "Hydrated", keyPath: \.stayedHydrated),
        Factor(id: "lateMeal", icon: "fork.knife", label: "Late Meal", keyPath: \.lateMeal),
        Factor(id: "stressed", icon: "brain.head.profile", label: "Stressed", keyPath: \.feltStressed),
    ]

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Daily Log")
                    .font(.vqSubheadline)
                    .foregroundStyle(Color.vqTextPrimary)
                Spacer()
                if let entry = todayEntry, let m = Mood(rawValue: entry.mood) {
                    Text(m.emoji)
                        .font(.system(size: 16))
                }
            }

            // 5 toggle icons
            HStack(spacing: 0) {
                ForEach(factors) { factor in
                    let isOn = todayEntry?[keyPath: factor.keyPath] ?? false
                    Button {
                        toggleFactor(factor)
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(isOn ? Color.vqGreen.opacity(0.15) : Color.vqTextPrimary.opacity(0.04))
                                    .frame(width: 40, height: 40)

                                Image(systemName: factor.icon)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(isOn ? Color.vqGreen : Color.vqTextSecondary.opacity(0.35))
                            }
                            Text(factor.label)
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(isOn ? Color.vqTextPrimary : Color.vqTextSecondary.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Mood pills
            HStack(spacing: 8) {
                ForEach(Mood.allCases, id: \.rawValue) { m in
                    let isSelected = todayEntry.map { Mood(rawValue: $0.mood) == m } ?? false
                    Button {
                        setMood(m)
                    } label: {
                        Text("\(m.emoji) \(m.rawValue.capitalized)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(isSelected ? .white : Color.vqTextSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(isSelected ? moodColor(m) : Color.vqSurface)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .vqCard()
    }

    // MARK: - Actions

    private func ensureEntry() -> JournalEntry {
        if let existing = todayEntry { return existing }
        let entry = JournalEntry(date: today)
        modelContext.insert(entry)
        return entry
    }

    private func toggleFactor(_ factor: Factor) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            let entry = ensureEntry()
            entry[keyPath: factor.keyPath].toggle()
            entry.lastUpdated = Date()
            try? modelContext.save()
        }
    }

    private func setMood(_ mood: Mood) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            let entry = ensureEntry()
            entry.mood = mood.rawValue
            entry.lastUpdated = Date()
            try? modelContext.save()
        }
    }

    private func moodColor(_ m: Mood) -> Color {
        switch m {
        case .great: .vqGreen
        case .good: .vqCyan
        case .okay: .vqOrange
        case .rough: .vqPink
        }
    }
}

#Preview {
    DailyLogCard()
        .padding()
        .background(AnimatedMeshBackground())
        .withMockEnvironment()
}
