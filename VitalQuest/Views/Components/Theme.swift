import SwiftUI

// MARK: - Color Palette

extension Color {
    // Primary brand colors — bright, playful green theme
    static let vqPurple = Color(red: 0.55, green: 0.90, blue: 0.65)      // Bright mint
    static let vqPink = Color(red: 1.0, green: 0.50, blue: 0.60)         // Bubblegum pink
    static let vqCyan = Color(red: 0.30, green: 0.95, blue: 0.85)        // Bright aqua
    static let vqGreen = Color(red: 0.25, green: 0.90, blue: 0.50)       // Bright spring green
    static let vqOrange = Color(red: 1.0, green: 0.70, blue: 0.25)       // Sunny orange
    static let vqYellow = Color(red: 0.95, green: 0.92, blue: 0.25)      // Bright lemon
    static let vqBlue = Color(red: 0.35, green: 0.65, blue: 1.0)         // Bright sky blue

    // Score tier colors
    static let scoreExcellent = Color(red: 0.25, green: 0.90, blue: 0.50)
    static let scoreGood = Color(red: 0.30, green: 0.95, blue: 0.85)
    static let scoreFair = Color(red: 1.0, green: 0.70, blue: 0.25)
    static let scoreLow = Color(red: 1.0, green: 0.45, blue: 0.45)

    // Adaptive background & surface colors (light ↔ dark)
    static let vqBackground = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.08, green: 0.10, blue: 0.08, alpha: 1)
            : UIColor(red: 0.92, green: 0.97, blue: 0.93, alpha: 1)
    })
    static let vqCardBackground = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.14, blue: 0.12, alpha: 1)
            : UIColor(red: 0.94, green: 0.97, blue: 0.94, alpha: 1)
    })
    static let vqSurface = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.10, green: 0.12, blue: 0.10, alpha: 1)
            : UIColor(red: 0.90, green: 0.95, blue: 0.91, alpha: 1)
    })
    static let vqSurfaceLight = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.14, green: 0.16, blue: 0.14, alpha: 1)
            : UIColor(red: 0.96, green: 0.98, blue: 0.96, alpha: 1)
    })

    // Adaptive text colors
    static let vqTextPrimary = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.92, green: 0.95, blue: 0.92, alpha: 1)
            : UIColor(red: 0.15, green: 0.20, blue: 0.15, alpha: 1)
    })
    static let vqTextSecondary = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.60, green: 0.67, blue: 0.62, alpha: 1)
            : UIColor(red: 0.40, green: 0.47, blue: 0.42, alpha: 1)
    })

    // Score-specific ring colors
    static let recoveryRing = Color.vqGreen
    static let sleepRing = Color.vqBlue
    static let activityRing = Color.vqPink
    // Gradients as color pairs
    static let recoveryGradientColors: [Color] = [.vqGreen, .vqCyan]
    static let sleepGradientColors: [Color] = [.vqBlue, .vqCyan]
    static let activityGradientColors: [Color] = [.vqPink, .vqOrange]
    static let xpGradientColors: [Color] = [.vqYellow, .vqGreen]
    static let streakGradientColors: [Color] = [.vqOrange, .vqYellow]
}

// MARK: - Gradients

