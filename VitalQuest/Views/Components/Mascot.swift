import SwiftUI

/// Nudge's mascot — Sprout, a friendly little bean creature with arms, legs, and a leaf.
/// Built entirely from SwiftUI shapes. Changes expression and posture based on mood.
enum MascotMood {
    case happy, excited, sleepy, tired, cheering, thinking, surprised
}

struct Mascot: View {
    var mood: MascotMood = .happy
    var size: CGFloat = 60

    @State private var bounce = false
    @State private var blink = false
    @State private var wobble = false
    @State private var wave = false

    private var scale: CGFloat { size / 60 }

    // Body colors
    private var bodyGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.45, green: 0.90, blue: 0.55),
                Color(red: 0.30, green: 0.75, blue: 0.42)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var bodyDark: Color {
        Color(red: 0.18, green: 0.50, blue: 0.30)
    }

    private var leafColor: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.40, green: 0.85, blue: 0.35),
                Color(red: 0.25, green: 0.65, blue: 0.28)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        ZStack {
            // Ground shadow
            Ellipse()
                .fill(bodyDark.opacity(0.12))
                .frame(width: 30 * scale, height: 6 * scale)
                .offset(y: 28 * scale)
                .blur(radius: 2 * scale)

            // Legs
            legsView

            // Body — bean/pill shape
            Capsule()
                .fill(bodyGradient)
                .frame(width: 32 * scale, height: 38 * scale)
                .offset(y: bounce ? -2 * scale : 0)

            // Body highlight
            Ellipse()
                .fill(.white.opacity(0.25))
                .frame(width: 12 * scale, height: 16 * scale)
                .offset(x: -5 * scale, y: -6 * scale + (bounce ? -2 * scale : 0))
                .blur(radius: 2 * scale)

            // Arms
            armsView

            // Leaf on top
            leafView

            // Face
            faceView
                .offset(y: 2 * scale + (bounce ? -2 * scale : 0))

            // Cheeks
            if mood == .happy || mood == .excited || mood == .cheering {
                HStack(spacing: 18 * scale) {
                    Ellipse()
                        .fill(Color.pink.opacity(0.22))
                        .frame(width: 6 * scale, height: 4 * scale)
                    Ellipse()
                        .fill(Color.pink.opacity(0.22))
                        .frame(width: 6 * scale, height: 4 * scale)
                }
                .offset(y: 8 * scale + (bounce ? -2 * scale : 0))
            }

            // Mood extras
            moodExtras
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                bounce = true
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                wave = true
            }
            startBlinking()
        }
    }

    // MARK: - Leaf

    private var leafView: some View {
        ZStack {
            // Stem
            Capsule()
                .fill(Color(red: 0.30, green: 0.65, blue: 0.30))
                .frame(width: 2.5 * scale, height: 8 * scale)
                .offset(y: -20 * scale + (bounce ? -2 * scale : 0))

            // Leaf blade
            LeafShape()
                .fill(leafColor)
                .frame(width: 12 * scale, height: 10 * scale)
                .rotationEffect(.degrees(wobble ? 8 : -8))
                .offset(x: 4 * scale, y: -26 * scale + (bounce ? -2 * scale : 0))
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        wobble = true
                    }
                }
        }
    }

    // MARK: - Arms

    @ViewBuilder
    private var armsView: some View {
        let armY = 2 * scale + (bounce ? -2 * scale : 0)

        // Left arm
        Capsule()
            .fill(bodyGradient)
            .frame(width: 6 * scale, height: 16 * scale)
            .rotationEffect(.degrees(leftArmAngle), anchor: .top)
            .offset(x: -19 * scale, y: armY)

        // Right arm
        Capsule()
            .fill(bodyGradient)
            .frame(width: 6 * scale, height: 16 * scale)
            .rotationEffect(.degrees(rightArmAngle), anchor: .top)
            .offset(x: 19 * scale, y: armY)
    }

    private var leftArmAngle: Double {
        switch mood {
        case .cheering: wave ? -40 : -20
        case .excited: -35
        case .tired, .sleepy: 15
        case .thinking: -10
        default: wave ? 12 : 18
        }
    }

    private var rightArmAngle: Double {
        switch mood {
        case .cheering: wave ? 40 : 20
        case .excited: 35
        case .tired, .sleepy: -15
        case .thinking: -25
        default: wave ? -12 : -18
        }
    }

    // MARK: - Legs

    private var legsView: some View {
        HStack(spacing: 10 * scale) {
            // Left leg
            Capsule()
                .fill(bodyDark.opacity(0.6))
                .frame(width: 8 * scale, height: 12 * scale)
                .offset(y: 22 * scale + (bounce ? 1 * scale : 0))

            // Right leg
            Capsule()
                .fill(bodyDark.opacity(0.6))
                .frame(width: 8 * scale, height: 12 * scale)
                .offset(y: 22 * scale + (bounce ? 1 * scale : 0))
        }
    }

    // MARK: - Face

    @ViewBuilder
    private var faceView: some View {
        switch mood {
        case .happy, .cheering:
            happyFace
        case .excited:
            excitedFace
        case .sleepy:
            sleepyFace
        case .tired:
            tiredFace
        case .thinking:
            thinkingFace
        case .surprised:
            surprisedFace
        }
    }

    private var happyFace: some View {
        VStack(spacing: 4 * scale) {
            HStack(spacing: 12 * scale) {
                eye(closed: blink)
                eye(closed: blink)
            }
            SmileShape()
                .stroke(bodyDark, lineWidth: 2 * scale)
                .frame(width: 12 * scale, height: 5 * scale)
        }
    }

    private var excitedFace: some View {
        VStack(spacing: 4 * scale) {
            HStack(spacing: 12 * scale) {
                starEye
                starEye
            }
            Ellipse()
                .fill(bodyDark)
                .frame(width: 8 * scale, height: 6 * scale)
        }
    }

    private var sleepyFace: some View {
        VStack(spacing: 4 * scale) {
            HStack(spacing: 12 * scale) {
                Capsule()
                    .fill(bodyDark)
                    .frame(width: 7 * scale, height: 2 * scale)
                Capsule()
                    .fill(bodyDark)
                    .frame(width: 7 * scale, height: 2 * scale)
            }
            Circle()
                .fill(bodyDark)
                .frame(width: 4 * scale, height: 4 * scale)
        }
    }

    private var tiredFace: some View {
        VStack(spacing: 5 * scale) {
            HStack(spacing: 12 * scale) {
                eye(closed: false)
                    .rotationEffect(.degrees(-10))
                eye(closed: false)
                    .rotationEffect(.degrees(10))
            }
            Capsule()
                .fill(bodyDark)
                .frame(width: 9 * scale, height: 2 * scale)
        }
    }

    private var thinkingFace: some View {
        VStack(spacing: 4 * scale) {
            HStack(spacing: 12 * scale) {
                eye(closed: false)
                eye(closed: false)
                    .offset(y: -2 * scale)
            }
            Capsule()
                .fill(bodyDark)
                .frame(width: 7 * scale, height: 2 * scale)
                .offset(x: 3 * scale)
        }
    }

    private var surprisedFace: some View {
        VStack(spacing: 4 * scale) {
            HStack(spacing: 12 * scale) {
                Circle()
                    .fill(bodyDark)
                    .frame(width: 6 * scale, height: 6 * scale)
                Circle()
                    .fill(bodyDark)
                    .frame(width: 6 * scale, height: 6 * scale)
            }
            Circle()
                .stroke(bodyDark, lineWidth: 2 * scale)
                .frame(width: 7 * scale, height: 7 * scale)
        }
    }

    // MARK: - Eye helpers

    private func eye(closed: Bool) -> some View {
        Group {
            if closed {
                Capsule()
                    .fill(bodyDark)
                    .frame(width: 6 * scale, height: 2 * scale)
            } else {
                ZStack {
                    Circle()
                        .fill(bodyDark)
                        .frame(width: 5.5 * scale, height: 5.5 * scale)
                    Circle()
                        .fill(.white)
                        .frame(width: 2 * scale, height: 2 * scale)
                        .offset(x: 1 * scale, y: -1 * scale)
                }
            }
        }
    }

    private var starEye: some View {
        Image(systemName: "star.fill")
            .font(.system(size: 6 * scale))
            .foregroundStyle(Color.vqYellow)
    }

    // MARK: - Mood extras

    @ViewBuilder
    private var moodExtras: some View {
        switch mood {
        case .sleepy:
            ZzzBubbles(scale: scale)
                .offset(x: 22 * scale, y: -16 * scale)
        case .excited, .cheering:
            SparkleRing(scale: scale)
        case .surprised:
            Text("!")
                .font(.system(size: 12 * scale, weight: .black, design: .rounded))
                .foregroundStyle(Color.vqYellow)
                .offset(x: 20 * scale, y: -22 * scale)
        default:
            EmptyView()
        }
    }

    // MARK: - Blink timer

    private func startBlinking() {
        Timer.scheduledTimer(withTimeInterval: Double.random(in: 2.5...4.5), repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.15)) { blink = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.15)) { blink = false }
            }
        }
    }
}

