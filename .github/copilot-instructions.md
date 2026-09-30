<!--
AI coding instructions for contributors and automated agents working on HouseKeepr.
Keep concise, factual, and reference specific files/commands below.
-->

# HouseKeepr — Copilot instructions

**Purpose:** Provide targeted, actionable guidance so an AI coding agent can be productive immediately.

**Big Picture:**

- **App type:** Flutter app using Firebase for auth, Firestore, storage, and Cloud Functions. Main app lives in `./`.
- **Frontend:** Flutter app entry at `./lib/main.dart` — initializes Firebase and wires cubits, repositories, services, and the write-queue.
- **State & sync:** Local state is managed with `flutter_bloc` cubits (`./lib/cubits/*`) and a write-queue + sync service pattern (`./lib/services/write_queue.dart`, `firestore_sync_service.dart`). Remote persistence is implemented with repository classes in `./lib/firestore/*` (e.g., `FirestoreTaskRepository`).
- **Server-side:** Cloud Functions live in `./functions/` (entry: `index.js`). Functions are callable HTTPS functions and expect Firebase-admin usage.

**Key files to read first:**

- `./lib/main.dart` — Firebase init, auth flow, and app wiring.
- `./firebase.json` — emulator host/port and emulator config (used by test helpers).
- `./pubspec.yaml` — dependencies (shows `flutter_bloc`, Firebase packages, integration_test, etc.).
- `./analysis_options.yaml` — project lint rules (based on `flutter_lints`).
- `./functions/index.js` — example Cloud Function (`joinHouseholdByInviteCode`).
- `./scripts/*` — helper scripts (emulator/test runner, run-with-firebase, pre-commit installer).

**Project-specific patterns & conventions (do not guess — follow examples):**

- Write-queue pattern: optimistic local updates are enqueued in `WriteQueue` and later applied to either per-user (`FirestoreTaskRepository`) or household-scoped repos (`FirestoreHouseholdTaskRepository`). When modifying persistence logic, follow existing op types (`QueueOpType`) and attach op builders/failure handlers as in `main.dart`.
- Household membership: prefer `households.members` as the source-of-truth. Look for `HouseholdService` usage when changing membership logic.
- Cubit + repository separation: Cubits operate on local repositories (e.g., `TaskRepository`) and accept remote repositories via `setRemoteRepository(...)`. When adding sync behavior, update both cubit and write-queue wiring.
- Notifications: `NotificationService` is a singleton initialized from `SharedPreferences` — schedule and firing logic is centralized there.

**Developer workflows & commands (copy-pasteable):**

- Install deps & format:
  - `cd housekeepr; flutter pub get`
  - `dart format .` or `flutter format .`
- Static analysis and tests:
  - `cd housekeepr; flutter analyze`
  - Unit tests: `cd housekeepr; flutter test` (runs tests in `test/`)
  - Integration tests (Firestore emulator):
    - Preferred Windows helper: `.
housekeepr\\scripts\\run_emulator_and_tests.ps1 -TestPath 'test/integration'`
    - Or run emulator manually and set `FIRESTORE_EMULATOR_HOST=localhost:8080` before `flutter test`.
- Running app with local Firebase env:
  - `.
housekeepr\\scripts\\run-with-firebase.ps1` (sources `scripts/set-firebase-env.ps1` if `.env.local` exists)
- Cloud Functions deploy (from `housekeepr/functions/`):
  - `cd housekeepr/functions; npm install; firebase deploy --only functions` (use Firebase CLI authenticated account)

**Testing notes:**

- Tests depend on the Firestore emulator. Use `housekeepr/scripts/run_emulator_and_tests.ps1` to automatically run emulator and tests, or set `FIRESTORE_EMULATOR_HOST` / `FIREBASE_AUTH_EMULATOR_HOST` when running `flutter test`.
- Integration tests live under `test/integration` or `integration_test/` and use platform-aware Firebase options (see `firebase.json` and `lib/firebase_options.dart`).

**When editing code, follow these concrete rules:**

- Prefer small, focused changes that preserve existing public APIs for repositories/cubits unless a refactor is explicitly requested.
- When adding remote persistence, update the corresponding cubit wiring in `housekeepr/lib/main.dart` (`setRemoteRepository`, attach `WriteQueue`, and ensure `FirestoreSyncService` subscribers are started).
- Update `housekeepr/firebase.json` only if emulator settings or firebase project mappings change; tests and scripts read this file.

**CI / pre-commit hooks:**

- A pre-commit hook is provided at `housekeepr/scripts/pre-commit`. Install via `housekeepr/scripts/install-precommit-hook.ps1` on Windows.

**If unsure, inspect these examples first:**

- Remote write handling and failure snackbar wiring: `housekeepr/lib/main.dart` (search for `WriteQueue` and `attachFailureHandler`).
- Cloud function example and transaction patterns: `housekeepr/functions/index.js` (`joinHouseholdByInviteCode`).

If any of the above references are unclear or you want me to expand a specific section (e.g., repository APIs, test examples, or the write-queue implementation), tell me which file to inspect and I will update this guidance.
