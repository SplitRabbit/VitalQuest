import Foundation

/// Context-aware dialogue for Sproutie based on the 3 score bars
enum SproutDialogue {

    /// Pick a line based on today's Recovery, Sleep, and Activity scores (0-100 each)
    static func pick(recovery: Double, sleep: Double, activity: Double) -> String {
        let r = tier(recovery)
        let s = tier(sleep)
        let a = tier(activity)

        // No data yet
        if recovery == 0 && sleep == 0 && activity == 0 {
            return noData.randomElement() ?? "Let's get started!"
        }

        // All three in the same tier
        if r == s && s == a {
            switch r {
            case .excellent: return allExcellent.randomElement()!
            case .good: return allGood.randomElement()!
            case .fair: return allFair.randomElement()!
            case .low: return allLow.randomElement()!
            }
        }

        // One standout score
        if r >= .good && s == .low && a == .low {
            return recoveryCarries.randomElement()!
        }
        if s >= .good && r == .low && a == .low {
            return sleepCarries.randomElement()!
        }
        if a >= .good && r == .low && s == .low {
            return activityCarries.randomElement()!
        }

        // One weak link
        if r == .low && s >= .good && a >= .good {
            return recoveryLagging.randomElement()!
        }
        if s == .low && r >= .good && a >= .good {
            return sleepLagging.randomElement()!
        }
        if a == .low && r >= .good && s >= .good {
            return activityLagging.randomElement()!
        }

        // Recovery + Sleep good but Activity fair
        if r >= .good && s >= .good && a == .fair {
            return needMoreMovement.randomElement()!
        }

        // Activity high but Recovery low (overtraining vibes)
        if a >= .good && r <= .fair {
            return overtraining.randomElement()!
        }

        // Sleep low, everything else okay
        if s <= .fair && r >= .fair && a >= .fair {
            return sleepStruggles.randomElement()!
        }

        // Recovery excellent, others mixed
        if r == .excellent {
            return recoveryShining.randomElement()!
        }

        // General fallbacks by average tier
        let avg = (recovery + sleep + activity) / 3.0
        switch tier(avg) {
        case .excellent: return generalExcellent.randomElement()!
        case .good: return generalGood.randomElement()!
        case .fair: return generalFair.randomElement()!
        case .low: return generalLow.randomElement()!
        }
    }

    // MARK: - Tier helper

    private enum Tier: Int, Comparable {
        case low, fair, good, excellent
        static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    private static func tier(_ score: Double) -> Tier {
        switch score {
        case 80...100: .excellent
        case 60..<80: .good
        case 40..<60: .fair
        default: .low
        }
    }

    // MARK: - Dialogue pools

    private static let noData = [
        "Hey! I'm Sproutie. Let's grow together!",
        "Pop on your watch and let's see those numbers!",
        "No data yet — every journey starts somewhere.",
        "I'm ready when you are! Let's do this.",
        "Waiting on your health data... exciting times ahead!",
    ]

    // All three excellent
    private static let allExcellent = [
        "You are CRUSHING it today! All three bars lit up!",
        "Recovery, sleep, AND activity all firing? Wow.",
        "This is what a perfect day looks like. Enjoy it!",
        "All green across the board! You should be proud.",
        "Legendary status today. The scores don't lie!",
        "Three for three! You're making this look easy.",
        "Peak performance. Cape optional, crown mandatory.",
        "I'm glowing because YOU'RE glowing right now!",
    ]

    // All three good
    private static let allGood = [
        "Solid across the board! Keep this energy going.",
        "Balanced and strong today. This is the way!",
        "Nice and steady — real progress looks like this.",
        "Good vibes all around. You're in a great spot!",
        "Everything's clicking today. Love to see it.",
        "Consistent effort pays off. Here's the proof!",
    ]

    // All three fair
    private static let allFair = [
        "Getting there! Baby steps still count.",
        "Not bad! A few tweaks could make today great.",
        "We're building something — brick by brick!",
        "Okay day so far, but there's still time to level up.",
        "Fair across the board. A walk could boost everything!",
        "Room to grow in all three. You've got this.",
    ]

    // All three low
    private static let allLow = [
        "Rough day? That's okay. Be gentle with yourself.",
        "Rest is a superpower too. I've got you.",
        "Low scores happen. Tomorrow we bounce back!",
        "Your body's asking for a break. Listen to it.",
        "Couch mode: activated. No shame in that!",
        "Even heroes take rest days. This one's yours.",
        "Today's a cocoon day. Tomorrow you're a butterfly.",
    ]

