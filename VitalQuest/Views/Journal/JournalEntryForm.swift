import SwiftUI
import SwiftData

/// Built-in factor definitions (id → icon + label)
let builtInFactorDefs: [String: (icon: String, label: String)] = [
    "coffee": ("cup.and.saucer.fill", "Coffee"),
    "alcohol": ("wineglass.fill", "Alcohol"),
    "hydrated": ("drop.fill", "Hydrated"),
    "lateMeal": ("fork.knife", "Late Meal"),
    "stressed": ("brain.head.profile", "Stressed"),
]

/// Compact inline daily log card for the home dashboard
struct DailyLogCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.date, order: .reverse) private var allEntries: [JournalEntry]
    @Query(sort: \CustomLog.createdAt) private var customLogs: [CustomLog]
    @Query private var profiles: [UserProfile]

    @State private var showAddLog = false
    @State private var editingLog: CustomLog?
    @State private var isEditing = false

    private let maxFactors = 5

    private var profile: UserProfile? {
        profiles.first
    }

    private var enabledIds: [String] {
        profile?.enabledLogFactors ?? ["coffee", "alcohol", "hydrated", "lateMeal", "stressed"]
    }

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
        let isBuiltIn: Bool
    }

    /// Resolve enabledLogFactors IDs into displayable factors, preserving order
    private var visibleFactors: [Factor] {
        enabledIds.compactMap { id in
            if let def = builtInFactorDefs[id] {
                return Factor(id: id, icon: def.icon, label: def.label, isBuiltIn: true)
            }
            if let log = customLogs.first(where: { $0.id == id }) {
                return Factor(id: log.id, icon: log.icon, label: log.label, isBuiltIn: false)
            }
            return nil
        }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Daily Log")
                    .font(.vqHeadline)
                    .foregroundStyle(Color.vqTextPrimary)
                Spacer()
                if isEditing {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isEditing = false
                        }
                    } label: {
                        Text("Done")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.vqCyan)
                    }
                }
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(visibleFactors) { factor in
                    let isOn = getValue(factor.id, isBuiltIn: factor.isBuiltIn)

                    Button {
                        if !isEditing {
                            toggleFactor(factor.id, isBuiltIn: factor.isBuiltIn)
                        }
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(isOn ? Color.vqCyan.opacity(0.15) : Color.vqTextPrimary.opacity(0.04))
                                    .frame(width: 40, height: 40)

                                Image(systemName: factor.icon)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(isOn ? Color.vqCyan : Color.vqTextSecondary.opacity(0.35))

                                if isEditing {
                                    Button {
                                        removeFactor(factor.id, isBuiltIn: factor.isBuiltIn)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.white, Color.vqPink)
                                    }
                                    .offset(x: 16, y: -16)
                                }
                            }
                            Text(factor.label)
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(isOn ? Color.vqTextPrimary : Color.vqTextSecondary.opacity(0.5))
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                    .wiggle(isEditing)
                    .onLongPressGesture {
                        if !factor.isBuiltIn {
                            editingLog = customLogs.first { $0.id == factor.id }
                        }
                    }
                }

                if visibleFactors.count < maxFactors {
                    Button {
                        showAddLog = true
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .strokeBorder(Color.vqTextSecondary.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                                    .frame(width: 40, height: 40)

                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.vqTextSecondary.opacity(0.4))
                            }
                            Text("Add")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.vqTextSecondary.opacity(0.5))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .vqCard()
            .onLongPressGesture {
                withAnimation(.spring(response: 0.3)) {
                    isEditing = true
                }
            }
        }
        .sheet(isPresented: $showAddLog) {
            AddCustomLogSheet(
                enabledIds: Set(enabledIds),
                onAdd: { id in
                    addFactor(id)
                }
            )
        }
        .sheet(item: $editingLog) { log in
            CreateCustomLogSheet(
                initialName: log.label,
                initialIcon: log.icon,
                existingIds: Set(customLogs.filter { $0.id != log.id }.map { $0.label.lowercased() }),
                onSave: { label, icon in
                    log.label = label
                    log.icon = icon
                    try? modelContext.save()
                }
            )
        }
    }

    // MARK: - Helpers

    private func ensureEntry() -> JournalEntry {
        if let existing = todayEntry { return existing }
        let entry = JournalEntry(date: today)
        modelContext.insert(entry)
        return entry
    }

    private func ensureProfile() -> UserProfile {
        if let p = profile { return p }
        let p = UserProfile()
        modelContext.insert(p)
        return p
    }

    private func getValue(_ id: String, isBuiltIn: Bool) -> Bool {
        guard let entry = todayEntry else { return false }
        if isBuiltIn {
            switch id {
            case "coffee": return entry.hadCoffee
            case "alcohol": return entry.hadAlcohol
            case "hydrated": return entry.stayedHydrated
            case "lateMeal": return entry.lateMeal
            case "stressed": return entry.feltStressed
            default: return false
            }
        }
        return entry.activeCustomLogs.contains(id)
    }

    private func toggleFactor(_ id: String, isBuiltIn: Bool) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            let entry = ensureEntry()
            if isBuiltIn {
                switch id {
                case "coffee": entry.hadCoffee.toggle()
                case "alcohol": entry.hadAlcohol.toggle()
                case "hydrated": entry.stayedHydrated.toggle()
                case "lateMeal": entry.lateMeal.toggle()
                case "stressed": entry.feltStressed.toggle()
                default: break
                }
            } else {
                if let idx = entry.activeCustomLogs.firstIndex(of: id) {
                    entry.activeCustomLogs.remove(at: idx)
                } else {
                    entry.activeCustomLogs.append(id)
                }
            }
            entry.lastUpdated = Date()
            try? modelContext.save()
        }
    }

    private func addFactor(_ id: String) {
        withAnimation(.spring(response: 0.3)) {
            let p = ensureProfile()
            guard p.enabledLogFactors.count < maxFactors else { return }
            guard !p.enabledLogFactors.contains(id) else { return }
            p.enabledLogFactors.append(id)
            try? modelContext.save()
        }
    }

    private func removeFactor(_ id: String, isBuiltIn: Bool) {
        withAnimation(.spring(response: 0.3)) {
            let p = ensureProfile()
            p.enabledLogFactors.removeAll { $0 == id }
            // If it's a custom log, also clean up the CustomLog object + history
            if !isBuiltIn {
                for entry in allEntries {
                    entry.activeCustomLogs.removeAll { $0 == id }
                }
                if let log = customLogs.first(where: { $0.id == id }) {
                    modelContext.delete(log)
                }
            }
            try? modelContext.save()
        }
    }
}

