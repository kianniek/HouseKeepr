# HouseKeepr — Features Specification

This document expands the project's TODOs into a detailed feature specification for developers and contributors. Each feature includes: what it does, how it connects (APIs/storage), how it works (data flow & sync), how it is displayed to end users (screens/components), edge cases, acceptance criteria, implementation notes mapping to the codebase — and, importantly for this update, a very-detailed implementation checklist showing "Already implemented" vs "To implement" items.

## Table of contents

- Tasks & Chores
- SubTasks & Recurrence
- Shared Shopping List
- Family Calendar & Events
- Meal Planner & Recipes
- Authentication, Households & Profiles
- Sync, Offline Support & Conflict Resolution
- Notifications & Reminders
- Integrations (Google Home, Philips Hue, Spotify, etc.)
- Media, Storage & Attachments
- Search, Filters & Views
- Settings, Privacy & Data Export
- Deployment & Kiosk Mode (Raspberry Pi / Desktop)
- Testing, Emulators & Developer tooling

---

## 1. Tasks & Chores

What it does
- Core entity for task management: create, edit, assign, complete, archive tasks.
- Supports priorities, due dates, tags, points (gamification), and optional verification (photo).

How it connects
- Primary storage: local SharedPreferences-based repository for offline-first behavior.
- Remote sync: Firestore collections (e.g., `households/{houseId}/tasks`) used when user opts in to sync.
- Authentication: tasks are scoped to a Household document referenced by user profile.

How it works (data flow)
- Create/Edit: UI writes to local task repository immediately. Changes are queued in WriteQueue for remote sync.
- Sync worker: background sync service consumes the WriteQueue and applies batched writes to Firestore. On success, local document is marked synced with server version/timestamp.
- Real-time updates: when connected and authenticated, the app listens to Firestore document changes and merges updates into local store.

How it's displayed to the user
- Task List screen: grouped by due date or custom lists (Inbox, Today, Upcoming, Completed). Each list item shows title, due date, assignee avatar(s), priority chip, and completion checkbox.
- Task Details screen: full description, sub-tasks, attachments, comments (optional), recurrence info, points, history log.
- Widgets: small home screen and dashboard widgets showing top priorities or today's tasks.

Edge cases
- Duplicate tasks created offline then synced concurrently; need conflict resolution strategy (latest-wins or merge with user prompt).
- Deleted tasks locally that were updated remotely while offline.
- Large number of tasks (pagination & efficient queries).

Acceptance criteria
- Create/Edit/Complete flows work offline and sync when network returns.
- Tasks assigned to users show correct assignee metadata.
- UI displays sync status (pending, failed, synced) for task edits.

Implementation notes
- Local repo: `housekeepr/lib/repositories/` (Task repository files)
- UI: `housekeepr/lib/ui/tasks/` or `housekeepr/lib/pages/tasks_page.dart` (adjust to actual paths)
- Sync: `housekeepr/lib/services/sync_service.dart` and `write_queue.dart`.

### Implementation checklist — Tasks & Chores

- Already implemented (based on repo scan / inferred):
	- [x] Core Task model exists (e.g., `Task`) with fields for title, description, due date, priority, tags.
	- [x] Local persistence for tasks via SharedPreferences-based repository (local TaskRepository).
	- [x] `WriteQueue` and `HistoryRepository` present for queued remote operations and history tracking.
	- [x] App initializes Firebase (presence of `firebase_options.dart` and `Firebase.initializeApp()` in `lib/main.dart`).
	- [x] Basic Task create/edit/delete flows implemented in codebase (UI and model-level handlers present in `lib/`).

