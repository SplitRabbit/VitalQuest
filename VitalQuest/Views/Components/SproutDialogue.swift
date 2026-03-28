import Foundation

/// Context-aware dialogue for Nudge based on today's scores + recent trends
enum SproutDialogue {

    /// Recent snapshot summary for trend detection
    struct TrendContext {
        let avgRecovery: Double
        let avgSleep: Double
        let avgActivity: Double
        let daysLowActivity: Int      // consecutive recent days with activity < 40
        let daysLowSleep: Int         // consecutive recent days with sleep < 40
        let daysHighRecovery: Int     // consecutive recent days with recovery >= 70
        let activityTrending: Trend   // comparing last 3 days to prior 4
        let recoveryTrending: Trend
        let sleepTrending: Trend
        let dayCount: Int             // how many days of data we have

        enum Trend { case up, down, flat }
    }

    /// Build trend context from recent snapshots (newest first or oldest first — we sort internally)
    static func buildContext(from snapshots: [DailySnapshot]) -> TrendContext {
        let sorted = snapshots.sorted { $0.date > $1.date } // newest first

        let recoveries = sorted.compactMap(\.recoveryScore)
        let sleeps = sorted.compactMap(\.sleepScore)
        let activities = sorted.compactMap(\.activityScore)

        let avgR = recoveries.isEmpty ? 0 : recoveries.reduce(0, +) / Double(recoveries.count)
        let avgS = sleeps.isEmpty ? 0 : sleeps.reduce(0, +) / Double(sleeps.count)
        let avgA = activities.isEmpty ? 0 : activities.reduce(0, +) / Double(activities.count)

        // Consecutive days of low activity (from most recent backwards, skip today at index 0)
        var lowActivityStreak = 0
        for snap in sorted.dropFirst() {
            if (snap.activityScore ?? 50) < 40 { lowActivityStreak += 1 } else { break }
        }

        var lowSleepStreak = 0
        for snap in sorted.dropFirst() {
            if (snap.sleepScore ?? 50) < 40 { lowSleepStreak += 1 } else { break }
        }

        var highRecoveryStreak = 0
        for snap in sorted {
            if (snap.recoveryScore ?? 0) >= 70 { highRecoveryStreak += 1 } else { break }
        }

        func trend(_ scores: [Double]) -> TrendContext.Trend {
            guard scores.count >= 4 else { return .flat }
            let recent = Array(scores.prefix(3))
            let prior = Array(scores.dropFirst(3))
            guard !recent.isEmpty, !prior.isEmpty else { return .flat }
            let recentAvg = recent.reduce(0, +) / Double(recent.count)
            let priorAvg = prior.reduce(0, +) / Double(prior.count)
            let diff = recentAvg - priorAvg
            if diff > 8 { return .up }
            if diff < -8 { return .down }
            return .flat
        }

        return TrendContext(
            avgRecovery: avgR,
            avgSleep: avgS,
            avgActivity: avgA,
            daysLowActivity: lowActivityStreak,
            daysLowSleep: lowSleepStreak,
            daysHighRecovery: highRecoveryStreak,
            activityTrending: trend(activities),
            recoveryTrending: trend(recoveries),
            sleepTrending: trend(sleeps),
            dayCount: sorted.count
        )
    }

    /// Pick dialogue considering today's scores AND recent trends
    static func pick(recovery: Double, sleep: Double, activity: Double, trends: TrendContext? = nil) -> String {
        // Try trend-based messages first (they're more insightful)
        if let t = trends, t.dayCount >= 3 {
            if let msg = trendMessage(recovery: recovery, sleep: sleep, activity: activity, trends: t) {
                return msg
            }
        }

        // Fall through to today-only logic
        return todayMessage(recovery: recovery, sleep: sleep, activity: activity)
    }

    // MARK: - Trend-based messages

    private static func trendMessage(recovery: Double, sleep: Double, activity: Double, trends: TrendContext) -> String? {
        let r = tier(recovery)
        let a = tier(activity)
        let s = tier(sleep)

        // Great recovery but days of low activity — nudge to move
        if r >= .good && trends.daysLowActivity >= 2 {
            return recoveryButInactive.randomElement()!
        }

        // Activity trending up — celebrate momentum
        if trends.activityTrending == .up && a >= .fair {
            return activityTrendingUp.randomElement()!
        }

        // Recovery trending down — warn about overtraining or stress
        if trends.recoveryTrending == .down && r <= .fair {
            return recoveryTrendingDown.randomElement()!
        }

        // Multiple days of poor sleep
        if trends.daysLowSleep >= 2 {
            return sleepStreak.randomElement()!
        }

        // Sleep trending up — positive reinforcement
        if trends.sleepTrending == .up && s >= .good {
            return sleepTrendingUp.randomElement()!
        }

        // Multi-day high recovery streak
        if trends.daysHighRecovery >= 4 {
            return recoveryStreak.randomElement()!
        }

        // Activity trending down from good levels
        if trends.activityTrending == .down && trends.avgActivity >= 55 {
            return activitySlipping.randomElement()!
        }

        // All averages solid over the week
        if trends.avgRecovery >= 65 && trends.avgSleep >= 65 && trends.avgActivity >= 65 {
            return weekSolid.randomElement()!
        }

        return nil // no strong trend signal — fall through to today-only
    }

