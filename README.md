# Internal Learning Portal

Internal learning portal for administrators, teachers, and students. The workspace is split into `Frontend` (React 18 + Vite) and `Backend` (Express + TypeScript); Supabase schema and RLS live in `supabase/migrations`.

## Requirements

- Node.js 20+
- A Supabase project with email/password auth enabled and public sign-ups disabled

## Local setup

1. Copy `Frontend/.env.example` to `Frontend/.env.local` and `Backend/.env.example` to `Backend/.env`.
2. Set the Supabase URL and anon key in the frontend. Set the URL, anon key, service role key, and allowed frontend origin in the backend. Keep the service role key on the server only.
3. Apply `supabase/migrations/0001_initial_schema.sql` to your Supabase project.
4. The migration creates private `resources` and `submissions` Storage buckets with 20 MB limits. Confirm both buckets remain private in Supabase Storage settings.
5. In separate terminals, install dependencies and start each app:

   ```sh
   cd Backend
   npm install
   npm run dev
   ```

   ```sh
   cd Frontend
   npm install
   npm run dev
   ```

   Run the API middleware checks with `cd Backend && npm test`.

The API listens on `http://localhost:4000`; Vite serves the web app at `http://localhost:5173`.

## Security and bootstrap

There is no public registration route. Create the first administrator with a one-time trusted script using the Supabase service role, then create other accounts through the administrator API. Do not expose service credentials to Vite or commit populated `.env` files. Every protected API call must use a Supabase access token. Database RLS remains enabled as a second authorization layer.

## Demo accounts (local development only)

After applying the schema migration, run `supabase/seed.sql` against your local/development Supabase database to create the demo users, courses, and enrollments. All demo accounts use the password `ChangeMe123!` and require a password change at first sign-in.

| Role | Email |
| --- | --- |
| Administrator | `admin@northstar.local` |
| Teacher | `jordan@northstar.local` |
| Teacher | `mika@northstar.local` |
| Student | `avery@northstar.local` |
| Student | `kai@northstar.local` |
| Student | `sam@northstar.local` |
| Student | `noor@northstar.local` |
| Student | `eli@northstar.local` |

These are sample credentials for local demos only. Do not run the seed script against production or reuse its password for real accounts.

## Deployment

- Deploy `Frontend` to Vercel or Netlify. Set `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, and `VITE_API_URL`.
- Deploy `Backend` to Render, Railway, or Fly. Set `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `CORS_ORIGIN`, and `PORT`.
- Add the deployed `/reset-password` URL to Supabase Auth redirect allowlist.
- Keep sign-ups disabled in Supabase Auth settings and use private Storage buckets with short-lived signed URLs.

## Project map

- `Frontend/src/routes/App.tsx` — learner, teacher, and administrator portal views
- `Backend/src` — API, auth middleware, validation and feature routes
- `supabase/migrations` — schema, helper functions, indexes, and RLS policies
- `supabase/seed.sql` — local development demo users, courses, and enrollments

## Implemented workflows

- Role-based sign-in, password recovery/change, profile settings, and admin-managed user accounts.
- Course creation, teacher assignment, student enrollment by email or roll number, and course catalog views.
- Private course resource uploads/downloads, assignments and submissions, timed quizzes, grading, and marks.
- Course/campus announcements, classroom chat, and student complaints with an admin response workflow.
- Admin overview counts, active course list, and complaint inbox.

The Supabase project is a required runtime dependency for persistent accounts and data. Configure both environment files, apply the migration, then run the local development seed before signing in. The browser-only role previews are for UI exploration and do not save data.
