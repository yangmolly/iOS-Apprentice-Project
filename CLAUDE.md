# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

StudySpot is a SwiftUI iOS app for UNC students to find study spots, review them, favorite them, and join events and study groups. The backend is Supabase (Postgres, Auth and Row Level Security), accessed through the `supabase-swift` SPM package (2.x).

## Build & run

- Project: `StudySpot.xcodeproj`. Its single target and scheme are both named `iOSApprenticeProject`; the target is not called StudySpot.
- Deployment target is iOS 26.2, Swift 5 language mode, with Approachable Concurrency enabled.
- Build from the CLI:
  ```sh
  xcodebuild -project StudySpot.xcodeproj -scheme iOSApprenticeProject \
    -destination 'generic/platform=iOS Simulator' build
  ```
- There is no test target and no linter configured.

## Project layout quirk

The top-level folders `iOSApprenticeProject/`, `Features/`, `Models/`, `Services/`, `Components/` and `supabase/` are Xcode **file-system synchronized groups**. Any `.swift` file you add under them is compiled automatically, so you don't need to edit `project.pbxproj`. Everything shares one module, so there are no imports between folders.

## Architecture

- **Entry point and auth gate:** `iOSApprenticeProject/iOSApprenticeProjectApp.swift` creates a single `AuthViewModel`, which is `@MainActor` and an `ObservableObject`, and injects it with `.environmentObject`. `ContentView` calls `auth.restoreSession()` on launch and switches between `SignInView`, wrapped in a `NavigationStack`, and `ExploreView` based on `auth.isSignedIn`. Views reach the signed-in user through `@EnvironmentObject AuthViewModel` and its `currentUserId`.
- **Features:** each feature under `Features/<Name>/` pairs a view with a view model. Only `AuthViewModel` currently talks to Supabase. The other view models (Explore, Favorites, Groups, Profile) are mostly UI-state stubs that still need to be wired to the backend.
- **Data access:**
  - `Services/SupabaseManager.swift` defines one global `supabase` client.
  - `Services/SupabaseConfig.swift` holds the project URL and the publishable/anon key. Never put the service_role key in the app.
  - `Services/StudyRepository.swift` is a static enum, and all table reads and writes are meant to go through it, not through `supabase.from(...)` calls in views.
- **Models** (`Models/`) mirror the database rows. They are snake_case in Postgres, so each model uses explicit `CodingKeys`. Reads use full `Codable` row structs (`Event`, `Review`, `StudySpot`, `UserProfile`). Inserts use separate `Encodable` `New*` structs (`NewEvent`, `NewReview`) that leave out server-generated `id` and `created_at` fields. Study groups are not their own table: they are `events` rows with `category = study_group`, and `EventCategory` must stay in sync with the Postgres `event_category` enum.

## Database (`supabase/migrations/`)

- Tables: `profiles`, `study_spots`, `reviews`, `events`, `event_members` and `favorites`. Views: `spot_ratings` and `event_member_counts`, both `security_invoker`.
- Profiles are created by the `handle_new_user` trigger on `auth.users`. Sign-up passes `name` in the user metadata (`supabase.auth.signUp(..., data: ["name": ...])`), and the trigger copies it into the profile. The app never inserts into `profiles` directly.
- RLS is enabled on every table. Only `authenticated` users can read, and writes require `auth.uid()` to match the row's `user_id` or `created_by`. Any new write path must send the current user's id in that column, or the insert will be rejected.
- Apply schema changes by adding a new timestamped migration file, then running `supabase db push` or pasting the SQL into the Supabase SQL editor. Don't edit migrations that have already been applied.