// MARK: - Common Log Suggestions

private struct LogSuggestion: Identifiable {
    let id: String
    let label: String
    let icon: String
    let category: String
}

private let commonLogs: [LogSuggestion] = [
    // Nutrition
    LogSuggestion(id: "sugar", label: "Sugar", icon: "birthday.cake.fill", category: "Nutrition"),
    LogSuggestion(id: "fastfood", label: "Fast Food", icon: "takeoutbag.and.cup.and.straw.fill", category: "Nutrition"),
    LogSuggestion(id: "protein", label: "High Protein", icon: "fish.fill", category: "Nutrition"),
    LogSuggestion(id: "fasting", label: "Fasting", icon: "clock.fill", category: "Nutrition"),
    LogSuggestion(id: "vitamins", label: "Vitamins", icon: "pills.fill", category: "Nutrition"),
    LogSuggestion(id: "creatine", label: "Creatine", icon: "bolt.fill", category: "Nutrition"),

    // Sleep & Recovery
    LogSuggestion(id: "nap", label: "Napped", icon: "bed.double.fill", category: "Sleep & Recovery"),
    LogSuggestion(id: "screenbed", label: "Screen Before Bed", icon: "iphone", category: "Sleep & Recovery"),
    LogSuggestion(id: "coldplunge", label: "Cold Plunge", icon: "snowflake", category: "Sleep & Recovery"),
    LogSuggestion(id: "sauna", label: "Sauna", icon: "flame.fill", category: "Sleep & Recovery"),
    LogSuggestion(id: "stretch", label: "Stretched", icon: "figure.flexibility", category: "Sleep & Recovery"),
    LogSuggestion(id: "massage", label: "Massage", icon: "hand.raised.fill", category: "Sleep & Recovery"),

    // Wellness
    LogSuggestion(id: "meditate", label: "Meditated", icon: "brain.head.profile.fill", category: "Wellness"),
    LogSuggestion(id: "journal", label: "Journaled", icon: "book.fill", category: "Wellness"),
    LogSuggestion(id: "sunlight", label: "Morning Sun", icon: "sun.max.fill", category: "Wellness"),
    LogSuggestion(id: "nature", label: "Time Outside", icon: "leaf.fill", category: "Wellness"),
    LogSuggestion(id: "social", label: "Socialized", icon: "person.2.fill", category: "Wellness"),
    LogSuggestion(id: "sick", label: "Felt Sick", icon: "facemask.fill", category: "Wellness"),

    // Habits
    LogSuggestion(id: "cannabis", label: "Cannabis", icon: "smoke.fill", category: "Habits"),
    LogSuggestion(id: "nicotine", label: "Nicotine", icon: "lungs.fill", category: "Habits"),
    LogSuggestion(id: "preworkout", label: "Pre-Workout", icon: "cup.and.saucer.fill", category: "Habits"),
    LogSuggestion(id: "gaming", label: "Gaming", icon: "gamecontroller.fill", category: "Habits"),
    LogSuggestion(id: "reading", label: "Read", icon: "text.book.closed.fill", category: "Habits"),
]

