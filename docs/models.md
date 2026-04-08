**Team Perspective**
- **Purpose:** Domain data types used across the app (tasks, shopping/grocery items, homes, completion history). They define persistent shapes, serialization, and small helpers used by repositories and cubits.

**Developer Perspective**
- **Language:** Dart
- **Location:** `lib/models/`

Function Catalog (Public types)
- **`CompletionRecord`**
  - Signature: `CompletionRecord({String? id, required String taskId, required String date, String? completedBy, DateTime? createdAt})`
  - Methods: `toMap()`, `fromMap(Map)`, `toJson()`, `fromJson(String)`.
  - Description: Represents a single completion entry for a task occurrence (date in YYYY-MM-DD).

- **`GroceryCategory`**
  - Signature: `enum GroceryCategory { ... }`
  - Helpers: `GroceryCategory.fromString(String?)` — parses stored names into enum value.
  - Description: Categorization for grocery items with display name and emoji metadata.

- **`GroceryItem`**
  - Signature: `GroceryItem({required id, required name, String? note, int quantity = 1, GroceryCategory category = other, bool checked = false, required DateTime createdAt, DateTime? checkedAt, int? serverVersion})`
  - Methods: `copyWith(...)`, `toMap()`, `fromMap(Map)`, `toJson()`, `fromJson(String)`.
  - Description: Rich grocery item used by the v2 shopping flow; contains category, timestamps, and sync metadata.

- **`ShoppingItem`**
  - Signature: `ShoppingItem({required id, required name, String? note, int quantity = 1, String? category, bool inCart = false, DateTime? lastSyncedAt, int? serverVersion})`
  - Methods: `copyWith(...)`, `toMap()`, `fromMap(Map)`, `toJson()`, `fromJson(String)`.
  - Description: Lightweight shopping list item used by legacy shopping flows; tolerant `fromMap` handles multiple remote types (Firestore Timestamp, string booleans, numeric strings).

- **`Home`**
  - Signature: `Home({required id, required name, required createdBy, List<String> members = const [], String? inviteCode, DateTime? createdAt})`
  - Methods: `copyWith(...)`, `toMap()`, `fromMap(Map)`, `toJson()`, `fromJson(String)`.
  - Description: Household/house entity containing member list and invite code.

- **`Task` and `SubTask`**
  - `SubTask`: constructor + `copyWith`, `toMap`, `fromMap`.
  - `Task`: large value object with many fields — `id`, `title`, `description`, `assignedToId/Name`, `subTasks`, `priority` (`TaskPriority` enum), `deadline`, `repeatRule`, `completedDates`, sync metadata (`SyncStatus`, `localVersion`, `serverVersion`, `isRetrying`), etc.
  - Methods: `copyWith(...)`, `toMap()`, `fromMap(Map)`, `toJson()`, `fromJson(String)`.
  - Description: Central model for chores and tasks; serialization is defensive (parses Firestore Timestamp, string forms, numeric strings).

Side Effects
- Models are pure data holders and serializers; no network or IO side effects. `fromMap` constructors are defensive and may parse/convert types.

Designer Perspective
- Models shape UI lists, sorting, and display fields. For example:
  - `Task` drives reminders, deadlines, assigned users and recurring occurrences.
  - `GroceryItem`/`ShoppingItem` drive shopping list UI states (checked/in-cart, quantity, category badges).

Visual Mapping
```mermaid
flowchart LR
  UI[UI Widgets]
  Cubits[Cubits]
  Repo[Repositories]
  Models[Models (Task, GroceryItem, ShoppingItem, Home, CompletionRecord)]

  UI -->|binds to| Cubits
  Cubits -->|use| Models
  Cubits -->|persist| Repo
  Repo -->|reads/writes| Models
```