- To implement / verify (detailed):
	- [x] Add per-item sync status metadata and UI badges (pending / syncing / failed / synced). Files: UI task list row, Task model, sync service.
	- [x] Display assignee avatars reliably (resolve avatar URL or initials fallback). Files: user profile model and task list widgets.
	- [x] Add optimistic UI with rollback on failed sync (WriteQueue + UI handlers).
	- [x] Implement server version tracking for conflict resolution (store serverUpdateTimestamp on synced docs).
	- [x] Add pagination / lazy-loading for long task lists (infinite scroll + local query limits).
	- [x] Implement task archiving & bulk-delete flows with confirmations and undo.
	- [x] Add in-app audit/history view for each task showing changes (use HistoryRepository) and wire UI to `history_repository`.
	- [x] Add keyboard & accessibility support for task interactions (a11y labels, focus order).
	- [ ] Add unit tests for TaskRepository (local persistence) and widget tests for TaskList and TaskDetail pages.

---

## 2. SubTasks & Recurrence

What it does
- Sub-tasks allow breaking tasks into checkable steps.
- Recurrence engine enables repeating schedules (daily, weekly, complex rules like "every Tuesday & Thursday" or "first day of month").

How it connects
- Stored as part of Task model (array of SubTask objects) in local repository and mirrored to Firestore as nested collection or field.
- Recurrence rules stored as structured rule objects (e.g., RFC5545-like simplified representation).

How it works
- SubTask toggles update parent task progress percentage and optionally auto-complete parent when all sub-tasks done.
- Recurrence expansion happens on the device: a background job or on-demand generator calculates next instances (creates new Task instances or shows virtual occurrences).
- Avoid creating infinite instances—store parent recurrence rule and generate occurrences for a sliding window (e.g., next 3 months).

How it's displayed
- Task Details: inline checklist for subtasks with quick add.
- Recurring indicator/icon on task list and recurrence schedule editor in task details.
- Calendar integration shows generated occurrences as separate events/tasks.

Edge cases
- Changing recurrence rules after some occurrences were completed—decide whether to update future occurrences only.
- Timezone effects for due dates; store UTC + timezone offset when appropriate.

Acceptance criteria
- Subtasks persist across sync and update parent progress.
- Recurrences display correctly in list and calendar for a 3-month window.

Implementation notes
- Model: `Task.subTasks`, `RecurrenceRule` model in `housekeepr/lib/models/`.
- UI: task details recurrence editor and validation; calendar hooks to read occurrences.

### Implementation checklist — SubTasks & Recurrence

- Already implemented (based on repo scan / inferred):
	- [x] SubTask model represented inside Task (array field) and basic toggling supported in model.
	- [x] A recurrence field or structure exists in Task/Recurrence models (repo scan noted recurrence references).

- To implement / verify (detailed):
	- [ ] Create a robust RecurrenceRule model (RFC5545-inspired simplified) with: frequency (daily/weekly/monthly), interval, byDay, byMonthDay, until/occurrence count.
	- [ ] Implement an occurrence generator that expands recurrence rules to a sliding window (e.g., next 90 days) without creating infinite instances.
	- [ ] Implement UI editor for recurrence: presets (daily, weekly) and custom rule builder; include preview of next 5 occurrences.
	- [ ] SubTask inline add/edit UI in TaskDetail with drag-reorder and bulk-complete support.
	- [ ] Auto-complete parent task when all sub-tasks done (configurable behavior toggle).
	- [ ] Handle editing past occurrences (date-shift rules) and whether edits apply to single occurrence or series.
	- [ ] Add unit tests for recurrence expansion and edge cases (DST, timezone shifts).
	- [ ] Add integration tests ensuring recurrence instances appear correctly in calendar and task lists.

---

## 3. Shared Shopping List

What it does
- Collaborative shopping list shared across household members. Items can be marked "in cart", assigned quantity and notes.

How it connects
- Local cache + Firestore: `households/{houseId}/shopping_items` collection.
- Optional recipe integration to bulk-add ingredients.

How it works
- Items added locally appear instantly; state changes are queued and synced.
- Item toggles (in-cart, purchased) are lightweight sync operations to keep lists responsive.
- Optionally group items by store/category at display time.

