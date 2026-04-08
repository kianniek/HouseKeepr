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
