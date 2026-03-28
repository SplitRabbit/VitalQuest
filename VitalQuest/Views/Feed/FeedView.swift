import SwiftUI
import SwiftData
import PhotosUI

struct FeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FeedItem.timestamp, order: .reverse) private var allItems: [FeedItem]

    /// Filter out daily summaries and quest completions from the feed.
    private var feedItems: [FeedItem] {
        allItems.filter { $0.type != .dailySummary && $0.type != .questComplete }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedMeshBackground()

                if feedItems.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(groupedByDate, id: \.date) { group in
                                // Date header row
                                timelineDateHeader(group.dateLabel)

                                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                                    let isLast = index == group.items.count - 1
                                    TimelineRow(item: item, isLastInGroup: isLast)
                                }
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileButton(compact: true)
                }
            }
        }
    }

    // MARK: - Grouping

    private struct DateGroup {
        let date: String
        let dateLabel: String
        let items: [FeedItem]
    }

    private var groupedByDate: [DateGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: feedItems) { item in
            calendar.startOfDay(for: item.timestamp)
        }

        return grouped.sorted { $0.key > $1.key }.map { (date, items) in
            let label: String
            if calendar.isDateInToday(date) {
                label = "Today"
            } else if calendar.isDateInYesterday(date) {
                label = "Yesterday"
            } else {
                label = date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
            }
            return DateGroup(
                date: date.formatted(.iso8601.year().month().day()),
                dateLabel: label,
                items: items.sorted { $0.timestamp > $1.timestamp }
            )
        }
    }

    private static let timelineLineX: CGFloat = 36

    private func timelineDateHeader(_ label: String) -> some View {
        HStack(spacing: 0) {
            // Timeline spine area
            ZStack {
                // Vertical line
                Rectangle()
                    .fill(Color.vqTextSecondary.opacity(0.12))
                    .frame(width: 2)
            }
            .frame(width: 52)

            Text(label)
                .font(.vqSubheadline)
                .foregroundStyle(Color.vqTextPrimary)

            Spacer()
        }
        .padding(.top, 16)
        .padding(.bottom, 4)
        .padding(.trailing, 20)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.bubble")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.vqGreen.opacity(0.4))

            Text("No activity yet")
                .font(.vqHeadline)
                .foregroundStyle(Color.vqTextPrimary)

            Text("Your workouts, achievements, and milestones will show up here.")
                .font(.vqBody)
                .foregroundStyle(Color.vqTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Timeline Row

struct TimelineRow: View {
    let item: FeedItem
    let isLastInGroup: Bool
    @State private var showShareSheet = false

    private var isShared: Bool { item.visibility == .public }

    var body: some View {
        Group {
            if isShared {
                sharedRow
            } else {
                compactRow
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareEditorSheet(item: item)
        }
    }

    // MARK: - Shared (Public) Row — Full Size

    private var sharedRow: some View {
        HStack(alignment: .top, spacing: 0) {
            // Large node
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.25))
                        .frame(width: 36, height: 36)

                    Image(systemName: item.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accentColor)
                }
                .padding(.top, 2)

                Rectangle()
                    .fill(Color.vqTextSecondary.opacity(isLastInGroup ? 0.0 : 0.12))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 52)

            VStack(alignment: .leading, spacing: 8) {
                // Title + shared badge + menu
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title)
                        .font(.vqSubheadline)
                        .foregroundStyle(Color.vqTextPrimary)

                    sharedBadge

                    Spacer()

                    itemMenu
                }

                if let detail = item.detail {
                    Text(detail)
                        .font(.vqBody)
                        .foregroundStyle(Color.vqTextSecondary)
                }

                if let value = item.metricValue, let unit = item.metricUnit {
                    HStack(spacing: 4) {
                        Text(formattedValue(value))
                            .font(.vqXP)
                            .foregroundStyle(accentColor)
                        Text(unit)
                            .font(.vqCaption)
                            .foregroundStyle(Color.vqTextSecondary)
                    }
                }

                // User caption
                if let caption = item.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.vqBody)
                        .foregroundStyle(Color.vqTextPrimary.opacity(0.85))
                }

                // User photo
                if let photoData = item.photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Text(formattedTimestamp(item.timestamp))
                    .font(.vqCaption)
                    .foregroundStyle(Color.vqTextSecondary.opacity(0.6))
            }
            .padding(.trailing, 20)
            .padding(.bottom, isLastInGroup ? 8 : 24)
        }
    }

    // MARK: - Compact (Private) Row — Smaller

    private var compactRow: some View {
        HStack(alignment: .top, spacing: 0) {
            // Small node
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 20, height: 20)

                    Image(systemName: item.icon)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(accentColor.opacity(0.5))
                }
                .padding(.top, 4)

                Rectangle()
                    .fill(Color.vqTextSecondary.opacity(isLastInGroup ? 0.0 : 0.12))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 52)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.title)
                        .font(.vqCaption)
                        .foregroundStyle(Color.vqTextPrimary.opacity(0.55))

                    if let detail = item.detail {
                        Text(detail)
                            .font(.vqCaption)
                            .foregroundStyle(Color.vqTextSecondary.opacity(0.45))
                            .lineLimit(1)
                    }

                    Spacer()

                    privateBadge

                    itemMenu
                }

                Text(formattedTimestamp(item.timestamp))
                    .font(.system(size: 10))
                    .foregroundStyle(Color.vqTextSecondary.opacity(0.35))
            }
            .padding(.trailing, 20)
            .padding(.top, 2)
            .padding(.bottom, isLastInGroup ? 6 : 12)
        }
        .opacity(0.8)
    }

    // MARK: - Badges

    private var sharedBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 8, weight: .bold))
            Text("Shared")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(accentColor.opacity(0.6))
    }

    private var privateBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "lock.fill")
                .font(.system(size: 7, weight: .bold))
            Text("Private")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(Color.vqTextSecondary.opacity(0.4))
    }

    // MARK: - Item Menu

    private var itemMenu: some View {
        Menu {
            Button {
                showShareSheet = true
            } label: {
                Label("Share with Friends", systemImage: "square.and.arrow.up")
            }

            if item.visibility == .public {
                Button {
                    item.visibility = .private
                } label: {
                    Label("Make Private", systemImage: "lock.fill")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.vqTextSecondary.opacity(0.4))
                .frame(width: 24, height: 24)
        }
    }

    // MARK: - Helpers

    private var accentColor: Color {
        switch item.accentColorName {
        case "green": .vqGreen
        case "blue": .vqBlue
        case "pink": .vqPink
        case "orange": .vqOrange
        case "yellow": .vqYellow
        case "cyan": .vqCyan
        default: .vqGreen
        }
    }

    private func formattedTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(.dateTime.hour().minute())
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday \u{2022} " + date.formatted(.dateTime.hour().minute())
        } else {
            return date.formatted(.dateTime.month(.abbreviated).day()) + " \u{2022} " + date.formatted(.dateTime.hour().minute())
        }
    }

    private func formattedValue(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

// MARK: - Share Editor Sheet

struct ShareEditorSheet: View {
    let item: FeedItem
    @Environment(\.dismiss) private var dismiss
    @State private var caption: String = ""
    @State private var selectedImageData: Data?
    @State private var photoSelection: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Preview of the activity
                    HStack(spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.vqGreen)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.vqSubheadline)
                                .foregroundStyle(Color.vqTextPrimary)
                            if let detail = item.detail {
                                Text(detail)
                                    .font(.vqCaption)
                                    .foregroundStyle(Color.vqTextSecondary)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.vqGreen.opacity(0.06))
                    )

                    // Caption
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Caption")
                            .font(.vqCaption)
                            .foregroundStyle(Color.vqTextSecondary)

                        TextField("Say something about this activity...", text: $caption, axis: .vertical)
                            .font(.vqBody)
                            .lineLimit(1...6)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.vqTextSecondary.opacity(0.06))
                            )
                    }

                    // Photo
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Photo")
                            .font(.vqCaption)
                            .foregroundStyle(Color.vqTextSecondary)

                        if let data = selectedImageData, let uiImage = UIImage(data: data) {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxHeight: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                Button {
                                    selectedImageData = nil
                                    photoSelection = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(.white, Color.black.opacity(0.5))
                                }
                                .padding(8)
                            }
                        } else {
                            PhotosPicker(selection: $photoSelection, matching: .images) {
                                HStack {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 16, weight: .medium))
                                    Text("Add Photo")
                                        .font(.vqBody)
                                }
                                .foregroundStyle(Color.vqGreen)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.vqGreen.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6]))
                                )
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.vqBackground)
            .navigationTitle("Share Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.vqTextSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Share") {
                        item.caption = caption.isEmpty ? nil : caption
                        item.photoData = selectedImageData
                        item.visibility = .public
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.vqGreen)
                }
            }
            .onChange(of: photoSelection) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        selectedImageData = data
                    }
                }
            }
        }
        .onAppear {
            caption = item.caption ?? ""
            selectedImageData = item.photoData
        }
    }
}

#Preview {
    FeedView()
        .withMockEnvironment()
}