How it's displayed
- Shopping List main screen with grouped sections (Produce, Dairy, Custom). Big tappable rows for quick toggle to "in cart" and swipe to remove or edit.
- Quick-add persistent input field and barcode/voice add overlay on mobile.

Edge cases
- Simultaneous edits (e.g., two users mark same item in-cart) — last-writer wins is acceptable for simple toggles; consider operational transforms for multi-field merges.

Acceptance criteria
- Real-time quick-sync for small updates; consistent final state.
- Grouping and quick-add features work offline and online.

Implementation notes
- UI: `housekeepr/lib/ui/shopping/`.
- Repos: `ShoppingItemRepository` local + Firestore counterparts.

### Implementation checklist — Shared Shopping List

- Already implemented (based on repo scan / inferred):
	- [x] ShoppingItem model and a local repository (SharedPreferences-based) exist.
	- [x] Core UI for shopping list present (quick-add, list view) inferred from `lib/` structure and tests.

- To implement / verify (detailed):
	- [ ] Ensure per-item real-time sync handlers (listen for remote updates and merge into local repo).
	- [ ] Implement grouping by category/store in UI with drag-and-drop re-ordering within groups.
	- [ ] Add barcode scanning integration for quick-add (mobile only) and voice-to-text input.
	- [ ] Implement quantity editing with unit normalization (e.g., "1 lb" vs "16 oz" conversion helper optional).
	- [ ] Add conflict handling for simultaneous toggles (last-writer-wins acceptable, but track lastChangedBy and lastChangedAt).
	- [ ] Add tests for ShoppingItemRepository sync behavior and widget tests for list interactions.
	- [ ] Add recipe ingredient import flow that parses a recipe's ingredient lines into ShoppingItem candidates.

---

## 4. Family Calendar & Events

What it does
- Shared calendar view for household events with color-coding per member, event types and optional travel-time alerts.

How it connects
- Two-way sync with external calendars (Google Calendar, optional). Internally uses Firestore `events` collection.
- Local caching for offline view.

How it works
- Events stored with metadata: owner, attendees, location, reminders, recurrence.
- Two-way sync with Google via OAuth: events created in-app can be pushed to Google Calendar if the user granted access.
- Calendar view queries local store and optionally remote for up-to-date info.

How it's displayed
- Weekly and monthly grid views. Day view with agenda list.
- Color chips for users and icons for event type. Tap an event to see details and options (edit, directions, add to personal calendar).

Edge cases
- Conflicting updates between local and external calendars (map external events to a separate source field and merge carefully).
- Timezone conversions for event times.

Acceptance criteria
- Calendar display accurate for user's timezone.
- Basic Google Calendar push/pull works when configured.

Implementation notes
- UI: calendar widgets and event editor; integration points in `services/calendar_service.dart`.

### Implementation checklist — Family Calendar & Events

- Already implemented (based on repo scan / inferred):
	- [x] Event model placeholder and calendar UI building blocks likely present (project contains calendar-related references in docs).

- To implement / verify (detailed):
	- [ ] Implement local EventRepository with caching and Firestore sync (`households/{houseId}/events`).
	- [ ] Calendar grid UI (month/week/day) with performant rendering and virtualization for many events.
	- [ ] Color-coding per member and event-type icons in UI.
	- [ ] Event editor with location, attendees, reminders, recurrence (reuse recurrence engine from tasks).
	- [ ] Google Calendar two-way sync: OAuth flow, push local events, pull remote events with mapping to internal event IDs and source metadata.
	- [ ] Implement travel-time alert integration (hook into Maps API or let users set buffer times).
	- [ ] Tests: unit tests for event merging behavior and widget tests for calendar interaction.

---

## 5. Meal Planner & Recipes

What it does
- Plan weekly meals, store recipe entries, scale ingredients, and add recipe ingredients to the shopping list.

How it connects
- Recipes stored locally and optionally in Firestore for shared households.
- Optional 3rd-party recipe APIs for import (Spoonacular or similar) requiring API keys.

