import SwiftUI

/// Sproutie — a cute leaf/sprout mascot built entirely from SwiftUI shapes.
/// Changes expression based on mood.
enum MascotMood {
    case happy, excited, sleepy, tired, cheering, thinking, surprised
}

struct Mascot: View {
    var mood: MascotMood = .happy
    var size: CGFloat = 60

    @State private var bounce = false
    @State private var blink = false
    @State private var wiggle = false

    private var scale: CGFloat { size / 60 }

    var body: some View {
        ZStack {
            // Body — rounded green blob
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.35, green: 0.85, blue: 0.50), Color(red: 0.20, green: 0.70, blue: 0.40)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 40 * scale, height: 48 * scale)
                .offset(y: bounce ? -3 * scale : 0)

            // Leaf on top
            leaf
                .offset(x: 2 * scale, y: -26 * scale)
                .rotationEffect(.degrees(wiggle ? 15 : -5), anchor: .bottom)
                .offset(y: bounce ? -3 * scale : 0)

            // Face
            faceView
                .offset(y: bounce ? -3 * scale : 0)

            // Cheeks (blush)
            if mood == .happy || mood == .excited || mood == .cheering {
                HStack(spacing: 22 * scale) {
                    Circle()
                        .fill(Color.pink.opacity(0.35))
                        .frame(width: 8 * scale, height: 6 * scale)
                    Circle()
                        .fill(Color.pink.opacity(0.35))
                        .frame(width: 8 * scale, height: 6 * scale)
                }
                .offset(y: 4 * scale + (bounce ? -3 * scale : 0))
            }

            // Arms
            arms
                .offset(y: bounce ? -3 * scale : 0)

            // Feet
            HStack(spacing: 10 * scale) {
                Capsule()
                    .fill(Color(red: 0.18, green: 0.55, blue: 0.30))
                    .frame(width: 10 * scale, height: 6 * scale)
                Capsule()
                    .fill(Color(red: 0.18, green: 0.55, blue: 0.30))
                    .frame(width: 10 * scale, height: 6 * scale)
            }
            .offset(y: 24 * scale)