    // MARK: - Today-only messages

    private static func todayMessage(recovery: Double, sleep: Double, activity: Double) -> String {
        let r = tier(recovery)
        let s = tier(sleep)
        let a = tier(activity)

        // No data yet
        if recovery == 0 && sleep == 0 && activity == 0 {
            return noData.randomElement()!
        }

        // All three same tier
        if r == s && s == a {
            switch r {
            case .excellent: return allExcellent.randomElement()!
            case .good: return allGood.randomElement()!
            case .fair: return allFair.randomElement()!
            case .low: return allLow.randomElement()!
            }
        }

        // One standout score
        if r >= .good && s == .low && a == .low { return recoveryCarries.randomElement()! }
        if s >= .good && r == .low && a == .low { return sleepCarries.randomElement()! }
        if a >= .good && r == .low && s == .low { return activityCarries.randomElement()! }

        // One weak link
        if r == .low && s >= .good && a >= .good { return recoveryLagging.randomElement()! }
        if s == .low && r >= .good && a >= .good { return sleepLagging.randomElement()! }
        if a == .low && r >= .good && s >= .good { return activityLagging.randomElement()! }

        // Recovery + Sleep good but Activity fair
        if r >= .good && s >= .good && a == .fair { return needMoreMovement.randomElement()! }

        // Activity high but Recovery low (overtraining vibes)
        if a >= .good && r <= .fair { return overtraining.randomElement()! }

        // Sleep low, everything else okay
        if s <= .fair && r >= .fair && a >= .fair { return sleepStruggles.randomElement()! }

        // Recovery excellent, others mixed
        if r == .excellent { return recoveryShining.randomElement()! }

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

    // MARK: - Trend dialogue pools

    // Recovery good but multiple days without activity
    private static let recoveryButInactive = [
        "Great recovery... time to get up and moving!",
        "Your body's been resting well — it's ready for action!",
        "Fully recharged! A few quiet days is fine, but let's use that energy.",
        "You've recovered beautifully. Even a short walk would feel amazing.",
        "All that rest is paying off. Your body's practically begging to move!",
        "Recovery on point, but those legs need some love. Let's go!",
    ]

    // Activity trending up
    private static let activityTrendingUp = [
        "You've been building momentum all week. Keep it up!",
        "Activity trending up! I can feel the energy from here.",
        "More movement each day — you're on a real roll!",
        "That activity streak is looking beautiful. Stay with it!",
        "You've been getting more active lately. It shows!",
    ]

    // Recovery trending down
    private static let recoveryTrendingDown = [
        "Recovery's been dipping — maybe ease off a bit this week.",
        "Your body's been working hard. A lighter day could help.",
        "I'm noticing recovery trending down. Rest isn't lazy, it's smart.",
        "Recovery's slipping — listen to your body, it's trying to tell you something.",
        "Downward recovery trend... could be stress, sleep, or overtraining. Check in with yourself.",
    ]

    // Multiple days of poor sleep
    private static let sleepStreak = [
        "Sleep's been rough the last few days. Something on your mind?",
        "A few bad nights in a row — try winding down earlier tonight.",
        "Your sleep's been struggling. A bedtime routine could turn this around.",
        "I've noticed the sleep dip. Even small changes can make a big difference.",
        "Multiple nights of rough sleep... your body really needs a good rest.",
    ]

    // Sleep trending up
    private static let sleepTrendingUp = [
        "Your sleep's been improving! Whatever you're doing, keep doing it.",
        "Sleep trending up — your body is thanking you for it.",
        "Better sleep each night. That's the kind of trend I love!",
        "You've been sleeping better lately. It's showing in everything!",
    ]

    // Multi-day high recovery streak
    private static let recoveryStreak = [
        "Recovery's been strong for days! You're in a great rhythm.",
        "Consistent high recovery — this is what balance looks like.",
        "Your body's been in a great place all week. Well done!",
        "Day after day of solid recovery. You've found your groove!",
    ]

    // Activity starting to slip from a good baseline
    private static let activitySlipping = [
        "Activity's been dipping — don't let the momentum slip away!",
        "You were on a great activity run. Let's get back to it!",
        "Movement's been tapering off. A quick workout could reset things.",
        "I noticed activity trending down. Even 10 minutes helps!",
    ]

    // All weekly averages solid
    private static let weekSolid = [
        "Your week's been amazing across the board. Consistency is king!",
        "Solid averages all week — this is what long-term progress looks like.",
        "Recovery, sleep, AND activity all strong this week. Incredible.",
        "You've had an incredible stretch. Pat yourself on the back!",
        "Week-over-week, you're in a great place. Keep building!",
    ]

    // MARK: - Today-only dialogue pools

    private static let noData = [
        "Hey! I'm Nudge. Let's do this together!",
        "Pop on your watch and let's see those numbers! *bounces*",
        "No data yet — every journey starts somewhere.",
        "I'm ready when you are! Let's do this.",
        "Waiting on your health data... exciting times ahead!",
    ]

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

    private static let allGood = [
        "Solid across the board! Keep this energy going.",
        "Balanced and strong today. This is the way!",
        "Nice and steady — real progress looks like this.",
        "Good vibes all around. You're in a great spot!",
        "Everything's clicking today. Love to see it.",
        "Consistent effort pays off. Here's the proof!",
    ]

    private static let allFair = [
        "Getting there! Baby steps still count.",
        "Not bad! A few tweaks could make today great.",
        "We're building something — brick by brick!",
        "Okay day so far, but there's still time to level up.",
        "Fair across the board. A walk could boost everything!",
        "Room to grow in all three. You've got this.",
    ]

    private static let allLow = [
        "Rough day? That's okay. Be gentle with yourself.",
        "Rest is a superpower too. I've got you.",
        "Low scores happen. Tomorrow we bounce back!",
        "Your body's asking for a break. Listen to it.",
        "Couch mode: activated. No shame in that!",
        "Even heroes take rest days. This one's yours.",
        "Today's a cocoon day. Tomorrow you're a butterfly.",
    ]

    private static let recoveryCarries = [
        "Your body bounced back nicely! Now let's get moving.",
        "Recovery's strong — you've got the engine, now hit the road!",
        "Great recovery! Let's build on it with good sleep tonight.",
        "Body says 'I'm ready!' — just need sleep and steps to match.",
    ]

    private static let sleepCarries = [
        "Amazing sleep! That's the foundation. Now let's move!",
        "You slept like a champ! Time to put that energy to work.",
        "Great rest — your body's charged up. Maybe a walk?",
        "That sleep score though! Your pillow must be magical.",
    ]

    private static let activityCarries = [
        "Look at you go! Don't forget to rest up though.",
        "So much movement! Make sure to wind down tonight.",
        "All that activity is great — pair it with solid sleep!",
        "You've been busy! Your body will thank you for some rest.",
    ]

    private static let recoveryLagging = [
        "Your body wants a breather. Maybe ease up a bit?",
        "Sleep and activity are great, but recovery needs some love.",
        "You're doing a lot — let your body catch its breath!",
        "Recovery's lagging. Some stretches or meditation might help.",
        "Strong output but your body's waving a little flag.",
    ]

    private static let sleepLagging = [
        "Everything's great except sleep — prioritize bedtime tonight!",
        "Sleep's the one holding you back. Wind down earlier?",
        "Imagine if you nailed sleep too — you'd be unstoppable!",
        "Sleep is the missing piece. Try no screens before bed!",
        "So close to a perfect score. Just need those ZzZ's.",
        "Great recovery and activity! Now fix that sleep.",
    ]

    private static let activityLagging = [
        "All rested up — now get moving!",
        "Your body's ready for action! Even a short walk counts.",
        "Recovery and sleep are on point. Time to use that energy!",
        "You've got fuel in the tank — let's burn some of it.",
        "Fully charged with nowhere to go? Let's fix that!",
        "C'mon, join me for a walk! It'll be worth it.",
    ]

    private static let needMoreMovement = [
        "So close to a perfect day! Just a bit more movement.",
        "Almost there — a walk would make this day sparkle.",
        "Recovery and sleep are dialed in. Just needs more steps!",
        "Get those steps in and today becomes legendary.",
    ]

    private static let overtraining = [
        "Big activity day but recovery's low — easy does it!",
        "Love the hustle, but your body's saying 'slow down.'",
        "Impressive movement, but watch that recovery bar.",
        "Active but running on fumes — tomorrow should be lighter.",
        "Great effort! Just make sure rest is part of the plan.",
    ]

    private static let sleepStruggles = [
        "Tonight's mission: get to bed on time. You'll thank me!",
        "Sleep could use some love. Try a calming routine tonight.",
        "Better sleep would supercharge everything else!",
        "Pro tip: put the phone down a bit earlier tonight.",
    ]

    private static let recoveryShining = [
        "Recovery is sparkling today! Your body feels great.",
        "Top-tier recovery! You're primed for whatever comes next.",
        "That recovery bar is making me happy.",
        "Your body recovered beautifully. What a champ!",
    ]

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
