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

### Recreate icons and favicons

Place the source icon files at the paths referenced by `flutter_launcher_icons.yaml`, then regenerate every platform's launcher assets:

```powershell
New-Item -ItemType Directory -Force assets/icon | Out-Null
# Copy or create the local source PNG/ICO files in assets/icon/
flutter pub get
dart run flutter_launcher_icons
```

The configured source files are `adaptive_icon_foreground_dark.png`, `adaptive_icon_background_dark.png`, `adaptive_icon_monochrome.png`, and `favicon_dark.ico`. The generator creates the platform-specific Android, iOS, web, Windows, and macOS icon files. Light-mode source variants can also be placed in `assets/icon/` when needed; the available filenames are documented in `flutter_launcher_icons.yaml`.

For a web favicon or custom web icon, place the local file in `assets/icon/`, update the `web.image_path` value in `flutter_launcher_icons.yaml`, and run `dart run flutter_launcher_icons` again. For manually created images, fonts, audio, or other media used by the app, place them under the relevant local `assets/` subdirectory, declare that directory or file under the `assets:` section of `pubspec.yaml`, and run `flutter pub get` before building. These source files and generated outputs are intentionally ignored by Git, so each clone must restore them locally before packaging.

Create a local `.env` from your Firebase/Dart-define values before running the app. Firebase platform configuration and service-account files are environment-specific; do not commit credentials. Generate Firebase client configuration with the FlutterFire CLI when a new Firebase project is used:

```powershell
flutterfire configure
```

The `.env` file should contain the following keys. Replace each placeholder with the value from your Firebase project or Google Maps configuration:

```dotenv
FIREBASE_WEB_API_KEY=[YOUR_WEB_API_KEY]
FIREBASE_AUTH_DOMAIN=[YOUR_AUTH_DOMAIN]
FIREBASE_PROJECT_ID=[YOUR_PROJECT_ID]
FIREBASE_STORAGE_BUCKET=[YOUR_STORAGE_BUCKET]
FIREBASE_MESSAGING_SENDER_ID=[YOUR_MESSAGING_SENDER_ID]
FIREBASE_APP_ID=[YOUR_APP_ID]
FIREBASE_MEASUREMENT_ID=[YOUR_MEASUREMENT_ID]

FIREBASE_ANDROID_API_KEY=[YOUR_ANDROID_API_KEY]
FIREBASE_ANDROID_APP_ID=[YOUR_ANDROID_APP_ID]

FIREBASE_IOS_API_KEY=[YOUR_IOS_API_KEY]
FIREBASE_IOS_APP_ID=[YOUR_IOS_APP_ID]

FIREBASE_MACOS_API_KEY=[YOUR_MACOS_API_KEY]
FIREBASE_MACOS_APP_ID=[YOUR_MACOS_APP_ID]

FIREBASE_WINDOWS_API_KEY=[YOUR_WINDOWS_API_KEY]
FIREBASE_WINDOWS_APP_ID=[YOUR_WINDOWS_APP_ID]

MAPS_API_KEY=[YOUR_MAPS_API_KEY]
```

Keep `.env` local. It is ignored by Git and must be recreated for each clone.

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