            // Mood-specific extras
            moodExtras
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                bounce = true
            }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.2)) {
                wiggle = true
            }
            // Blink loop
            startBlinking()
        }
    }

    // MARK: - Leaf

    private var leaf: some View {
        ZStack {
            // Stem
            Capsule()
                .fill(Color(red: 0.25, green: 0.65, blue: 0.35))
                .frame(width: 3 * scale, height: 12 * scale)

            // Leaf shape
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.40, green: 0.90, blue: 0.45), Color(red: 0.25, green: 0.75, blue: 0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 14 * scale, height: 10 * scale)
                .rotationEffect(.degrees(-20))
                .offset(x: 6 * scale, y: -8 * scale)
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
            // Eyes
            HStack(spacing: 12 * scale) {
                eye(closed: blink)
                eye(closed: blink)
            }
            // Smile
            SmileShape()
                .stroke(Color(red: 0.12, green: 0.40, blue: 0.20), lineWidth: 2 * scale)
                .frame(width: 14 * scale, height: 6 * scale)
        }
        .offset(y: -2 * scale)
    }

    private var excitedFace: some View {
        VStack(spacing: 4 * scale) {
            HStack(spacing: 12 * scale) {
                starEye
                starEye
            }
            // Big open smile
            Ellipse()
                .fill(Color(red: 0.12, green: 0.40, blue: 0.20))
                .frame(width: 12 * scale, height: 8 * scale)
        }
        .offset(y: -2 * scale)
    }

    private var sleepyFace: some View {
        VStack(spacing: 4 * scale) {
            HStack(spacing: 12 * scale) {
                // Closed sleepy eyes (curved lines)
                Capsule()
                    .fill(Color(red: 0.12, green: 0.40, blue: 0.20))
                    .frame(width: 8 * scale, height: 2 * scale)
                Capsule()
                    .fill(Color(red: 0.12, green: 0.40, blue: 0.20))
                    .frame(width: 8 * scale, height: 2 * scale)
            }
            // Small o mouth
            Circle()
                .fill(Color(red: 0.12, green: 0.40, blue: 0.20))
                .frame(width: 6 * scale, height: 6 * scale)
        }
        .offset(y: -2 * scale)
    }

    private var tiredFace: some View {
        VStack(spacing: 5 * scale) {
            HStack(spacing: 12 * scale) {
                // Droopy eyes
                eye(closed: false)
                    .rotationEffect(.degrees(-10))
                eye(closed: false)
                    .rotationEffect(.degrees(10))
            }
            // Flat mouth
            Capsule()
                .fill(Color(red: 0.12, green: 0.40, blue: 0.20))
                .frame(width: 10 * scale, height: 2 * scale)
        }
        .offset(y: -2 * scale)
    }

    private var thinkingFace: some View {
        VStack(spacing: 4 * scale) {
            HStack(spacing: 12 * scale) {
                eye(closed: false)
                eye(closed: false)
                    .offset(y: -2 * scale) // One eye raised
            }
            // Wavy mouth
            Capsule()
                .fill(Color(red: 0.12, green: 0.40, blue: 0.20))
                .frame(width: 8 * scale, height: 2 * scale)
                .offset(x: 3 * scale)
        }
        .offset(y: -2 * scale)
    }

    private var surprisedFace: some View {
        VStack(spacing: 4 * scale) {
            HStack(spacing: 14 * scale) {
                // Big round eyes
                Circle()
                    .fill(Color(red: 0.12, green: 0.40, blue: 0.20))
                    .frame(width: 7 * scale, height: 7 * scale)
                Circle()
                    .fill(Color(red: 0.12, green: 0.40, blue: 0.20))
                    .frame(width: 7 * scale, height: 7 * scale)
            }
            // O mouth
            Circle()
                .stroke(Color(red: 0.12, green: 0.40, blue: 0.20), lineWidth: 2 * scale)
                .frame(width: 8 * scale, height: 8 * scale)
        }
        .offset(y: -2 * scale)
    }

    // MARK: - Eye helpers

    private func eye(closed: Bool) -> some View {
        Group {
            if closed {
                Capsule()
                    .fill(Color(red: 0.12, green: 0.40, blue: 0.20))
                    .frame(width: 7 * scale, height: 2 * scale)
            } else {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.12, green: 0.40, blue: 0.20))
                        .frame(width: 6 * scale, height: 6 * scale)
                    Circle()
                        .fill(.white)
                        .frame(width: 2.5 * scale, height: 2.5 * scale)
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

    // MARK: - Arms

    @ViewBuilder
    private var arms: some View {
        switch mood {
        case .cheering, .excited:
            // Arms up!
            HStack(spacing: 36 * scale) {
                Capsule()
                    .fill(Color(red: 0.30, green: 0.78, blue: 0.42))
                    .frame(width: 4 * scale, height: 14 * scale)
                    .rotationEffect(.degrees(-30))
                Capsule()
                    .fill(Color(red: 0.30, green: 0.78, blue: 0.42))
                    .frame(width: 4 * scale, height: 14 * scale)
                    .rotationEffect(.degrees(30))
            }
            .offset(y: -6 * scale)
        case .sleepy:
            // Arms down
            HStack(spacing: 34 * scale) {
                Capsule()
                    .fill(Color(red: 0.30, green: 0.78, blue: 0.42))
                    .frame(width: 4 * scale, height: 12 * scale)
                    .rotationEffect(.degrees(10))
                Capsule()
                    .fill(Color(red: 0.30, green: 0.78, blue: 0.42))
                    .frame(width: 4 * scale, height: 12 * scale)
                    .rotationEffect(.degrees(-10))
            }
            .offset(y: 4 * scale)
        default:
            // Normal arms
            HStack(spacing: 36 * scale) {
                Capsule()
                    .fill(Color(red: 0.30, green: 0.78, blue: 0.42))
                    .frame(width: 4 * scale, height: 12 * scale)
                    .rotationEffect(.degrees(-15))
                Capsule()
                    .fill(Color(red: 0.30, green: 0.78, blue: 0.42))
                    .frame(width: 4 * scale, height: 12 * scale)
                    .rotationEffect(.degrees(15))
            }
            .offset(y: 0)
        }
    }

    // MARK: - Mood extras

    @ViewBuilder
    private var moodExtras: some View {
        switch mood {
        case .sleepy:
            // Zzz bubbles
            ZzzBubbles(scale: scale)
                .offset(x: 24 * scale, y: -20 * scale)
        case .excited, .cheering:
            // Sparkles around
            SparkleRing(scale: scale)
        case .surprised:
            // Exclamation
            Text("!")
                .font(.system(size: 12 * scale, weight: .black, design: .rounded))
                .foregroundStyle(Color.vqYellow)
                .offset(x: 22 * scale, y: -24 * scale)
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
                    .offset(y: -34 * scale)
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
            ConfettiBurst()
        }
    }
}
