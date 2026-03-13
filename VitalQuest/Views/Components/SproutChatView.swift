import SwiftUI

struct SproutChatView: View {
    let snapshot: DailySnapshot?
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isTyping = false
    @FocusState private var inputFocused: Bool

    struct ChatMessage: Identifiable {
        let id = UUID()
        let text: String
        let isUser: Bool
        let timestamp = Date()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedMeshBackground()

                VStack(spacing: 0) {
                    // Chat messages
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(messages) { message in
                                    chatBubble(message)
                                        .id(message.id)
                                }

                                if isTyping {
                                    typingIndicator
                                        .id("typing")
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .onChange(of: messages.count) { _, _ in
                            if let lastID = messages.last?.id {
                                withAnimation {
                                    proxy.scrollTo(lastID, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: isTyping) { _, typing in
                            if typing {
                                withAnimation {
                                    proxy.scrollTo("typing", anchor: .bottom)
                                }
                            }
                        }
                    }

                    // Quick reply chips
                    if !isTyping {
                        quickReplies
                    }

                    // Input bar
                    inputBar
                }
            }
            .navigationTitle("Chat with Sproutie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.vqGreen)
                }
            }
        }
        .onAppear {
            sendGreeting()
        }
    }

    // MARK: - Chat Bubble

    private func chatBubble(_ message: ChatMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 60)
            } else {
                Mascot(mood: sproutMood, size: 28)
            }

            Text(message.text)
                .font(.system(size: 15))
                .foregroundStyle(message.isUser ? .white : Color.vqTextPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(message.isUser ? Color.vqGreen : Color.vqCardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            message.isUser ? Color.clear : Color.vqTextPrimary.opacity(0.06),
                            lineWidth: 1
                        )
                )

            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Mascot(mood: .thinking, size: 28)

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.vqTextSecondary.opacity(0.4))
                        .frame(width: 7, height: 7)
                        .offset(y: isTyping ? -4 : 0)
                        .animation(
                            .easeInOut(duration: 0.4)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: isTyping
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.vqCardBackground)
            )

            Spacer(minLength: 60)
        }
    }

    // MARK: - Quick Replies

    private var quickReplies: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                quickReplyChip("How am I doing?")
                quickReplyChip("Tips for today")
                quickReplyChip("Tell me a joke")
                quickReplyChip("Motivate me!")
                quickReplyChip("What should I focus on?")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func quickReplyChip(_ text: String) -> some View {
        Button {
            sendUserMessage(text)
        } label: {
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.vqGreen)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.vqGreen.opacity(0.1))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.vqGreen.opacity(0.25), lineWidth: 1)
                )
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Talk to Sproutie...", text: $inputText)
                .font(.system(size: 15))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.vqCardBackground)
                )
                .overlay(
                    Capsule()
                        .stroke(Color.vqTextPrimary.opacity(0.08), lineWidth: 1)
                )
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit {
                    guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    sendUserMessage(inputText)
                    inputText = ""
                }

            Button {
                guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                sendUserMessage(inputText)
                inputText = ""
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        inputText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.vqTextSecondary.opacity(0.3)
                            : Color.vqGreen
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.vqBackground)
    }

    // MARK: - Chat Logic

    private var sproutMood: MascotMood {
        guard let snap = snapshot else { return .thinking }
        let avg = [snap.recoveryScore, snap.sleepScore, snap.activityScore]
            .compactMap { $0 }
        let score = avg.isEmpty ? 0 : avg.reduce(0, +) / Double(avg.count)
        switch score {
        case 80...100: return .cheering
        case 60..<80: return .happy
        case 40..<60: return .thinking
        default: return .tired
        }
    }

    private func sendGreeting() {
        let recovery = snapshot?.recoveryScore ?? 0
        let sleep = snapshot?.sleepScore ?? 0
        let activity = snapshot?.activityScore ?? 0
        let greeting = SproutDialogue.pick(recovery: recovery, sleep: sleep, activity: activity)
        messages.append(ChatMessage(text: greeting, isUser: false))

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            messages.append(ChatMessage(
                text: "Tap a quick reply or type anything — I love chatting!",
                isUser: false
            ))
        }
    }

    private func sendUserMessage(_ text: String) {
        messages.append(ChatMessage(text: text, isUser: true))
        isTyping = true

        let delay = Double.random(in: 0.8...1.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            isTyping = false
            let response = generateResponse(to: text)
            messages.append(ChatMessage(text: response, isUser: false))
        }
    }

    private func generateResponse(to input: String) -> String {
        let lowered = input.lowercased()
        let recovery = snapshot?.recoveryScore ?? 0
        let sleep = snapshot?.sleepScore ?? 0
        let activity = snapshot?.activityScore ?? 0

        // "How am I doing?" / status check
        if lowered.contains("how am i") || lowered.contains("doing") || lowered.contains("status") {
            return statusResponse(recovery: recovery, sleep: sleep, activity: activity)
        }

        // Tips
        if lowered.contains("tip") || lowered.contains("advice") || lowered.contains("suggest") || lowered.contains("should i") || lowered.contains("focus") {
            return tipsResponse(recovery: recovery, sleep: sleep, activity: activity)
        }

        // Jokes
        if lowered.contains("joke") || lowered.contains("funny") || lowered.contains("laugh") {
            return jokes.randomElement()!
        }

        // Motivation
        if lowered.contains("motivat") || lowered.contains("inspire") || lowered.contains("pump") || lowered.contains("encourage") {
            return motivation.randomElement()!
        }

        // Sleep related
        if lowered.contains("sleep") || lowered.contains("tired") || lowered.contains("rest") {
            if sleep >= 80 { return "Your sleep was great last night! Keep that bedtime routine going." }
            if sleep >= 60 { return "Sleep was okay but could be better. Try winding down 30 minutes earlier tonight." }
            return "Sleep needs some love! Try no screens an hour before bed and keep your room cool. You'll feel so much better."
        }

        // Exercise / activity
        if lowered.contains("exercise") || lowered.contains("workout") || lowered.contains("active") || lowered.contains("move") {
            if activity >= 80 { return "You're crushing the activity game! Just make sure to balance it with recovery." }
            if activity >= 60 { return "Good activity levels! A brisk walk or quick workout could push it even higher." }
            return "Let's get moving! Even a 10-minute walk can boost your mood and your score."
        }

        // Heart rate
        if lowered.contains("heart") || lowered.contains("rhr") || lowered.contains("hrv") {
            if let rhr = snapshot?.restingHeartRate {
                let quality = rhr < 60 ? "That's really solid" : rhr < 70 ? "That's in a healthy range" : "A bit elevated — stress or less sleep can do that"
                return "Your resting heart rate is \(Int(rhr)) bpm. \(quality). Consistent cardio and good sleep help bring it down over time."
            }
            return "I don't have heart rate data for today yet. Check back after wearing your watch for a bit!"
        }

        // Weight
        if lowered.contains("weight") || lowered.contains("scale") {
            if let w = snapshot?.bodyMass {
                return "Your latest weight is \(String(format: "%.1f", w)) kg. Remember, daily fluctuations are totally normal — focus on the weekly trend!"
            }
            return "No weight data yet today. Step on the scale and it'll sync through Apple Health!"
        }

        // Gratitude / thanks
        if lowered.contains("thank") || lowered.contains("love you") || lowered.contains("appreciate") {
            return thankYou.randomElement()!
        }

        // Hello / greeting
        if lowered.contains("hello") || lowered.contains("hi") || lowered.contains("hey") || lowered.contains("sup") {
            return greetings.randomElement()!
        }

        // Fallback — context-aware
        return SproutDialogue.pick(recovery: recovery, sleep: sleep, activity: activity)
    }

    // MARK: - Response Generators

    private func statusResponse(recovery: Double, sleep: Double, activity: Double) -> String {
        let scores = [(recovery, "Recovery"), (sleep, "Sleep"), (activity, "Activity")]
        let best = scores.max(by: { $0.0 < $1.0 })!
        let worst = scores.min(by: { $0.0 < $1.0 })!
        let avg = (recovery + sleep + activity) / 3

        if avg >= 80 {
            return "You're on fire today! All scores looking great. \(best.1) is leading at \(Int(best.0)). Keep this energy going!"
        }
        if avg >= 60 {
            return "Pretty solid day! \(best.1) is your strongest at \(Int(best.0)). \(worst.1) could use a bump at \(Int(worst.0)) — but overall, nice work."
        }
        if avg >= 40 {
            return "Mixed bag today. \(best.1) is doing okay at \(Int(best.0)), but \(worst.1) is struggling at \(Int(worst.0)). Focus on \(worst.1.lowercased()) and tomorrow will be better!"
        }
        return "Tough day — \(worst.1) is at \(Int(worst.0)). That's okay though! Rest up, hydrate, and give yourself some grace. Tomorrow's a fresh start."
    }

    private func tipsResponse(recovery: Double, sleep: Double, activity: Double) -> String {
        if sleep < 60 {
            return "Top tip: prioritize sleep tonight! Dim the lights early, skip the late-night scrolling, and aim for 7-8 hours. Everything else improves when sleep does."
        }
        if activity < 50 {
            return "Try to get some movement in! A 20-minute walk or even some stretching can make a big difference. Your body's ready for it."
        }
        if recovery < 50 {
            return "Recovery's low — today might be a good day for gentle movement, hydration, and early bedtime. Let your body catch up."
        }
        if recovery >= 80 && activity < 70 {
            return "Your body is fully recovered! This is the perfect day to push yourself a bit — go for that run or hit the gym."
        }
        return "You're doing well! Stay hydrated, take breaks to stretch, and maybe try something new today — even a short meditation counts."
    }

    private let jokes = [
        "Why did the heart rate monitor break up with the step counter? It couldn't keep up with the pace! ...I'll be here all week.",
        "What do you call a sleeping dinosaur? A dino-snore! ...Get it? Because sleep is important? I'm hilarious.",
        "I told my watch I wanted to lose weight. It said 'stop asking me and start walking!' Harsh but fair.",
        "Why don't scientists trust atoms? Because they make up everything! ...Sorry, that has nothing to do with health. I just like it.",
        "What's Sproutie's favorite exercise? Lunges. Because they really help me GROW. Okay I'll stop.",
        "How do trees get on the internet? They log in! ...Just like you should log your health data!",
    ]

    private let motivation = [
        "Every step you take is literally building a better you. Your body is keeping score, and you're winning.",
        "You showed up today. That alone puts you ahead of yesterday's version of yourself.",
        "Progress isn't always linear, but it's always there if you're putting in the work. And you are!",
        "The best workout is the one you actually do. No judgment, just movement.",
        "Think about how far you've come! Past-you would be seriously impressed.",
        "You're not competing with anyone else — just yesterday's version of yourself. And you're crushing it.",
    ]

    private let thankYou = [
        "Aww, you're making me blush! (Can plants blush? I think I can.)",
        "Right back at you! I love being your health buddy.",
        "That means the world to me! Let's keep growing together.",
        "You're the best! Seriously, my favorite human.",
    ]

    private let greetings = [
        "Hey there! Ready to check in on today's stats?",
        "Hi! I was just thinking about your scores. Want the scoop?",
        "Yo! Great to see you. What's on your mind?",
        "Hello, hello! I've been crunching your numbers. Ask me anything!",
    ]
}

#Preview {
    SproutChatView(snapshot: .mockToday())
}