// MARK: - Add Custom Log Sheet

struct AddCustomLogSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let enabledIds: Set<String>
    let onAdd: (String) -> Void

    @State private var searchText = ""
    @State private var showCreateCustom = false

    /// Built-in factors not currently in the grid
    private var availableBuiltIns: [LogSuggestion] {
        builtInFactorDefs.compactMap { id, def in
            guard !enabledIds.contains(id) else { return nil }
            return LogSuggestion(id: id, label: def.label, icon: def.icon, category: "Defaults")
        }.sorted { $0.label < $1.label }
    }

    /// Pregenerated suggestions not already enabled
    private var availableSuggestions: [LogSuggestion] {
        commonLogs.filter { !enabledIds.contains($0.id) }
    }

    private var filteredBuiltIns: [LogSuggestion] {
        if searchText.isEmpty { return availableBuiltIns }
        return availableBuiltIns.filter { $0.label.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredSuggestions: [LogSuggestion] {
        let available = availableSuggestions
        if searchText.isEmpty { return available }
        return available.filter { $0.label.localizedCaseInsensitiveContains(searchText) }
    }

    private var groupedSuggestions: [(String, [LogSuggestion])] {
        let categories = Dictionary(grouping: filteredSuggestions, by: \.category)
        let order = ["Nutrition", "Sleep & Recovery", "Wellness", "Habits"]
        return order.compactMap { cat in
            guard let items = categories[cat], !items.isEmpty else { return nil }
            return (cat, items)
        }
    }

    private var showCreateRow: Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let allLabels = (commonLogs.map { $0.label.lowercased() }) + builtInFactorDefs.values.map { $0.label.lowercased() }
        return !allLabels.contains(trimmed.lowercased())
    }

    var body: some View {
        NavigationStack {
            List {
                if showCreateRow {
                    Section {
                        Button {
                            showCreateCustom = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.square.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.vqGreen)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.vqGreen.opacity(0.12))
                                    )

                                Text("Create \"\(searchText.trimmingCharacters(in: .whitespaces))\"")
                                    .font(.vqBody)
                                    .foregroundStyle(Color.vqTextPrimary)

                                Spacer()

                                Image(systemName: "arrow.right.circle")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.vqGreen)
                            }
                        }
                    }
                }

                // Available built-in factors
                if !filteredBuiltIns.isEmpty {
                    Section("Defaults") {
                        ForEach(filteredBuiltIns) { item in
                            Button {
                                onAdd(item.id)
                                dismiss()
                            } label: {
                                logRow(icon: item.icon, label: item.label)
                            }
                        }
                    }
                }

                // Pregenerated suggestions
                ForEach(groupedSuggestions, id: \.0) { category, items in
                    Section(category) {
                        ForEach(items) { suggestion in
                            Button {
                                addSuggestion(suggestion)
                            } label: {
                                logRow(icon: suggestion.icon, label: suggestion.label)
                            }
                        }
                    }
                }

                // Persistent create custom
                Section {
                    Button {
                        showCreateCustom = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.square.dashed")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.vqTextSecondary)
                                .frame(width: 32, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.vqTextPrimary.opacity(0.04))
                                )

                            Text("Create Custom Log")
                                .font(.vqBody)
                                .foregroundStyle(Color.vqTextSecondary)

                            Spacer()
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search logs")
            .navigationTitle("Add Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.vqTextSecondary)
                }
            }
            .sheet(isPresented: $showCreateCustom) {
                CreateCustomLogSheet(
                    initialName: showCreateRow ? searchText.trimmingCharacters(in: .whitespaces) : "",
                    existingIds: Set(enabledIds),
                    onSave: { label, icon in
                        let log = CustomLog(label: label, icon: icon)
                        modelContext.insert(log)
                        try? modelContext.save()
                        onAdd(log.id)
                    }
                )
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func logRow(icon: String, label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.vqCyan)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.vqCyan.opacity(0.12))
                )

            Text(label)
                .font(.vqBody)
                .foregroundStyle(Color.vqTextPrimary)

            Spacer()

            Image(systemName: "plus.circle")
                .font(.system(size: 18))
                .foregroundStyle(Color.vqCyan)
        }
    }

    private func addSuggestion(_ suggestion: LogSuggestion) {
        let log = CustomLog(label: suggestion.label, icon: suggestion.icon)
        modelContext.insert(log)
        try? modelContext.save()
        onAdd(log.id)
        dismiss()
    }
}

