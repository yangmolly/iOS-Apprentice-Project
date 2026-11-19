# iOS-Apprentice-Project

StudySpot: a SwiftUI app for UNC students to find, rate and save study spots and join study events. The backend is Supabase.

## Setup

1. Copy the credentials template and fill in your Supabase project values (Dashboard → Project Settings → API). Use the publishable/anon key only, never the service_role key.
   ```sh
   cp Secrets.swift.example Services/Secrets.swift
   ```
   `Services/Secrets.swift` is gitignored.
2. Open `StudySpot.xcodeproj` and run the `iOSApprenticeProject` scheme.

Database migrations are in `supabase/migrations/`. Apply them in order with `supabase db push` or the Supabase SQL editor.