// MARK: - Leaf Shape

struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Simple leaf: pointed tip left, rounded right
        path.move(to: CGPoint(x: 0, y: h * 0.5))
        path.addQuadCurve(
            to: CGPoint(x: w, y: h * 0.1),
            control: CGPoint(x: w * 0.5, y: -h * 0.2)
        )
        path.addQuadCurve(
            to: CGPoint(x: 0, y: h * 0.5),
            control: CGPoint(x: w * 0.5, y: h * 1.2)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Smile Shape

struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return path
    }
}

// MARK: - Zzz Bubbles

struct ZzzBubbles: View {
    let scale: CGFloat
    @State private var float = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("z")
                .font(.system(size: 7 * scale, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.3))
                .offset(y: float ? -4 : 0)
            Text("Z")
                .font(.system(size: 9 * scale, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .offset(x: 4 * scale, y: float ? -6 : 0)
            Text("Z")
                .font(.system(size: 12 * scale, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .offset(x: 8 * scale, y: float ? -8 : 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                float = true
            }
        }
    }
}

// MARK: - Sparkle Ring

struct SparkleRing: View {
    let scale: CGFloat
    @State private var spin = false
    @State private var twinkle = false

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: (4 + CGFloat(i % 3) * 2) * scale))
                    .foregroundStyle(Color.vqYellow.opacity(twinkle ? 0.8 : 0.3))
                    .offset(y: -30 * scale)
                    .rotationEffect(.degrees(Double(i) * 60 + (spin ? 30 : 0)))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                spin = true
            }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                twinkle = true
            }
        }
    }
}

