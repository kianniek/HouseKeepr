# HouseKeepr Engineering Guardrails

## Batch Firestore Mutations
- Never dispatch N individual `saveTask` / `saveItem` operations through `WriteQueue` for multi-item actions (e.g., `batchRescheduleTasks`, `restoreTasks`, `completeAllTasks`).
- Use a Firestore `WriteBatch` (chunked at 500 ops max) or a dedicated batch queue operation so Firestore emits a single snapshot instead of N consecutive snapshots.

## Notification Sync Throttling
- `NotificationService.syncTaskNotifications` must be debounced/coalesced when called from stream-driven state updates (`TaskCubit.replaceAll`, `subscribeToTasksStream`).
- One-time legacy notification cleanup (such as cancelling legacy ID `1000`) must be gated by a persisted `SharedPreferences` flag rather than called on every `syncTaskNotifications` invocation, to avoid Android `NotificationManager` rate-limit shedding (`Shedding cancel (dupe)`).
