import SwiftUI

/// Animated circular score ring with gradient stroke and bouncy fill.
struct ScoreRing: View {
    let score: Double
    let label: String
    let gradientColors: [Color]
    var size: CGFloat = 120
    var lineWidth: CGFloat = 10
    var showLabel: Bool = true

    @State private var animatedProgress: Double = 0

    private var tier: ScoreTier { DailySnapshot.scoreTier(score) }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background track
                Circle()
                    .stroke(Color.vqTextPrimary.opacity(0.06), lineWidth: lineWidth)

                // Animated gradient ring
                Circle()
                    .trim(from: 0, to: animatedProgress / 100)
                    .stroke(
                        AngularGradient(
                            colors: gradientColors + [gradientColors.first ?? .white],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: gradientColors.first?.opacity(0.5) ?? .clear, radius: 6)

                // Score text
                VStack(spacing: 2) {
                    Text("\(Int(animatedProgress))")
                        .font(size > 100 ? .vqScoreMedium : .vqScoreSmall)
                        .foregroundStyle(Color.vqTextPrimary)
                        .contentTransition(.numericText(value: animatedProgress))

                    if showLabel && size > 80 {
                        Text(tier.emoji)
                            .font(.system(size: size * 0.15))
                    }
                }
            }
            .frame(width: size, height: size)

            if showLabel {
                Text(label)
                    .font(.vqCaption)
                    .foregroundStyle(Color.vqTextSecondary)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.6).delay(0.1)) {
                animatedProgress = score
            }
        }
        .onChange(of: score) { _, newValue in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedProgress = newValue
            }
        }
    }
}

/// Compact score badge for inline display
struct ScoreBadge: View {
    let score: Double
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.vqCaption)
                    .foregroundStyle(Color.vqTextSecondary)
                Text("\(Int(score))")
                    .font(.vqSubheadline)
                    .foregroundStyle(Color.vqTextPrimary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
        .overlay(
            Capsule()
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview("Score Rings") {
    ZStack {
        AnimatedMeshBackground()
        VStack(spacing: 24) {
            HStack(spacing: 20) {
                ScoreRing(score: 85, label: "Recovery", gradientColors: Color.recoveryGradientColors)
                ScoreRing(score: 72, label: "Sleep", gradientColors: Color.sleepGradientColors)
            }
            ScoreRing(score: 64, label: "Activity", gradientColors: Color.activityGradientColors)
        }
    }
}
