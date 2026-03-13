import SwiftUI

/// Colorful metric display row with icon and value
struct MetricRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    var detail: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.vqCaption)
                    .foregroundStyle(Color.vqTextSecondary)
                Text(value)
                    .font(.vqSubheadline)
                    .foregroundStyle(Color.vqTextPrimary)
            }

            Spacer()

            if let detail {
                Text(detail)
                    .font(.vqCaption)
                    .foregroundStyle(Color.vqTextSecondary.opacity(0.6))
            }
        }
    }
}

/// Horizontal scrolling metric pill
struct MetricPill: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)

            Text(value)
                .font(.vqSubheadline)
                .foregroundStyle(Color.vqTextPrimary)

            Text(label)
                .font(.vqCaption)
                .foregroundStyle(Color.vqTextSecondary.opacity(0.7))
        }
        .frame(width: 80, height: 90)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }
}

/// Score component breakdown row (for score detail view)
struct ScoreComponentRow: View {
    let label: String
    let value: Double
    let weight: String
    let color: Color

    @State private var animatedWidth: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.vqCaption)
                    .foregroundStyle(Color.vqTextSecondary)
                Spacer()
                Text(weight)
                    .font(.vqCaption)
                    .foregroundStyle(Color.vqTextSecondary.opacity(0.5))
                Text("\(Int(value))")
                    .font(.vqSubheadline)
                    .foregroundStyle(DailySnapshot.scoreTier(value).color)
                    .frame(width: 32, alignment: .trailing)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.vqTextPrimary.opacity(0.04))
                    Capsule()
                        .fill(color.opacity(0.7))
                        .frame(width: geo.size.width * animatedWidth / 100)
                }
            }
            .frame(height: 4)
            .clipShape(Capsule())
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1)) {
                animatedWidth = value
            }
        }
    }
}

#Preview("Metrics") {
    ZStack {
        AnimatedMeshBackground()
        VStack(spacing: 16) {
            MetricRow(icon: "figure.walk", label: "Steps", value: "8,432", color: .vqCyan, detail: "84%")
            MetricRow(icon: "flame.fill", label: "Calories", value: "423 kcal", color: .vqPink)
            MetricRow(icon: "heart.fill", label: "Resting HR", value: "62 bpm", color: .vqOrange)

            Divider().background(Color.vqTextPrimary.opacity(0.08))

            HStack(spacing: 8) {
                MetricPill(icon: "figure.walk", label: "Steps", value: "8.4K", color: .vqCyan)
                MetricPill(icon: "flame.fill", label: "Calories", value: "423", color: .vqPink)
                MetricPill(icon: "figure.run", label: "Exercise", value: "34m", color: .vqGreen)
                MetricPill(icon: "heart.fill", label: "RHR", value: "62", color: .vqOrange)
            }

            Divider().background(Color.vqTextPrimary.opacity(0.08))

            ScoreComponentRow(label: "HRV vs Baseline", value: 82, weight: "30%", color: .vqGreen)
            ScoreComponentRow(label: "Resting HR", value: 71, weight: "25%", color: .vqOrange)
            ScoreComponentRow(label: "Sleep Quality", value: 65, weight: "25%", color: .vqPurple)
        }
        .padding()
    }
}