extension LinearGradient {
    static let recovery = LinearGradient(colors: Color.recoveryGradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    static let sleep = LinearGradient(colors: Color.sleepGradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    static let activity = LinearGradient(colors: Color.activityGradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    static let xpBar = LinearGradient(colors: Color.xpGradientColors, startPoint: .leading, endPoint: .trailing)
    static let streak = LinearGradient(colors: Color.streakGradientColors, startPoint: .leading, endPoint: .trailing)
    static let brand = LinearGradient(colors: [.vqGreen, .vqCyan], startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - Score Tier Styling

extension ScoreTier {
    var color: Color {
        switch self {
        case .excellent: .scoreExcellent
        case .good: .scoreGood
        case .fair: .scoreFair
        case .low: .scoreLow
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .excellent: LinearGradient(colors: [.vqGreen, .vqCyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .good: LinearGradient(colors: [.vqCyan, .vqBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .fair: LinearGradient(colors: [.vqOrange, .vqYellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .low: LinearGradient(colors: [.scoreLow, .vqOrange], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var emoji: String {
        switch self {
        case .excellent: "🔥"
        case .good: "💪"
        case .fair: "👌"
        case .low: "😴"
        }
    }
}

// MARK: - Typography

extension Font {
    static let vqTitle = Font.system(size: 28, weight: .black, design: .rounded)
    static let vqHeadline = Font.system(size: 20, weight: .bold, design: .rounded)
    static let vqSubheadline = Font.system(size: 16, weight: .semibold, design: .rounded)
    static let vqBody = Font.system(size: 15, weight: .medium, design: .rounded)
    static let vqCaption = Font.system(size: 12, weight: .medium, design: .rounded)
    static let vqScoreLarge = Font.system(size: 42, weight: .black, design: .rounded)
    static let vqScoreMedium = Font.system(size: 32, weight: .bold, design: .rounded)
    static let vqScoreSmall = Font.system(size: 22, weight: .bold, design: .rounded)
    static let vqXP = Font.system(size: 14, weight: .heavy, design: .rounded)
    static let vqLevel = Font.system(size: 18, weight: .black, design: .rounded)
    static let vqQuestTitle = Font.system(size: 16, weight: .bold, design: .rounded)
    static let vqQuestFlavor = Font.system(size: 13, weight: .regular, design: .serif)
}

// MARK: - Card Style Modifier

struct VQCard: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.vqCardBackground)
                    .shadow(color: Color.vqGreen.opacity(0.08), radius: 10, x: 0, y: 4)
            )
    }
}

struct VQGlowCard: ViewModifier {
    let glowColor: Color
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.vqCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(glowColor.opacity(0.4), lineWidth: 1.5)
            )
            .shadow(color: glowColor.opacity(0.15), radius: 10, x: 0, y: 4)
    }
}

extension View {
    func vqCard(padding: CGFloat = 16) -> some View {
        modifier(VQCard(padding: padding))
    }

    func vqGlowCard(color: Color, padding: CGFloat = 16) -> some View {
        modifier(VQGlowCard(glowColor: color, padding: padding))
    }
}

// MARK: - Animated Background — bright & cheerful

struct AnimatedMeshBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let isDark = colorScheme == .dark

                // Adaptive base gradient
                let bg = Gradient(colors: isDark ? [
                    Color(red: 0.06, green: 0.08, blue: 0.06),
                    Color(red: 0.08, green: 0.10, blue: 0.08),
                    Color(red: 0.07, green: 0.09, blue: 0.07),
                ] : [
                    Color(red: 0.92, green: 0.97, blue: 0.93),
                    Color(red: 0.88, green: 0.96, blue: 0.90),
                    Color(red: 0.93, green: 0.98, blue: 0.94),
                ])
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(bg, startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height))
                )

                // Floating orbs — dimmer in dark mode
                let orbAlpha: CGFloat = isDark ? 0.08 : 1.0
                let orbs: [(Color, CGFloat, CGFloat, CGFloat)] = [
                    (.vqGreen.opacity(0.12 * orbAlpha), 0.25, 0.15, 1.0),
                    (.vqCyan.opacity(0.10 * orbAlpha), 0.75, 0.75, 1.3),
                    (.vqYellow.opacity(0.08 * orbAlpha), 0.50, 0.45, 0.8),
                    (.vqPink.opacity(0.06 * orbAlpha), 0.85, 0.25, 0.9),
                ]
                for (color, baseX, baseY, speed) in orbs {
                    let x = size.width * (baseX + 0.08 * sin(time * speed * 0.3))
                    let y = size.height * (baseY + 0.08 * cos(time * speed * 0.2))
                    let radius = min(size.width, size.height) * 0.35
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(color)
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Playful Button Style

struct VQButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.vqSubheadline)
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(color.gradient)
            )
            .overlay(
                Capsule()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.2 : 0))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == VQButtonStyle {
    static func vqButton(color: Color = .vqGreen) -> VQButtonStyle {
        VQButtonStyle(color: color)
    }
}
