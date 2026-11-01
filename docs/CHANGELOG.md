# Changelog

## v0.2 — Initial implementation

- Added responsive React/Vite portal foundations for administrator, teacher, and student roles.
- Added internal login, rate-limited API sign-in, password reset flow, forced first-login password change, and profile settings.
- Added Express API with request-scoped Supabase clients so normal API access is subject to Postgres RLS. The service role is limited to managed user lifecycle and audit operations.
- Added schema, indexes, helper functions, row-level policies, audit trail, private file policies, and separated quiz answer keys.
- Added course, resource, assignment, quiz, marks, announcement, chat, and complaint API/UI foundations.
- Added local development seed accounts and setup/deployment guidance.

## v0.1

- Initial feature specification.
