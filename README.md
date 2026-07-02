# IronMind

Built by Iron Foundry

IronMind is an AI-powered training and discipline app focused on workouts, consistency, progression, and mental toughness.

It helps users plan training, log workouts, review progress, stay disciplined, and use AI coaching to train more intelligently.

## What IronMind Is

IronMind is built around a focused training loop:

1. Set goals and training preferences.
2. Plan or generate a workout.
3. Train and log the session.
4. Review progress and history.
5. Adjust intelligently and stay consistent.

## What IronMind Is Not

IronMind is not currently trying to be a full nutrition tracker, meal logger, barcode scanner, meal database, or generic wellness app.

Nutrition logging was removed from the current MVP direction because it made the app too broad and diluted the training identity.

## Current Core Features

- Workout planning
- Workout logging
- Exercise history
- Progress tracking
- AI workout and coaching support
- Wellness/readiness check-ins that support training decisions
- Profile, goals, equipment, and training preferences

## Current Project Status

The project is being cleaned up and restructured.

- Official source of truth: this Flutter app directory on branch `V.06.03`.
- Duplicate local app versions are being consolidated.
- A stale duplicate copy has been archived locally under `Documents/IronMind-archive/` and marked deprecated in its old workspace.
- New development should happen only in the official app root.

## Roadmap

1. Codebase cleanup
2. Architecture refactor
3. Workout MVP
4. AI coaching
5. Progression tracking
6. Wellness/readiness support
7. Polish and release prep

## Tech Stack

- Flutter and Dart
- Supabase for auth, database, and file storage
- AI workout/coaching integrations
- Apple Health / Health Connect for training-relevant readiness data
- Codemagic for CI/CD

## Local Setup

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

Local helper script:

```powershell
.\run_chrome.ps1
```

## Build and Checks

```bash
flutter analyze
flutter build web
```

## Project Structure

The app is moving toward a feature-based architecture:

```text
lib/
  app/             App bootstrap, shell, routing, navigation
  core/            Theme, config, storage, platform integrations
  features/        Training, progress, discipline, readiness, AI coach, auth, profile
  shared/          Reusable UI components and cross-feature helpers
```

Current cleanup has started with:

```text
lib/core/theme/ironmind_theme.dart
lib/shared/widgets/common.dart
```

Feature screens and services are still being migrated gradually to preserve functionality.

## Author

Brandon Begley
