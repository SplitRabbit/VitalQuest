# VitalQuest

A gamified iOS health app that turns your Apple Watch data into personalized recovery, sleep, and activity scores -- with adaptive quests, XP progression, and on-device ML predictions.

## What It Does

- **Health Scores**: Computes Recovery, Sleep, Activity, and Readiness scores from HealthKit data using baseline-relative scoring (HRV, resting HR, sleep stages, step counts, etc.)
- **Adaptive Quests**: Generates daily and weekly challenges scaled to your personal baselines -- not generic step goals
- **On-Device ML**: Trains CoreML models locally to predict next-day recovery and forecast sleep quality
- **XP & Streaks**: Earn experience points for completing quests and maintaining streaks, with leveling progression
- **Activity Feed**: Timeline of health events, quest completions, achievements, and score changes
- **Journal**: Log subjective notes (mood, energy, soreness) alongside objective health data
- **Data Export**: Export raw health samples and analytics for external analysis

## Tech Stack

- **Swift 5** / **SwiftUI** -- declarative UI with iOS 18+ features
- **HealthKit** -- real-time health data ingestion (heart rate, HRV, sleep, steps, workouts)
- **SwiftData** -- persistent storage for quests, journal entries, snapshots, and baselines
- **CoreML / CreateML** -- on-device model training and inference for recovery and sleep prediction
- **Observation framework** -- reactive state management

## Architecture

```
App/                  Entry point and root navigation
Models/               SwiftData models (Quest, Activity, DailySnapshot, UserProfile, etc.)
Services/
  HealthKitManager    HealthKit authorization and data queries
  ScoringEngine       Baseline-relative score computation (Recovery, Sleep, Activity)
  BaselineEngine      Rolling statistical baselines with ln-transform normalization
  MLModelManager      On-device CoreML training and prediction pipeline
  QuestEngine         Adaptive quest generation and evaluation
  XPEngine            Experience point calculations and level progression
  StreakManager        Streak tracking with freeze mechanics
  FeedService         Activity feed aggregation
  AnalyticsEngine     Trend analysis and population comparisons
ViewModels/           Dashboard state coordination
Views/                SwiftUI screens (Dashboard, Scores, Quests, Feed, Journal, Profile)
  Components/         Reusable UI (ScoreRing, QuestCard, XPBar, Mascot, etc.)
```

## Status

Active development. Currently runs on iPhone with HealthKit data from Apple Watch.
