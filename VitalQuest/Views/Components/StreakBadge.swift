import SwiftUI

/// Animated flame streak counter with pulsing glow
struct StreakBadge: View {
    let streak: Int
    let freezes: Int
    var compact: Bool = false

    @State private var flameScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3

    private var streakColor: Color {
        switch streak {
        case 0: .gray
        case 1...6: .vqOrange
        case 7...29: .vqPink
        case 30...99: .vqPurple
        default: .vqCyan
        }
    }

    var body: some View {
        HStack(spacing: compact ? 6 : 10) {
            // Flame icon with pulse
            ZStack {
                if streak > 0 {
                    Image(systemName: "flame.fill")
                        .font(.system(size: compact ? 18 : 26))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.vqYellow, .vqOrange, .vqPink],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .scaleEffect(flameScale)
                        .shadow(color: .vqOrange.opacity(glowOpacity), radius: 8)
                } else {
                    Image(systemName: "flame")
                        .font(.system(size: compact ? 18 : 26))
                        .foregroundStyle(.gray.opacity(0.5))
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text("\(streak)")
                        .font(compact ? .vqSubheadline : .vqHeadline)
                        .foregroundStyle(Color.vqTextPrimary)
                    Text(streak == 1 ? "day" : "days")
                        .font(.vqCaption)
                        .foregroundStyle(Color.vqTextSecondary)
                }

                if !compact {
                    // Freeze indicators
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: i < freezes ? "snowflake" : "snowflake")
                                .font(.system(size: 10))
                                .foregroundStyle(i < freezes ? Color.vqCyan : Color.vqTextPrimary.opacity(0.15))
                        }
                        if freezes > 0 {
                            Text("\(freezes)")
                                .font(.vqCaption)
                                .foregroundStyle(Color.vqCyan.opacity(0.7))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, compact ? 12 : 16)
        .padding(.vertical, compact ? 8 : 12)
        .background(
            RoundedRectangle(cornerRadius: compact ? 18 : 24, style: .continuous)
                .fill(streakColor.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 18 : 24, style: .continuous)
                .stroke(streakColor.opacity(0.25), lineWidth: 1)
        )
        .onAppear {
            guard streak > 0 else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                flameScale = 1.12
                glowOpacity = 0.6
            }
        }
    }
}

#Preview("Streak Badges") {
    ZStack {
        AnimatedMeshBackground()
        VStack(spacing: 16) {
            StreakBadge(streak: 42, freezes: 2)
            StreakBadge(streak: 7, freezes: 1)
            StreakBadge(streak: 3, freezes: 0, compact: true)
            StreakBadge(streak: 0, freezes: 0)
        }
        .padding()
    }
}
