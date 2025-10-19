# Firestore schema: Homes & invite flow

This document describes the recommended Firestore schema for the `homes` collection used by HouseKeepr and provides a suggested (starter) security rules snippet and guidance for implementing invite-based joins.

## Top-level collections

- `homes` (collection)
  - document id: `homeId` (string)
  - fields:
    - `name` (string) — human-readable household name
    - `createdBy` (string) — UID of the user who created the home
    - `members` (array<string>) — list of UIDs who are members of the Home
    - `inviteCode` (string, optional) — short code used to invite new members
    - `inviteExpiresAt` (timestamp, optional) — when the invite expires
    - `createdAt` (timestamp) — creation time
  - example document:

```json
{
  "name": "The Smiths",
  "createdBy": "uid-alice",
  "members": ["uid-alice", "uid-bob"],
  "inviteCode": "ABC123",
  "inviteExpiresAt": "2025-10-31T00:00:00Z",
  "createdAt": "2025-10-01T12:00:00Z"
}
```

## Per-home subcollections (recommended)

- `homes/{homeId}/tasks` — household tasks (documents modeled by your `Task` type)
- `homes/{homeId}/shopping` — shared shopping list items
- `homes/{homeId}/rewards` — reward cards and metadata

Keeping tasks/shopping/etc. under the `homes/{homeId}` document simplifies security rules and makes it easier to scope reads to a single Home.

## Invite flow options

There are two common approaches for implementing invite/code joins:

1. Client-side join (not recommended for production):
   - The client reads `homes/{homeId}` by lookup of `inviteCode` and attempts to update the document's `members` array to include the authenticated user.
   - This approach is simple but hard to secure: you'd need rules that allow non-members to add themselves safely while preventing tampering, which is error-prone.

2. Server-side join (recommended):
   - Implement a Cloud Function (or HTTPS endpoint) that accepts the invite code and the caller's auth token.
   - The function verifies the invite (code exists and not expired) and atomically adds the caller UID to the `members` array using an admin SDK (server-side) update/transaction.
   - The client then reads the updated home document. This pattern keeps the security rules simple and strong because only the server (trusted) code can modify membership.

## Suggested Firestore security rules (starter)

Below is a concise, opinionated starter ruleset for the `homes` collection. It intentionally keeps membership mutation restricted to existing members — this means server-side (Cloud Function) logic is recommended for invite acceptance.

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() {
      return request.auth != null;
    }

    // A user is considered a member if their UID is present in the members array
    function isHomeMember(homeDoc) {
      return isSignedIn() && (request.auth.uid in homeDoc.data.members);
    }

    match /homes/{homeId} {
      // Create a home: only signed-in users and createdBy must match the caller
      allow create: if isSignedIn()
                     && request.resource.data.createdBy == request.auth.uid
                     && request.resource.data.name is string;

      // Read: only members may read the home doc
      allow get, list: if isSignedIn() && (request.auth.uid in resource.data.members);

      // Update: allow existing members to update the home (rename, invite rotate, etc.)
      // Do NOT allow arbitrary non-members to append themselves to members.
      allow update: if isSignedIn() && (request.auth.uid in resource.data.members);

      // Delete: only the creator can delete a home
      allow delete: if isSignedIn() && request.auth.uid == resource.data.createdBy;

      // Subcollection rules should live here for tasks/shopping/rewards
      match /{subCollection=**} {
        // Example: members may read/write subcollections; more granular rules are recommended.
        allow read, write: if isSignedIn() && (request.auth.uid in resource.data.members);
      }
    }
  }
}
```

Notes:
- The rule above purposefully prevents a non-member from directly updating the `members` array to add themselves. This is safer and forces a server-side join flow.
- If you absolutely must support client-side joining, the rule must carefully verify that the only change is adding the caller's UID and that no other fields were changed. Implementing that correctly is tricky and error-prone; server-side join is recommended.

## Indexes and performance

- A single-field query on `inviteCode` (e.g. `where('inviteCode', '==', code).limit(1)`) typically does not require a custom index. Multi-field queries will.
- Consider storing a normalized `homeId` or `lookup` collection if inviteCode lookups become a hotspot.

## Example join sequence (recommended)

1. Client opens invite link: `https://app/join?code=ABC123`
2. Client calls an HTTPS Cloud Function endpoint `POST /join` with JSON `{ code: 'ABC123' }` and includes auth bearer token.
3. Cloud Function (using admin SDK) finds the home by inviteCode, validates expiry, and updates `homes/{homeId}` with a transaction to append the caller UID to `members`.
4. Client listens to `homes/{homeId}` and will receive the updated member list and proceed into the Home context.

## Final notes

This doc is a starting point. Before shipping, review rules with your security requirements and test join flows thoroughly (including concurrent join attempts). Consider rate-limiting invites and rotating invite codes to reduce abuse.