How it works
- Weekly planner allows drag-and-drop of recipes into day/meal slots.
- When adding a recipe to a shopping list, ingredients are parsed and transformed into ShoppingItem entries.

How it's displayed
- Meal Planner: visual weekly grid, recipe cards with preview image and tags.
- Recipe detail: ingredients list, steps, servings control, nutrition info (if available).

Edge cases
- Ingredient parsing inconsistencies from external sources.
- Conflicting edits on shared recipes—treat recipes like content with simple last-writer wins or use owner-based edits.

Acceptance criteria
- Drag-and-drop meal planning updates persistent planner state.
- Add-to-shopping function creates appropriate items.

Implementation notes
- UI: `lib/ui/meal_planner/` and `lib/models/recipe.dart`.

### Implementation checklist — Meal Planner & Recipes

- Already implemented (based on repo scan / inferred):
	- [x] Recipe model placeholder and some UI scaffolding likely exists.

- To implement / verify (detailed):
	- [ ] Implement RecipeRepository local + optional Firestore sync and image attachments.
	- [ ] Meal planner weekly grid UI with drag-and-drop recipe placement and per-slot serving size.
	- [ ] Ingredient scaling and automatic conversion when changing servings.
	- [ ] Add-to-shopping feature: map recipe ingredients to normalized ShoppingItem entries (dedupe by normalized name).
	- [ ] Import from third-party APIs (Spoonacular): add API client and importer with mapping heuristics and rate-limit handling.
	- [ ] Add recipe editor with rich text or structured steps and image upload.
	- [ ] Tests covering scaling logic, import heuristics, and planner persistence.

---

## 6. Authentication, Households & Profiles

What it does
- User accounts (Firebase Auth) and Household concept allowing multiple users to share data.

How it connects
- Firebase Authentication for user identity (Email/Password, Google Sign-In).
- Firestore Household documents with membership lists and role (owner/admin/member).

How it works
- On sign up, create a personal household by default or invite users to an existing household via email invite codes.
- User identity maps to user profile documents containing display name, avatar URL, and preferences.

How it's displayed
- Auth gate screen for login/signup. Household switcher (if user in multiple households) in settings or app header.
- Profile editor screen.

Edge cases
- Invite acceptance flow when user signs up later.
- Removing members must consider ownership transfer.

Acceptance criteria
- Sign-up/login works with Firebase Auth and household membership resolves correctly.

Implementation notes
- Files: `housekeepr/lib/auth/`, `houseKeepr/lib/models/user_profile.dart`, `houseKeepr/lib/repositories/household_repository.dart`.

### Implementation checklist — Authentication, Households & Profiles

- Already implemented (based on repo scan / inferred):
	- [x] Firebase initialization and `firebase_options.dart` present.
	- [x] Firebase Auth usage likely present (`auth_gate.dart` in `lib/` suggests auth gating).

- To implement / verify (detailed):
	- [ ] Implement robust HouseholdRepository and member roles (owner/admin/member), with Firestore documents `households/{houseId}`.
	- [ ] Invite flow: generate invite codes/links, accept link flow, and email-send handling.
	- [ ] Profile editor: display name, avatar upload, preferences and notification channels.
	- [ ] Household switcher UI for users in multiple households.
	- [ ] Secure access rules in Firestore (rules to ensure only household members can access household data).
	- [ ] Tests: unit tests for invite flow and household membership management.

---

## 7. Sync, Offline Support & Conflict Resolution

What it does
- Provide robust offline UX with eventual consistency and clear conflict handling.

How it connects
- Local store (SharedPreferences + local models) + Firestore remote store.
- WriteQueue persists pending operations across restarts.

How it works
- Local-first writes, queue to be applied remotely.
- Background sync worker with retry/backoff and error reporting.
- Conflict resolution policy documented: timestamps + user precedence; provide UI prompt when automatic merge might cause data loss.

