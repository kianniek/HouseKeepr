**Why / Purpose**
- **Summary:** Centralize the household experience to make it easier for household members to coordinate tasks, shopping, and schedules across devices.
- **Motivation:** This app was created to simplify household collaboration — so families, roommates, and shared households can organize chores, shopping, and daily responsibilities in one place.

**Team Perspective**
- **Purpose:** High-level architecture diagram showing how UI, state (cubits), local persistence, write-queue, and Firestore interact to provide a resilient, multi-device syncing experience.

**Developer Perspective**
- **Components:**
  - UI: `AuthGate`, `HomeScreen`, pages and widgets that bind to cubits.
  - Cubits: local state + orchestration (tasks, shopping, auth, user).
  - Local Repositories: Hive and SharedPreferences adapters for fast local reads/writes.
  - Write Queue: durable local queue that serializes remote write operations and supports retries/failure handling.
  - Firestore Sync Service: subscribes to remote snapshots and applies merges into local state.
  - Remote Repositories: Firestore adapters for user and household collections.
  - Services: notifications, widget bridge, migration utilities, product suggestion engine.

Visual Architecture
```mermaid
flowchart TB
  subgraph UI
    AG[AuthGate]
    HS[HomeScreen]
    Pages[Dashboard / Tasks / Shopping]
  end

  subgraph State
    Cubits[Cubits (Task/Shopping/Auth/...)]
  end

  subgraph Local
    Hive[Hive Boxes]
    Prefs[SharedPreferences]
    LocalRepos[Local Repositories]
    WQ[WriteQueue]
  end

  subgraph Remote
    Sync[FirestoreSyncService]
    Firestore[Cloud Firestore]
    RemoteRepos[Firestore Repositories]
  end

  subgraph Services
    Notif[NotificationService]
    WidgetSvc[WidgetService]
    ProdSvc[ShoppingProductsService]
    Migration[MigrationService]
  end

  AG --> HS
  HS --> Pages
  Pages --> Cubits
  Cubits --> LocalRepos
  LocalRepos --> Hive
  LocalRepos --> Prefs
  Cubits --> WQ
  WQ --> RemoteRepos
  RemoteRepos --> Firestore
  Sync --> Cubits
  Sync --> RemoteRepos
  Cubits --> Notif
  Cubits --> WidgetSvc
  ProdSvc --> Cubits
  Migration --> RemoteRepos
```

Notes
- The system favors optimistic local updates (cubits emit before remote persistence) and relies on `WriteQueue` + `FirestoreSyncService` to eventually reconcile with server state. Services are designed to degrade gracefully in web/tests where platform plugins aren't available. Firebase Auth and Storage are used in the auth/profile flows, while Firestore is accessed through the repository and sync layers.

**Features**
- Task management: create, assign, reorder, and complete household tasks.
- Shared shopping lists: collaborative lists with product suggestions and quantities.
- Household membership: invite/join households, roles, and per-household data scopes.
- Offline-first sync: local repositories + `WriteQueue` for durable, optimistic updates.
- Notifications & reminders: scheduled local notifications for tasks and shopping.
- Home screen widgets: platform widgets for quick access and glanceable info.
- User auth & profiles: Firebase Auth with profile storage and avatars.
- Migration & compatibility: migration utilities for schema changes and upgrades.

**Potential Future Features**
- Shared payments calculator: tool to compute how much each household member should contribute to a shared bank account (splits, per-person shares, adjustable weights).
- Calendar sync: sync tasks and shopping events with external calendars.
- Advanced analytics: household spending and task completion summaries.
- Meal planning: shared meal plans with recipe suggestions and ingredient lists.
- Recurring tasks & shopping: support for recurring chores and shopping items with flexible schedules.
- Localization & accessibility improvements.
