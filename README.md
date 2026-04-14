# IronMind

Built by Iron Foundry

IronMind is an AI-powered all-in-one fitness platform focused on helping people build consistency in both training and daily habits.

## Vision

Most fitness apps focus on tracking. IronMind focuses on discipline.

The goal is to give users a simple system they can rely on every day — train, track, and stay consistent. No distractions. No unnecessary features.

## Features

- **Workout** — Log training sessions, track sets/reps/weight, generate AI-built workouts tailored to your profile, and track personal records
- **Food Log** — Log meals, track daily calories and macros, manage nutrition targets
- **Dashboard** — See your progress at a glance — recent workouts, strength trends, and training summary
- **Wellness** — Log daily check-ins (sleep, mood, recovery), track body weight and measurements, build habits, and connect Apple Health / Health Connect
- **Profile** — Manage your lifter profile, strength goals, training preferences, profile photo, and app settings

## Brand

IronMind is part of Iron Foundry — built on the idea of forging yourself through pressure, consistency, and discipline.

---

## Tech Stack

- **Flutter** `3.41.x` / **Dart** `3.11.x`
- **Supabase** — Auth, database, and file storage
- **OpenAI** — AI workout generation
- **Apple Health / Health Connect** — Wellness data sync
- **Codemagic** — CI/CD

---

## Local Setup

**Requirements:** Flutter `3.41.x` or newer, Dart `3.11.x` or newer.

Install dependencies:

```bash
flutter pub get
```

Enable web support if needed:

```bash
flutter config --enable-web
```

See [SUPABASE_SETUP.md](SUPABASE_SETUP.md) for backend configuration.

## Running the App

Chrome preview:

```bash
flutter run -d chrome
```

Local helper script (uses bundled SDK):

```powershell
.\run_chrome.ps1
```

## Build & Checks

```bash
# Web build
flutter build web

# Static analysis
flutter analyze
```

---

## Project Structure

```
lib/
  config/         API keys and Supabase config
  models/         Data models
  screens/        All app screens
  services/       API, auth, health, local storage
  widgets/        Shared UI components
  theme.dart      Colors and typography
  main.dart       App entry point
```

---

## Author

Brandon Begley
