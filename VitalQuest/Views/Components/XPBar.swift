import SwiftUI

/// Shiny, animated XP progress bar with level badge
struct XPBar: View {
    let level: Int
    let progress: Double  // 0.0 to 1.0
    let xpToNext: Int
    let title: String

    @State private var animatedProgress: Double = 0
    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                // Level badge
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.vqYellow, .vqOrange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .shadow(color: .vqYellow.opacity(0.4), radius: 6)

                    Text("\(level)")
                        .font(.vqLevel)
                        .foregroundStyle(Color.vqTextPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.vqSubheadline)
                        .foregroundStyle(Color.vqTextPrimary)

                    Text("\(xpToNext) XP to next level")
                        .font(.vqCaption)
                        .foregroundStyle(Color.vqTextSecondary.opacity(0.7))
                }

                Spacer()
            }

            // XP Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.vqTextPrimary.opacity(0.08))

                    // Fill
                    Capsule()
                        .fill(LinearGradient.xpBar)
                        .frame(width: max(0, geo.size.width * animatedProgress))
                        .overlay(
                            // Shimmer effect
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.clear, .white.opacity(0.3), .clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .offset(x: shimmerOffset * geo.size.width)
                                .mask(
                                    Capsule()
                                        .frame(width: max(0, geo.size.width * animatedProgress))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                )
                        )

                    // Glow on leading edge
                    if animatedProgress > 0.02 {
                        Circle()
                            .fill(Color.vqYellow.opacity(0.8))
                            .frame(width: 14, height: 14)
                            .blur(radius: 4)
                            .offset(x: max(0, geo.size.width * animatedProgress - 7))
                    }
                }
            }
            .frame(height: 12)
            .clipShape(Capsule())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.vqCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.vqYellow.opacity(0.15), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.7).delay(0.3)) {
                animatedProgress = progress
            }
            // Shimmer loop
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false).delay(1)) {
                shimmerOffset = 2
            }
        }
    }
}

/// Compact XP gain notification
struct XPGainBubble: View {
    let amount: Int
    let source: String

    @State private var appear = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.vqYellow)
            Text("+\(amount) XP")
                .font(.vqXP)
                .foregroundStyle(Color.vqYellow)
            Text(source)
                .font(.vqCaption)
                .foregroundStyle(Color.vqTextSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.vqYellow.opacity(0.12))
        )
        .overlay(
            Capsule()
                .stroke(Color.vqYellow.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(appear ? 1 : 0.5)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                appear = true
            }
        }
    }
}

#Preview("XP Bar") {
    ZStack {
        AnimatedMeshBackground()
        VStack(spacing: 20) {
            XPBar(level: 12, progress: 0.65, xpToNext: 180, title: "Journeyman")
            XPGainBubble(amount: 30, source: "Daily Quest")
            XPGainBubble(amount: 10, source: "Check-in")
        }
        .padding()
    }
}