// MARK: - Confetti Burst (for achievements / level-ups)

struct ConfettiBurst: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var active = false

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                Circle()
                    .fill(p.color)
                    .frame(width: p.size, height: p.size)
                    .offset(x: active ? p.endX : 0, y: active ? p.endY : 0)
                    .opacity(active ? 0 : 1)
                    .scaleEffect(active ? 0.3 : 1)
            }
        }
        .onAppear {
            particles = (0..<20).map { _ in ConfettiParticle() }
            withAnimation(.easeOut(duration: 1.2)) {
                active = true
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    let endX: CGFloat
    let endY: CGFloat

    init() {
        color = [Color.vqGreen, .vqCyan, .vqYellow, .vqPink, .vqOrange, .white].randomElement()!
        size = CGFloat.random(in: 4...8)
        endX = CGFloat.random(in: -120...120)
        endY = CGFloat.random(in: -160...(-20))
    }
}

// MARK: - Floating Hearts (for good scores)

struct FloatingHearts: View {
    let count: Int
    @State private var hearts: [FloatingHeart] = []

    var body: some View {
        ZStack {
            ForEach(hearts) { heart in
                Image(systemName: "heart.fill")
                    .font(.system(size: heart.size))
                    .foregroundStyle(heart.color.opacity(heart.opacity))
                    .offset(x: heart.x, y: heart.y)
            }
        }
        .onAppear {
            for i in 0..<count {
                let delay = Double(i) * 0.3
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    let heart = FloatingHeart()
                    hearts.append(heart)
                    withAnimation(.easeOut(duration: 2.0)) {
                        if let idx = hearts.firstIndex(where: { $0.id == heart.id }) {
                            hearts[idx].y = -100
                            hearts[idx].opacity = 0
                        }
                    }
                }
            }
        }
    }
}

struct FloatingHeart: Identifiable {
    let id = UUID()
    let color: Color = [.vqPink, .vqGreen, .vqCyan].randomElement()!
    let size: CGFloat = .random(in: 10...18)
    var x: CGFloat = .random(in: -40...40)
    var y: CGFloat = 0
    var opacity: Double = 0.7
}

#Preview("Mascot Moods") {
    ZStack {
        AnimatedMeshBackground()
        VStack(spacing: 30) {
            HStack(spacing: 30) {
                VStack {
                    Mascot(mood: .happy, size: 60)
                    Text("Happy").font(.vqCaption).foregroundStyle(.white)
                }
                VStack {
                    Mascot(mood: .excited, size: 60)
                    Text("Excited").font(.vqCaption).foregroundStyle(.white)
                }
                VStack {
                    Mascot(mood: .cheering, size: 60)
                    Text("Cheering").font(.vqCaption).foregroundStyle(.white)
                }
            }
            HStack(spacing: 30) {
                VStack {
                    Mascot(mood: .sleepy, size: 60)
                    Text("Sleepy").font(.vqCaption).foregroundStyle(.white)
                }
                VStack {
                    Mascot(mood: .tired, size: 60)
                    Text("Tired").font(.vqCaption).foregroundStyle(.white)
                }
                VStack {
                    Mascot(mood: .surprised, size: 60)
                    Text("Surprised").font(.vqCaption).foregroundStyle(.white)
                }
            }
            HStack(spacing: 30) {
                VStack {
                    Mascot(mood: .thinking, size: 60)
                    Text("Thinking").font(.vqCaption).foregroundStyle(.white)
                }
            }
            ConfettiBurst()
        }
    }
}