// MARK: - Create Custom Log Sheet

private struct CreateCustomLogSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initialName: String
    var initialIcon: String = "star.fill"
    let existingIds: Set<String>
    let onSave: (String, String) -> Void

    @State private var name = ""
    @State private var selectedIcon = "star.fill"

    private let iconOptions = [
        "star.fill", "heart.fill", "bolt.fill", "flame.fill", "leaf.fill",
        "drop.fill", "moon.fill", "sun.max.fill", "cloud.fill", "snowflake",
        "figure.walk", "figure.run", "dumbbell.fill", "bicycle", "sportscourt.fill",
        "cup.and.saucer.fill", "fork.knife", "carrot.fill", "fish.fill", "birthday.cake.fill",
        "pills.fill", "cross.case.fill", "bandage.fill", "facemask.fill", "brain.head.profile.fill",
        "book.fill", "pencil", "music.note", "gamecontroller.fill", "paintbrush.fill",
        "bed.double.fill", "alarm.fill", "hands.sparkles.fill", "eye.fill", "ear.fill",
    ]

    private let iconColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 7)

    private var canSave: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && !existingIds.contains(trimmed.lowercased())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Preview
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(Color.vqCyan.opacity(0.15))
                                .frame(width: 56, height: 56)

                            Image(systemName: selectedIcon)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(Color.vqCyan)
                        }
                        Text(name.isEmpty ? "Custom Log" : name)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.vqTextPrimary)
                    }
                    .padding(.top, 8)

                    // Name field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.vqTextSecondary)

                        TextField("e.g. Cold Shower", text: $name)
                            .font(.vqBody)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.vqTextPrimary.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.vqTextPrimary.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal)

                    // Icon picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Icon")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.vqTextSecondary)
                            .padding(.horizontal)

                        LazyVGrid(columns: iconColumns, spacing: 12) {
                            ForEach(iconOptions, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(selectedIcon == icon ? Color.vqCyan : Color.vqTextSecondary.opacity(0.4))
                                        .frame(width: 40, height: 40)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(selectedIcon == icon ? Color.vqCyan.opacity(0.15) : Color.vqTextPrimary.opacity(0.03))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(selectedIcon == icon ? Color.vqCyan.opacity(0.3) : Color.clear, lineWidth: 1.5)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Create Custom Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.vqTextSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave(name.trimmingCharacters(in: .whitespaces), selectedIcon)
                        dismiss()
                    }
                    .foregroundStyle(canSave ? Color.vqCyan : Color.vqTextSecondary.opacity(0.3))
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            name = initialName
            selectedIcon = initialIcon
        }
    }
}

// MARK: - Wiggle Modifier

private struct WiggleModifier: ViewModifier {
    let active: Bool
    @State private var angle: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(active ? angle : 0))
            .onChange(of: active) { _, isActive in
                if isActive {
                    withAnimation(.easeInOut(duration: 0.1).repeatForever(autoreverses: true)) {
                        angle = 2
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        angle = 0
                    }
                }
            }
            .onAppear {
                if active {
                    withAnimation(.easeInOut(duration: 0.1).repeatForever(autoreverses: true)) {
                        angle = 2
                    }
                }
            }
    }
}

extension View {
    fileprivate func wiggle(_ active: Bool) -> some View {
        modifier(WiggleModifier(active: active))
    }
}

#Preview {
    DailyLogCard()
        .padding()
        .background(AnimatedMeshBackground())
        .withMockEnvironment()
}