How it's displayed
- Visible sync indicator in app header or settings with per-item status where helpful.
- Conflict prompt modal that shows both versions and allows choose/merge.

Edge cases
- Network flaps, repeated failures causing queue buildup.
- Cross-device fast edits producing complex merge scenarios.

Acceptance criteria
- Writes are persisted offline and applied when network available.
- Conflicts surfaced to user when automatic merge is unsafe.

Implementation notes
- Files: `write_queue.dart`, `sync_service.dart`, `repositories/*`.

### Implementation checklist — Sync, Offline & Conflict Resolution

- Already implemented (based on repo scan / inferred):
	- [x] Local-first approach and a `WriteQueue` for queued remote operations.
	- [x] Some sync wiring and a `sync_service` are present.

- To implement / verify (detailed):
	- [ ] Make WriteQueue durable across app restarts: persisted queue state with backoff and exponential retry strategies.
	- [ ] Implement per-object conflict metadata (lastModifiedAt, lastModifiedBy, localVersion, serverVersion) to aid merges.
	- [ ] Automatic merge heuristics for non-overlapping fields; UI conflict resolution modal for overlapping edits.
	- [ ] Add metrics and logging for queue backlog size and sync failures (for debugging and telemetry).
	- [ ] Add unit/integration tests simulating network flaps and concurrent edits.

---

## 8. Notifications & Reminders

What it does
- Local and remote push notifications for task due reminders, upcoming events, and assigned tasks.

How it connects
- Local scheduling (platform notification APIs) for reminders.
- Firebase Cloud Messaging (FCM) for remote push notifications.

How it works
- Reminder metadata on tasks/events triggers local schedule. If remote, send a message via FCM to household members.
- Reminder preferences: quiet hours, Do Not Disturb, and per-user channels.

How it's displayed
- System notification center entries with deeplinks into specific task or event in the app.
- In-app notifications center showing recent notifications and actions.

Edge cases
- Handling notification permissions denied; local fallback.
- Duplicate notifications when both local and remote triggers fire.

Acceptance criteria
- Reminders fire reliably on device and deep-link to the correct in-app screen.

Implementation notes
- Files: `notification_service.dart`, `firebase_messaging` integration.

### Implementation checklist — Notifications & Reminders

- Already implemented (based on repo scan / inferred):
	- [x] Notification scaffolding references and FCM usage referenced in docs.

- To implement / verify (detailed):
	- [ ] Platform-specific local notification scheduling for iOS/Android/desktop (use flutter_local_notifications or equivalent).
	- [ ] Integrate with FCM for remote push and map FCM messages into in-app notification center.
	- [ ] Add user preferences: quiet hours, per-channel notification toggles, snooze options.
	- [ ] Prevent duplicate notifications when both local and remote triggers occur (de-duplication keys).
	- [ ] Tests: verify deeplink behavior from notification to task/event screen across platforms.

---

## 9. Integrations (Google Home, Philips Hue, Spotify, etc.)

What it does
- Optional integrations to extend the dashboard: show device status, control lights, and play music.

How it connects
- Each integration uses its specific API and OAuth flow (e.g., Google SDM API, Philips Hue API, Spotify Web API).
- Tokens and secrets stored securely using platform mechanisms or app settings (encrypted storage recommended).

How it works
- Integrations are opt-in per household. A background service polls or subscribes to webhooks where available.
- Actions from the app (e.g., "Set Movie Night lighting") call integration endpoints to effect changes.

How it's displayed
- Integrations panel in settings; small control widgets on dashboard (e.g., currently playing track, light group controls).

Edge cases
- Token refresh and broken integration flows.
- Rate limits and transient API failures.

Acceptance criteria
- Basic connection/detection flows work and UI shows integration status. Controls perform the expected action.

Implementation notes
- Add `services/integrations/*` to manage API clients and tokens.

### Implementation checklist — Integrations

