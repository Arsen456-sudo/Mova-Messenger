# Messenger

Fresh-start cross-platform messenger foundation.

## Structure

- `android/` — native Android application (Kotlin, Jetpack Compose, Material 3)
- `ios/` — native iOS application (Swift, UIKit)
- `shared/` — Kotlin Multiplatform business logic used by both clients
- `supabase/` — PostgreSQL schema and access policies for Supabase
- `docs/` — architecture and security decisions

The foundation is designed around Supabase Auth, account/profile setup, unique `@handles`, a server-backed Notes chat, user search, and real-time text messages. UI polish and feature expansion follow later.

## Important security boundary

The handle must be searchable, so Supabase necessarily stores a normalized handle index. Email is required for account authentication, while first name is required, surname and avatar are optional, and birth date is collected. Profile fields and message bodies are stored as ordinary database values for now, as requested. End-to-end encryption can be added later.

## Build prerequisites

JDK 17 or later, Gradle, Android SDK, and Xcode on macOS are required. iOS apps cannot be compiled or run on Windows. Create a Supabase project, run the migration in `supabase/migrations/`, then configure the project URL and publishable key as described in `supabase/README.md`.
