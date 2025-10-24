# housekeepr

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Tests

This repository includes a suite of unit and widget tests. Run them with:

```powershell
flutter test --reporter expanded
```

Included test files:

- `test/task_model_test.dart` — model roundtrip tests for `Task` and `SubTask`.
- `test/write_queue_test.dart` — tests for `WriteQueue` migration, retry and resume behavior.
- `test/widget_test.dart` — Flutter default widget smoke test (basic app build).
- `test/test_utils.dart` — test utilities (in-memory SharedPreferences) used by other tests.
- `test/repositories_test.dart` — repository CRUD tests for `TaskRepository` and `ShoppingRepository`.
- `test/cubits_test.dart` — cubit unit tests for `TaskCubit`, `ShoppingCubit`, and `UserCubit`.
- `test/widgets/task_add_dialog_test.dart` — widget test for the Add task dialog and cubit interaction.
- `test/widgets/member_picker_test.dart` — widget smoke test for the `MemberPicker` component.

All tests passed in the local environment when run during development.

## Running the Firestore emulator + integration tests (Windows PowerShell)

This repository includes integration tests that exercise the Firestore emulator. A small helper PowerShell script is provided at `scripts/run_emulator_and_tests.ps1` to make running the emulator and tests easier on Windows.

Prerequisites:
- `firebase-tools` on PATH (install with `npm i -g firebase-tools`)
- Java JRE/JDK for the emulator
- `flutter` on PATH

Basic usage (from the `housekeepr` project directory):

```powershell
# Run all integration tests (default: test/integration)
Set-Location -LiteralPath 'c:\path\to\housekeepr\housekeepr'
.\scripts\run_emulator_and_tests.ps1

# Run a single integration test file
.\scripts\run_emulator_and_tests.ps1 -TestPath 'test/integration/firestore_task_repository_emulator_rest_test.dart'
```

What the script does:
- Reads `firebase.json` for configured emulator host/port (falls back to `127.0.0.1:8080`).
- Tries `firebase emulators:exec` to start the emulator and run the tests (clean lifecycle).
- If the port is already in use, it will attempt to run tests against the existing emulator by setting `FIRESTORE_EMULATOR_HOST`.

If you run into a port conflict, stop the other process using the configured port (usually `8080`) or pass a different host/port in your `firebase.json`.

## Architecture & Integrations (Mermaid)

The diagram below shows the major app components, state flow (Cubits), local storage, and external integrations (Firebase and Google Sign-In).

```mermaid
flowchart LR
	subgraph App[HouseKeepr Flutter App]
		UI[UI Widgets\n(ProfileMenu, ProfilePage, Dashboard, Tasks, Shopping)]
		Cubits[State Layer\n(TaskCubit, ShoppingCubit, UserCubit)]
		Repos[Local Repos\n(TaskRepository, ShoppingRepository)]
		WriteQ[WriteQueue]
		Cropper[SimpleCropper]
	end

	subgraph Firebase[Firebase Services]
		Auth[Firebase Auth]
		Firestore[Cloud Firestore]
		Storage[Firebase Storage]
	end

	Google[Google Sign-In]

	UI --> Cubits
	Cubits --> Repos
	Cubits -->|enqueue remote ops| WriteQ
	WriteQ -->|executes| Firestore
	Repos -. local cache .-> Shared[SharedPreferences]
	Shared --- Repos
	ProfilePage --> Cropper
	Cropper --> ProfilePage

	Cubits -->|sync service| Firestore
	UI -->|sign in/out| Auth
	Auth -->|user profile| Firestore
	ProfilePage -->|upload image| Storage
	UI -->|Google sign in| Google
	Google -->|credential| Auth

	classDef ext fill:#f9f,stroke:#333,stroke-width:1px;
	class Firebase,Google ext;
```

Notes:
- Cubits are the single source of truth for UI state; FirestoreSyncService keeps Cubits synced with remote Firestore documents for the signed-in user.
- `WriteQueue` persists operations locally (via SharedPreferences) and retries them when a remote repository or network is available.
- `ProfilePage` uses `SimpleCropper` to crop/rotate images client-side, resizes/compresses using the `image` package, then uploads JPEGs to `users/{uid}/profile.jpg` in Firebase Storage and updates both Firebase Auth profile and the Firestore `users/{uid}` document.
- Google Sign-In is used on non-web platforms to obtain credentials for Firebase Auth; on web the FirebaseAuth popup flow is used.


## Build-time Firebase configuration

This project reads Firebase configuration from Dart environment defines so you can avoid hard-coding values into source files. You can provide these at build time using `--dart-define`.

Local example (web):

```powershell
flutter run -d chrome \
	--dart-define=FIREBASE_WEB_API_KEY=AIza... \
	--dart-define=FIREBASE_PROJECT_ID=your-project-id \
	--dart-define=FIREBASE_AUTH_DOMAIN=your-app.firebaseapp.com \
	--dart-define=FIREBASE_APP_ID=1:... \
	--dart-define=FIREBASE_MEASUREMENT_ID=G-...
```

Platform-specific keys are also supported; set `FIREBASE_ANDROID_API_KEY`, `FIREBASE_IOS_API_KEY`, etc., if needed.

CI / GitHub Actions

Create repository secrets (Settings → Secrets) for the values you need (example names below), then use the provided workflow to build the web app with defines.

- FIREBASE_WEB_API_KEY
- FIREBASE_PROJECT_ID
- FIREBASE_AUTH_DOMAIN
- FIREBASE_APP_ID
- FIREBASE_MEASUREMENT_ID

The included workflow `.github/workflows/build-web.yml` demonstrates how to pass these secrets into the `flutter build web` command using `--dart-define`.

Note: Client Firebase API keys are not secret in the sense that they are embedded in the client bundle for web/mobile; these measures are mostly for preventing accidental commits and for convenient build-time configuration.

## Quick: PowerShell local env vars

If you prefer to set environment variables in PowerShell (instead of using `--dart-define`) you can export the platform keys before running the app. Replace the placeholder values with the values from your Firebase project.

Example (Android):

```powershell
$env:FIREBASE_ANDROID_API_KEY = 'AIza...'
$env:FIREBASE_ANDROID_APP_ID = '1:1234567890:android:abcdef'
$env:FIREBASE_PROJECT_ID = 'your-firebase-project-id'
$env:FIREBASE_MESSAGING_SENDER_ID = '1234567890'
$env:FIREBASE_STORAGE_BUCKET = 'your-firebase-project-id.appspot.com'

flutter run
```

Example (Web):

```powershell
$env:FIREBASE_WEB_API_KEY = 'AIza...'
$env:FIREBASE_WEB_APP_ID = '1:1234567890:web:abcdef'
$env:FIREBASE_PROJECT_ID = 'your-firebase-project-id'
$env:FIREBASE_AUTH_DOMAIN = 'your-app.firebaseapp.com'
$env:FIREBASE_MEASUREMENT_ID = 'G-XXXX'

flutter run -d chrome
```

Notes:
- These environment variables are only present in the current PowerShell session. Opening a new terminal will require re-setting them.
- For CI, prefer using `--dart-define` or repository secrets as shown above.
