# Iron Mind

Built by Iron Foundry

Iron Mind is a fitness and discipline tracking app focused on helping people build consistency in both training and daily habits.

## Vision

Most fitness apps focus on tracking. Iron Mind focuses on discipline.

The goal is to give users a simple system they can rely on every day:
- train
- track
- stay consistent

No distractions. No unnecessary features.

## Core Features

- Workout tracking (sets, reps, weight)
- Progress tracking (body weight, photos)
- Nutrition tracking
- Daily check-ins (habits and mindset)
- Streak tracking for consistency

## Roadmap

- User accounts and authentication
- Dashboard with daily overview
- Expanded progress tracking
- Habit streak system
- Community and coaching features

## Brand

Iron Mind is part of Iron Foundry.

Iron Foundry represents the idea of building yourself through pressure, consistency, and discipline.

## Status

Early development

## Flutter Setup

Use Flutter `3.41.x` or newer with Dart `3.11.x` or newer.

For local preview in Chrome:

```bash
flutter config --enable-web
flutter pub get
flutter run -d chrome
```

This repo also includes a local runner that uses the bundled SDK:

```powershell
.\run_chrome.ps1
```

That runs the app with Flutter hot reload in Chrome. Saving code in your editor should trigger refreshes, and you can use `r` in the terminal for a manual hot reload.

If you want to verify the web build before deploying:

```bash
flutter build web
```

## Author

Brandon Begley