    // Recovery carrying
    private static let recoveryCarries = [
        "Your body bounced back nicely! Now let's get moving.",
        "Recovery's strong — you've got the engine, now hit the road!",
        "Great recovery! Let's build on it with good sleep tonight.",
        "Body says 'I'm ready!' — just need sleep and steps to match.",
    ]

    // Sleep carrying
    private static let sleepCarries = [
        "Amazing sleep! That's the foundation. Now let's move!",
        "You slept like a champ! Time to put that energy to work.",
        "Great rest — your body's charged up. Maybe a walk?",
        "That sleep score though! Your pillow must be magical.",
    ]

    // Activity carrying
    private static let activityCarries = [
        "Look at you go! Don't forget to rest up though.",
        "So much movement! Make sure to wind down tonight.",
        "All that activity is great — pair it with solid sleep!",
        "You've been busy! Your body will thank you for some rest.",
    ]

    // Recovery lagging
    private static let recoveryLagging = [
        "Your body wants a breather. Maybe ease up a bit?",
        "Sleep and activity are great, but recovery needs some love.",
        "You're doing a lot — let your body catch its breath!",
        "Recovery's lagging. Some stretches or meditation might help.",
        "Strong output but your body's waving a little flag.",
    ]

    // Sleep lagging
    private static let sleepLagging = [
        "Everything's great except sleep — prioritize bedtime tonight!",
        "Sleep's the one holding you back. Wind down earlier?",
        "Imagine if you nailed sleep too — you'd be unstoppable!",
        "Sleep is the missing piece. Try no screens before bed!",
        "So close to a perfect score. Just need those ZzZ's.",
        "Great recovery and activity! Now fix that sleep.",
    ]

    // Activity lagging
    private static let activityLagging = [
        "All rested up — now get moving!",
        "Your body's ready for action! Even a short walk counts.",
        "Recovery and sleep are on point. Time to use that energy!",
        "You've got fuel in the tank — let's burn some of it.",
        "Fully charged with nowhere to go? Let's fix that!",
        "C'mon, join me for a walk! It'll be worth it.",
    ]

    // Need more movement
    private static let needMoreMovement = [
        "So close to a perfect day! Just a bit more movement.",
        "Almost there — a walk would make this day sparkle.",
        "Recovery and sleep are dialed in. Just needs more steps!",
        "Get those steps in and today becomes legendary.",
    ]

    // Overtraining vibes
    private static let overtraining = [
        "Big activity day but recovery's low — easy does it!",
        "Love the hustle, but your body's saying 'slow down.'",
        "Impressive movement, but watch that recovery bar.",
        "Active but running on fumes — tomorrow should be lighter.",
        "Great effort! Just make sure rest is part of the plan.",
    ]

    // Sleep struggles
    private static let sleepStruggles = [
        "Tonight's mission: get to bed on time. You'll thank me!",
        "Sleep could use some love. Try a calming routine tonight.",
        "Better sleep would supercharge everything else!",
        "Pro tip: put the phone down a bit earlier tonight.",
    ]

    // Recovery shining
    private static let recoveryShining = [
        "Recovery is sparkling today! Your body feels great.",
        "Top-tier recovery! You're primed for whatever comes next.",
        "That recovery bar is making me happy.",
        "Your body recovered beautifully. What a champ!",
    ]

    // General fallbacks
    private static let generalExcellent = [
        "What a day! Everything's coming together!",
        "The numbers are looking fantastic. Keep it going!",
        "I can barely keep up with how well you're doing!",
        "This is the kind of day you'll look back on proudly.",
    ]

    private static let generalGood = [
        "Things are looking good! Keep the momentum going.",
        "Nice balance today. Small wins add up!",
        "You're in a good groove — stay with it!",
        "Steady and strong. That's how progress works.",
    ]

    private static let generalFair = [
        "Showing up IS the hard part — you did that!",
        "Mixed bag today, but it still counts.",
        "Can't be sparkly every day, and that's totally fine.",
        "Today's a stepping stone to something great.",
    ]

    private static let generalLow = [
        "Tough day, but I still think you're doing great.",
        "Be extra gentle with yourself today, okay?",
        "Low scores just mean tomorrow has room to shine.",
        "Bad day? More like a character development arc.",
        "It's okay. I'm here for the rough days too.",
    ]
}