- Already implemented (based on repo scan / inferred):
	- [ ] No third-party integrations are currently implemented (assume none; they are optional and should be gated behind opt-in flows).

- To implement / verify (detailed):
	- [ ] OAuth flow and token storage for each integration (Google SDM, Philips Hue Bridges, Spotify OAuth). Secure token storage per platform.
	- [ ] Integration UI to connect/disconnect third-party services and show status.
	- [ ] Build service clients with robust retry and rate-limit handling.
	- [ ] Add action-to-integration mappings (e.g., "Movie Night" -> set light scene via Hue, start playlist via Spotify).
	- [ ] Tests / sandbox mode to simulate integration endpoints without hitting production APIs.

---

## 10. Media, Storage & Attachments

What it does
- Allow uploading and attaching photos (task verification, recipe images) to cloud storage.

How it connects
- Firebase Storage or other cloud storage provider; store metadata references in Firestore.

How it works
- Uploads happen after initial local save; attachments are referenced with storage URLs; local caching for preview.

How it's displayed
- Attachment gallery in task details and recipe pages; placeholder while uploading with progress indicator.

Edge cases
- Large files and network interruptions; retry and resume logic recommended.

Acceptance criteria
- Uploads complete successfully and attachments load in-app with caching.

Implementation notes
- Files: `storage_service.dart`, attachment handling in models and UIs.

### Implementation checklist — Media, Storage & Attachments

- Already implemented (based on repo scan / inferred):
	- [x] App references storage usage in docs and has Firebase configured; some upload scaffolding likely present.

- To implement / verify (detailed):
	- [ ] Implement `StorageService` with resumable uploads and progress feedback (Firebase Storage or equivalent).
	- [ ] Attachment model storing storage path, thumbnail URLs, mime-type and size.
	- [ ] Local caching (disk cache) of thumbnails and images for fast display.
	- [ ] Limit enforcement (max file size) and image compression before upload.
	- [ ] Tests for interrupted upload resume and failed upload cleanup.

---

## 11. Search, Filters & Views

What it does
- Global search across tasks, shopping items, and recipes with filtering (assignee, tags, date range).

How it connects
- Local indices for quick search; remote queries for larger datasets.

How it works
- Use simple in-memory search for local items; optionally use Firestore indexes for advanced server-side queries.

How it's displayed
- Search bar in the app header, filter chips, and sorting controls.

Edge cases
- Large datasets and pagination; unclear query semantics across sources.

Acceptance criteria
- Search returns relevant results and filters refine results predictably.

Implementation notes
- Add `search_service.dart` to encapsulate search logic.

### Implementation checklist — Search, Filters & Views

- Already implemented (based on repo scan / inferred):
	- [ ] Basic filtering and lists exist in UI; global search likely not implemented yet.

- To implement / verify (detailed):
	- [ ] Implement `SearchService` that indexes local items (in-memory or small on-disk index) for tasks, shopping items, and recipes.
	- [ ] Add advanced filter options (assignee, date range, tags) and saveable views.
	- [ ] Add server-side search mapping using Firestore queries where appropriate (with index definitions added to `firestore.indexes.json` if needed).
	- [ ] Add UI for query suggestions and fuzzy matching for misspellings.
	- [ ] Tests for search relevance and filter combinations.

---

## 12. Settings, Privacy & Data Export

What it does
- Central settings for account, notifications, household management, privacy choices, and export data.

How it connects
- Local preferences stored in SharedPreferences; user-visible changes reflected in cloud settings when applicable.

How it works
- Export: generate JSON or CSV of household data that can be downloaded or shared.
- Privacy: allow removal of account and household data with a clear flow.

How it's displayed
- Settings screen with grouped sections and inline help text for sensitive actions.

Edge cases
- Deleting household should cascade or reassign resources properly.

Acceptance criteria
- Settings persist and exports produce a complete snapshot of household data.

Implementation notes
- UI: `lib/ui/settings/` and export helper utilities in `lib/services/export_service.dart`.

