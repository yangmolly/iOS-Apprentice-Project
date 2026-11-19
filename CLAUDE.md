# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

StudySpot is a SwiftUI iOS app for UNC students to find study spots, rate them Beli-style, save them, and RSVP to study events. The backend is Supabase (Postgres, Auth, Row Level Security and Realtime), accessed through the `supabase-swift` SPM package (2.x).

## Build & test

- Project: `StudySpot.xcodeproj`. The app target and the shared scheme are both named `iOSApprenticeProject`, not StudySpot. Unit tests are in the `StudySpotTests` target and use Swift Testing.
- Deployment target is iOS 26.2, Swift 5 language mode, Approachable Concurrency, and **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`**. Types are main-actor-isolated by default, and the test target uses the same setting.
- A fresh clone needs `Services/Secrets.swift`, which is gitignored. Copy `Secrets.swift.example` from the repo root to that path and fill it in.
  ```sh
  xcodebuild -project StudySpot.xcodeproj -scheme iOSApprenticeProject \
    -destination 'platform=iOS Simulator,name=iPhone 17' build test
  # a single suite or test:
  #   -only-testing:StudySpotTests/SyncQueueTests
  #   -only-testing:StudySpotTests/SyncQueueTests/queuesWhenOfflineAndFlushesInOrder
  ```
- No linter is configured.

## Project layout quirk

The top-level folders `iOSApprenticeProject/`, `Features/`, `Models/`, `Services/` and `Components/` are Xcode **file-system synchronized groups** in the app target. `StudySpotTests/` is one in the test target. Any `.swift` file under them, subfolders included, is compiled automatically, so you don't need to edit `project.pbxproj`. Adding a *new top-level* folder does need a `project.pbxproj` edit. Non-Swift files inside these folders get copied into the app bundle, which is why `Secrets.swift.example` sits at the repo root. `supabase/` is not part of any target. With member import visibility enabled, each file must import every module it uses, such as `SwiftData` for `.modelContainer`.

## Architecture

MVVM on top of a repository layer, network-first with a SwiftData cache and an offline write queue.

- **Composition:** `iOSApprenticeProjectApp` builds `AppEnvironment.live()` and an `AuthViewModel`, and injects both with `.environment(...)`. Views read them with `@Environment(AppEnvironment.self)` and `@Environment(AuthViewModel.self)`. These are `@Observable` classes, not `ObservableObject`.
- **Auth gate:** `ContentView` switches on `auth.phase` (`launching`, then `signedOut` showing `AuthFlowView`, or `signedIn` showing `MainTabView`). `AuthViewModel` follows `AuthRepository.authStateChanges()`. On sign-in it sets `env.session.userId`, loads the cache, then calls `refreshAll()`. On sign-out it calls `env.reset()`, which clears the cache and the queue.
- **Data flow** (`Services/`):
  - `Remote/SupabaseRemote` is the only code that calls PostgREST, behind the `RemoteDataSource` protocol. `Repositories/AuthRepository` wraps `supabase.auth`.
  - `Repositories/*Repository` are `@Observable` classes that own the state views render (`spots.spots`, `events.myRSVPs`, …).
  - **Reads:** `loadCached()` runs first, then `refresh()` replaces the cache with server data. A refresh keeps any entries that have pending writes (`sync.pendingIds(for:)`) so optimistic changes don't flicker away.
  - **Writes:** the repository applies the change to the cache, then calls `sync.submit(op)`. That either sends the write or queues it. If the server permanently rejects it, `submit` throws `SyncError` and the repository rolls the change back.
  - `Sync/SyncQueue` persists `WriteOperation`s as `PendingWrite` SwiftData models and replays them in order. `SyncFailure.classify` maps errors to transient (keep queued), permanent (drop and report) or alreadyApplied (a unique violation on a primary key). `AppEnvironment.refreshAll()` flushes the queue before refreshing, and it runs on reconnect through `NetworkMonitor`.
  - `Cache/CacheStore` stores every record as JSON in a single generic `CachedRecord` model keyed by (kind, id). Domain model changes need no SwiftData migration.
  - Rows the app creates (spots, events, reviews) get their UUIDs on the device, so a spot created offline can be rated or saved before it syncs.
- **Supabase client** (`SupabaseManager.swift`): the session is stored in the Keychain, and `emitLocalSessionAsInitialSession` is on, so a returning user stays signed in offline. Sign-out uses `.local` scope.
- **Models** (`Models/`) mirror database rows using explicit snake_case `CodingKeys`. Inserts use separate `New*` and `ReviewUpsert` types. `Event` decodes the RSVP count from the embedded `event_rsvps(count)` select. Swift enums (`EventCategory`, `NoiseLevel`, `Seating`, `RatingBucket`, `SavedList`) must match the Postgres enums.
- **Tests** (`StudySpotTests/TestSupport.swift`): `TestEnv` builds a real `AppEnvironment` with an in-memory SwiftData container, a `MockRemote` and a switch for connectivity. Prefer testing real repositories and view models this way over adding repository protocols.

## Database (`supabase/migrations/`)

- Never run SQL against the Supabase project. Write a new timestamped migration and the user applies it. Don't edit migrations that have already been applied. Destructive cleanup goes in `supabase/cleanup/`, which is never auto-applied.
- To test a migration locally, PostgreSQL 18 is installed at `/Library/PostgreSQL/18/bin`. Run `initdb` in a scratch directory, connect over TCP on 127.0.0.1 (the scratch path is too long for a Unix socket), stub the `auth` schema (`auth.users`, `auth.uid()`), the `authenticated` role and the `supabase_realtime` publication, then apply all migrations in order.
- Tables in use: `profiles`, `study_spots`, `reviews` (one per user per spot), `events`, `event_rsvps` and `saved_spots`. `favorites`, `event_members` and the views `spot_ratings` and `event_member_counts` are legacy and the app doesn't use them.
- Triggers:
  - `handle_new_user` creates a profile from signup metadata `name`.
  - `enforce_unc_email` rejects non-`@unc.edu` emails.
  - `reviews_refresh_spot_stats` keeps `study_spots.avg_rating`, `review_count` and the consensus attributes current.
  - `study_spots_prevent_duplicate` raises `duplicate_spot:` when a spot within 75 m has a name with trigram similarity ≥ 0.7 and the same digits. The RPC `find_similar_spots` returns softer matches for "Did you mean…?".
- RLS: any `authenticated` user can read. Writes require `auth.uid()` to match the row's `user_id` or `created_by`, so new write paths must send the current user's id. `study_spots` has no delete policy, so spots are permanent.
