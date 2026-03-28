import SwiftUI
import SwiftData

struct ActivitiesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Activity.sortOrder) private var activities: [Activity]

    @State private var showAddSheet = false

    private var visibleActivities: [Activity] {
        activities.filter { !$0.isHidden }
    }

    private var hiddenDefaults: [Activity] {
        activities.filter { $0.isHidden && $0.isDefault }
    }

    var body: some View {
        ZStack {
            AnimatedMeshBackground()

            ScrollView {
                VStack(spacing: 16) {
                    // Active activities
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Activities")
                            .font(.vqHeadline)
                            .foregroundStyle(Color.vqTextPrimary)

                        ForEach(visibleActivities) { activity in
                            activityRow(activity)
                        }
                    }
                    .vqCard()

                    // Hidden defaults (restore section)
                    if !hiddenDefaults.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Hidden")
                                .font(.vqHeadline)
                                .foregroundStyle(Color.vqTextSecondary)

                            ForEach(hiddenDefaults) { activity in
                                hiddenRow(activity)
                            }
                        }
                        .vqCard()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Activities")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.vqGreen)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            ActivityEditorSheet(mode: .add)
        }
    }

    // MARK: - Rows

    private func activityRow(_ activity: Activity) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(colorFor(activity.colorName).opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: activity.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(colorFor(activity.colorName))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.name)
                    .font(.vqSubheadline)
                    .foregroundStyle(Color.vqTextPrimary)

                if activity.isDefault {
                    Text("Default")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.vqTextSecondary.opacity(0.5))
                }
            }

            Spacer()

            Menu {
                if !activity.isDefault {
                    Button {
                        showEditSheet(for: activity)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }

                Button(role: .destructive) {
                    removeActivity(activity)
                } label: {
                    Label(activity.isDefault ? "Hide" : "Delete", systemImage: activity.isDefault ? "eye.slash" : "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.vqTextSecondary.opacity(0.4))
                    .frame(width: 30, height: 30)
            }
        }
    }

    private func hiddenRow(_ activity: Activity) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.vqTextSecondary.opacity(0.06))
                    .frame(width: 36, height: 36)

                Image(systemName: activity.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.vqTextSecondary.opacity(0.3))
            }

            Text(activity.name)
                .font(.vqBody)
                .foregroundStyle(Color.vqTextSecondary.opacity(0.5))

            Spacer()

            Button {
                activity.isHidden = false
            } label: {
                Text("Restore")
                    .font(.vqCaption)
                    .foregroundStyle(Color.vqGreen)
            }
        }
    }

    // MARK: - Actions

    @State private var editingActivity: Activity?

    private func showEditSheet(for activity: Activity) {
        editingActivity = activity
    }

    private func removeActivity(_ activity: Activity) {
        if activity.isDefault {
            activity.isHidden = true
        } else {
            modelContext.delete(activity)
        }
    }

    private func colorFor(_ name: String) -> Color {
        switch name {
        case "green": .vqGreen
        case "blue": .vqBlue
        case "pink": .vqPink
        case "orange": .vqOrange
        case "yellow": .vqYellow
        case "cyan": .vqCyan
        case "purple": .vqPurple
        default: .vqGreen
        }
    }
}

// MARK: - Activity Editor Sheet

struct ActivityEditorSheet: View {
    enum Mode {
        case add
        case edit(Activity)
    }

    let mode: Mode
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Activity.sortOrder) private var activities: [Activity]

    @State private var name = ""
    @State private var selectedIcon = "figure.mixed.cardio"
    @State private var selectedColor = "pink"

    private let iconOptions = [
        "figure.run", "figure.outdoor.cycle", "figure.walk", "figure.pool.swim",
        "figure.yoga", "figure.hiking", "dumbbell.fill", "bolt.heart.fill",
        "figure.elliptical", "figure.rower", "figure.dance", "figure.pilates",
        "figure.cross.training", "figure.mixed.cardio", "figure.basketball",
        "figure.tennis", "figure.boxing", "figure.climbing", "figure.surfing",
        "figure.skiing.downhill", "figure.snowboarding", "figure.martial.arts",
        "figure.jumprope", "figure.cooldown", "sportscourt.fill",
    ]

    private let colorOptions = ["pink", "green", "blue", "orange", "yellow", "cyan", "purple"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name")
                            .font(.vqCaption)
                            .foregroundStyle(Color.vqTextSecondary)

                        TextField("Activity name", text: $name)
                            .font(.vqBody)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.vqTextSecondary.opacity(0.06))
                            )
                    }

                    // Icon picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Icon")
                            .font(.vqCaption)
                            .foregroundStyle(Color.vqTextSecondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                            ForEach(iconOptions, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(selectedIcon == icon
                                                ? colorFor(selectedColor).opacity(0.2)
                                                : Color.vqTextSecondary.opacity(0.06))
                                            .frame(height: 44)

                                        if selectedIcon == icon {
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(colorFor(selectedColor).opacity(0.5), lineWidth: 1.5)
                                                .frame(height: 44)
                                        }

                                        Image(systemName: icon)
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundStyle(selectedIcon == icon
                                                ? colorFor(selectedColor)
                                                : Color.vqTextSecondary.opacity(0.5))
                                    }
                                }
                            }
                        }
                    }

                    // Color picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Color")
                            .font(.vqCaption)
                            .foregroundStyle(Color.vqTextSecondary)

                        HStack(spacing: 10) {
                            ForEach(colorOptions, id: \.self) { color in
                                Button {
                                    selectedColor = color
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(colorFor(color))
                                            .frame(width: 36, height: 36)

                                        if selectedColor == color {
                                            Circle()
                                                .stroke(Color.vqTextPrimary, lineWidth: 2.5)
                                                .frame(width: 42, height: 42)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Preview
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Preview")
                            .font(.vqCaption)
                            .foregroundStyle(Color.vqTextSecondary)

                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(colorFor(selectedColor).opacity(0.15))
                                    .frame(width: 40, height: 40)

                                Image(systemName: selectedIcon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(colorFor(selectedColor))
                            }

                            Text(name.isEmpty ? "Activity name" : name)
                                .font(.vqSubheadline)
                                .foregroundStyle(name.isEmpty ? Color.vqTextSecondary.opacity(0.4) : Color.vqTextPrimary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(colorFor(selectedColor).opacity(0.04))
                        )
                    }
                }
                .padding(20)
            }
            .background(Color.vqBackground)
            .navigationTitle(isEditing ? "Edit Activity" : "New Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.vqTextSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.vqGreen)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if case .edit(let activity) = mode {
                    name = activity.name
                    selectedIcon = activity.icon
                    selectedColor = activity.colorName
                }
            }
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        switch mode {
        case .add:
            let nextOrder = (activities.map(\.sortOrder).max() ?? 0) + 1
            let activity = Activity(
                name: trimmed,
                icon: selectedIcon,
                colorName: selectedColor,
                isDefault: false,
                sortOrder: nextOrder
            )
            modelContext.insert(activity)

        case .edit(let activity):
            activity.name = trimmed
            activity.icon = selectedIcon
            activity.colorName = selectedColor
        }
    }

    private func colorFor(_ name: String) -> Color {
        switch name {
        case "green": .vqGreen
        case "blue": .vqBlue
        case "pink": .vqPink
        case "orange": .vqOrange
        case "yellow": .vqYellow
        case "cyan": .vqCyan
        case "purple": .vqPurple
        default: .vqGreen
        }
    }
}

#Preview {
    NavigationStack {
        ActivitiesView()
            .withMockEnvironment()
    }
}
