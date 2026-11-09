# Architecture and privacy

## Client/server split

`shared/` owns platform-neutral models, handle validation, and Supabase repositories used by both apps. The Android and iOS directories own their native presentation and OS integrations. Supabase Auth owns email credentials; PostgreSQL stores profiles, conversations, memberships, and messages; Supabase Realtime delivers database changes.

## Identity and lookup

- Email: private account identifier, verified before account activation.
- Handle: unique, case-insensitive public lookup key beginning with `@`; enforce uniqueness atomically in the database with a unique normalized column/index.
- First name: required. Surname and avatar: optional. Birth date: collected during profile setup.
- Search by handle should rank exact normalized matches first; name search can return multiple results and must return only fields intended to be public.

The server must see the handle to provide search and enforce uniqueness. Avoid exposing email and birth date in search results or public profiles by default.

## Notes and messages

Notes is a real user-owned conversation persisted in PostgreSQL, not a fabricated chat row. The database trigger creates it only after email confirmation. Text messages are stored in PostgreSQL and clients can receive changes over Supabase Realtime, subject to row-level access policies.

## Security requirements before production

The migration enables Postgres Row Level Security and restricts profile edits to an authenticated database function; messages are limited to conversation members. Message and profile content is currently stored in plaintext, as requested. For the goal that service operators cannot read profile details or message content, encrypt those fields on the clients with keys unavailable to the service. That requires a key recovery/device enrollment design; ordinary server-side disk encryption does not provide that guarantee. Searchable handles are visible to authenticated users and the database.

Do not execute active content or file previews in a privileged WebView. Apply strict sandboxing and content-type/size limits when that feature is designed.
