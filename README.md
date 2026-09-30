# HouseKeepr

[![Project Health Check](https://github.com/kianniek/HouseKeepr/actions/workflows/Project_Health_Check.yml/badge.svg)](https://github.com/kianniek/HouseKeepr/actions/workflows/Project_Health_Check.yml)

> A cross‑platform, shared household command center built with Flutter + Firebase.

This repository contains the Flutter app plus Firebase configuration, emulator helpers, and Cloud Functions.

# Repository contents

This is intentionally a code-only repository. Source code, tests, Firebase configuration, platform project files, scripts, and dependency manifests are tracked. Generated output, API documentation, design assets, symbols, IDE metadata, local secrets, and build caches are ignored so the Git history stays small.

The generated `docs/`, `build/`, `.dart_tool/`, and `debug_info/` directories are not required in a checkout. Recreate the relevant output with the normal Flutter/Dart commands:

```powershell
flutter pub get
dart doc .
flutter build web --release --dart-define-from-file=.env
```

Design and launcher assets are deliberately excluded. Restore or recreate them locally before running `flutter_launcher_icons`, platform packaging, or any feature that refers to media files. The project configuration remains in `flutter_launcher_icons.yaml` and `pubspec.yaml`.

Create a local `.env` from your Firebase/Dart-define values before running the app. Firebase platform configuration and service-account files are environment-specific; do not commit credentials. Generate Firebase client configuration with the FlutterFire CLI when a new Firebase project is used:

```powershell
flutterfire configure
```

---

## Repo layout

- `./` — Flutter app + Firebase config (this is the directory you `cd` into for Flutter commands)
- `./functions/` — Firebase Cloud Functions
- `./scripts/` — helper scripts (emulator runner, run-with-firebase, etc.)

## Getting started (developer)

### Prerequisites

- **Flutter** (Dart SDK is constrained by `./pubspec.yaml`)
- **A Firebase project** (or the Firebase emulators for tests)
- **For emulators:** Java (JRE/JDK) + Firebase CLI (`npm i -g firebase-tools`)

### Install

```powershell
flutter pub get
```

### Run

Most local runs use build-time Dart defines from a file:

```powershell
flutter run --dart-define-from-file=.env
```

If you prefer to pass values directly (example for web):

```powershell
flutter run -d chrome --dart-define-from-file=.env
```

If you want to run it in release mode (example for web):

```powershell
flutter run -d chrome --release --dart-define-from-file=.env
``` 

### Run tests

Unit + widget tests:

```powershell
Set-Location -LiteralPath .\housekeepr
flutter test --reporter expanded
```

Integration tests (Firestore emulator) on Windows PowerShell:

```powershell
Set-Location -LiteralPath .\housekeepr
.\scripts\run_emulator_and_tests.ps1
```

To run a single integration test:

```powershell
.\scripts\run_emulator_and_tests.ps1 -TestPath 'test/integration/firestore_task_repository_emulator_rest_test.dart'
```

---

## Cloud Functions

This repo includes a Cloud Function used to join a household via an invite code.

Deploy (from `./functions`):

```bash
cd ./functions
npm install
firebase deploy --only functions
```

## Deployment

Standard Flutter builds apply (Android/iOS/Desktop/Web). Example:

```powershell
Set-Location -LiteralPath .\
flutter build web --release --dart-define-from-file=.env
```

## Contributing

- Create a feature branch, keep changes focused, and add/adjust tests when appropriate.
- Prefer the existing patterns (**BLoC/Cubits**, repositories, and local-first sync) over introducing new architecture.
