# Messenger project instructions

- Keep platform interfaces native: UIKit with Swift on iOS, Jetpack Compose with Material 3 on Android.
- Put shared business rules, models, validation, Supabase access, and platform-neutral state in `shared/` (Kotlin Multiplatform). Keep iOS- and Android-specific UI/platform adapters in their own directories.
- Build reusable UI components and design tokens before repeating them: shared spacing, colors, typography, buttons, fields, and common screen patterns must have one source of truth per platform.
- Prefer small, focused modules and files; avoid duplicating behavior or styling across screens.
- Treat privacy and security as architectural requirements. Never claim server-stored data is invisible to server operators unless end-to-end encryption or client-side encryption actually makes that true. Keep public lookup data minimal and document trust boundaries.
- Persist messages in Supabase; do not substitute local demo data for real network behavior.
- Keep Android, iOS, shared logic, and Supabase migrations/configuration organized in separate directories.