### Implementation checklist — Settings, Privacy & Data Export

- Already implemented (based on repo scan / inferred):
	- [ ] Basic settings UI scaffold may exist (not guaranteed). Export flow not implemented.

- To implement / verify (detailed):
	- [ ] Implement settings pages for account, notifications, household management, and integrations.
	- [ ] Implement data export (JSON/CSV) that composes household data (tasks, shopping items, recipes, events) with proper sanitization.
	- [ ] Implement account deletion and household deletion flows with safe confirmation and cascade rules.
	- [ ] Tests for export correctness and data deletion safety (dry-run mode recommended).

---

## 13. Deployment & Kiosk Mode (Raspberry Pi / Desktop)

What it does
- Provide instructions and scripts to run the app in kiosk mode for Raspberry Pi and desktop deployments.

How it connects
- App uses the same codebase, but build flags may alter behavior (e.g., fullscreen, auto-login, local-only mode).

How it works
- Kiosk mode runs with a configured household and optional auto-login token, hides system chrome, and starts in full-screen dashboard.

How it's displayed
- Launches directly into dashboard UI optimized for touch or large displays.

Edge cases
- Networkless mode for kiosk devices; local-only behavior and limited interactivity if not connected.

Acceptance criteria
- Documented steps to build for Linux and run kiosk as a systemd service; optional sample service file included.

Implementation notes
- Docs: `docs/` and scripts in `scripts/` (e.g., systemd unit examples).

### Implementation checklist — Deployment & Kiosk Mode

- Already implemented (based on repo scan / inferred):
	- [x] `scripts/` contains Windows PowerShell scripts and other helpers (e.g., `run_emulator_and_tests.ps1`).
	- [ ] Kiosk-specific systemd unit and fully documented steps may not yet be present.

- To implement / verify (detailed):
	- [ ] Provide a sample systemd service file and install instructions for Raspberry Pi (headless kiosk mode with autologin and X/Wayland setup).
	- [ ] Add a kiosk-mode app flag (`--kiosk`) or build flavor that auto-logs a household and restricts navigation.
	- [ ] Add auto-update instructions (e.g., deployment script or instructions using `apt`/snap or manual pulls).
	- [ ] Test on Pi hardware or QEMU-based CI run to validate kiosk startup.

---

## 14. Testing, Emulators & Developer Tooling

What it does
- Provide unit, widget, and integration tests including support for Firestore emulator.

How it connects
- Tests use Firestore emulator when FIRESTORE_EMULATOR_HOST is set; otherwise, they run with mocked repositories.

How it works
- Integration tests that touch Firestore will skip if emulator not configured. Developer docs show how to run emulator locally.

How it's displayed
- N/A (developer-focused). Include CI workflows to run tests and `flutter analyze`.

Edge cases
- Flaky tests; maintain stable test harness and avoid network-dependent tests unless emulator is present.

Acceptance criteria
- Tests run locally with `flutter test`; integration tests run against emulator when configured.

Implementation notes
- Test files in `housekeepr/test/` already present. Add CI workflow file in `.github/workflows/` to run tests and analyze.

### Implementation checklist — Testing, Emulators & Developer Tooling

- Already implemented (based on repo scan / inferred):
	- [x] Unit and widget test files exist under `housekeepr/test/` (a variety of tests in the repository).
	- [x] Integration tests exist and some check for emulator env vars (per `todo.readme.md`).

- To implement / verify (detailed):
	- [ ] Add a reproducible local dev guide section documenting how to run the Firestore emulator and run integration tests against it (PowerShell and bash snippets).
	- [ ] Add GitHub Actions CI workflow to run `flutter test --reporter expanded` and `flutter analyze` on PRs with a matrix for stable Flutter versions.
	- [ ] Add test harness utilities to reliably mock time, network failures, and FCM messages for deterministic tests.
	- [ ] Add flake-detection rules and retry strategies for flaky integration tests.

---