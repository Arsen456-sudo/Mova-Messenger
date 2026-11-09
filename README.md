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

## iPhone test build

GitHub Actions always builds the iOS Simulator app. To also export an IPA that can be installed on a physical iPhone, configure these repository Actions secrets:

- `APPLE_CERTIFICATE_BASE64` — base64-encoded Apple Distribution `.p12` certificate
- `APPLE_CERTIFICATE_PASSWORD` — password for that `.p12`
- `APPLE_PROVISIONING_PROFILE_BASE64` — base64-encoded Ad Hoc `.mobileprovision` profile
- `APPLE_TEAM_ID` — Apple Developer Team ID
- `KEYCHAIN_PASSWORD` — a temporary password used by the GitHub runner

The Ad Hoc profile must use bundle ID `app.mova.messenger` and include the target iPhone's registered UDID. After adding the secrets, push to `main` or run **Build Mova iOS** manually. Download the `mova-iphone-ipa` artifact from the completed Actions run. Without signing secrets, Actions creates only the simulator artifact.
