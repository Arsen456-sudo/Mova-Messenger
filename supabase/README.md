# Supabase setup

## Connected project

The messenger foundation is applied to the Supabase Free project `wrfobivetcqxstqugvsg`.

- Project URL: `https://wrfobivetcqxstqugvsg.supabase.co`
- Publishable key: `sb_publishable_7H-kTsq5rfvjy8KbXkt6OQ_bypN6ZWb`
- Database: PostgreSQL 17; migration `202611090001_messenger_foundation.sql`

The publishable key is intended for client apps. Never put a `service_role` or secret key in either mobile app.

1. In Authentication → URL Configuration, add the app's redirect/deep-link URL before testing sign-up end to end. Configure email delivery and confirmation for the intended app flow.
2. For Android, add these lines to the root `local.properties` file (it is not committed):

   ```properties
   supabase.url=https://wrfobivetcqxstqugvsg.supabase.co
   supabase.publishableKey=sb_publishable_7H-kTsq5rfvjy8KbXkt6OQ_bypN6ZWb
   ```

3. For iOS, add the same values to a local `Supabase.xcconfig` file and load it from the Xcode target. Do not commit that local configuration file.

The Kotlin SDK used here (`supabase-kt`) is a Kotlin Multiplatform community SDK documented by Supabase. Shared business logic stays in Kotlin; UIKit and Compose remain native. The signup trigger reserves the handle on the server immediately and only publishes the profile and creates Notes after email confirmation.

This stage stores profile and message content as ordinary database values, as requested. The migration still turns on Postgres RLS and limits data access to authenticated users and conversation members; this is baseline access control, not end-to-end encryption.
