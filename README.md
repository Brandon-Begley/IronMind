# Iron Mind App

This folder contains the active Flutter application for Iron Mind.

For the high-level product overview and brand description, see the repo root [README](../README.md).

## What Is Here

- Flutter app source in `lib/`
- Platform projects for `android/`, `ios/`, `macos/`, `linux/`, `windows/`, and `web/`
- Codemagic config in `codemagic.yaml`
- Supabase setup notes in `SUPABASE_SETUP.md`

## Local Setup

Use Flutter `3.41.x` or newer with Dart `3.11.x` or newer.

Install dependencies:

```bash
flutter pub get
```

Enable web support if needed:

```bash
flutter config --enable-web
```

## Running The App

For a normal Chrome preview:

```bash
flutter run -d chrome
```

This project also includes a local helper script that uses the bundled SDK:

```powershell
.\run_chrome.ps1
```

## Build Check

To verify the web build:

```bash
flutter build web
```

To run analyzer checks:

```bash
flutter analyze
```

## Notes

- The active app now lives in this `IronMind-main/` folder.
- The older `IronMind-push/` folder is only a local backup and is no longer the primary tracked app.

## Author

Brandon Begley
