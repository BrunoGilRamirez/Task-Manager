# Changelog – 04/05/2026

## Summary

Session focused on replacing the remote Supabase Cloud project with a full local Docker stack, and on fixing all errors that arose when integrating the frontend + backend against that stack.

---

## [Docker] Local Supabase stack

### Added

- `docker-compose.yml` at the repository root with 6 services:
  - **db** – PostgreSQL 15 with a custom image (roles baked-in)
  - **auth** – GoTrue `v2.170.0` for authentication
  - **rest** – PostgREST `v12.2.3` as the DB REST API
  - **kong** – Kong `2.8.1` as API Gateway on `:5433`
  - **mail** – Mailpit for capturing local emails on `:5435`
  - **db-setup** – One-shot service to initialize the public schema
- `docker/.env` with all stack variables (JWT secret, ANON_KEY, SERVICE_ROLE_KEY, ports, SMTP, etc.)
- `docker/volumes/db/Dockerfile` – `postgres:15` image with init script baked-in (no bind mounts due to Docker Desktop Windows long-path limitations)
- `docker/volumes/kong/Dockerfile` + `kong.yml` – declarative Kong configuration
- `docker/volumes/db-setup/Dockerfile` + `setup.sh` – phase 2 service

### Assigned ports (avoiding conflicts with Docker Desktop WSL)

| Port | Service                      |
| ---- | ---------------------------- |
| 5432 | PostgreSQL                   |
| 5433 | Kong HTTP (= `SUPABASE_URL`) |
| 5434 | Kong HTTPS                   |
| 5435 | Mailpit UI                   |

---

## [Docker] Two-phase initialization architecture

### Problem

GoTrue failed with `type "auth.factor_type" does not exist` because the `supabase_auth_admin` role did not have `search_path = auth`, and its ENUM types were created in `public` instead of `auth`, corrupting the migration ordering.

### Solution

- **Phase 1** (`docker/volumes/db/init/00-init.sh`): creates only PostgreSQL roles + an empty `auth` schema. It does not touch `auth` tables or functions.
  - Added `ALTER ROLE supabase_auth_admin SET search_path TO auth, public` so GoTrue migrations create their objects in the correct schema.
- **Phase 2** (`docker/volumes/db-setup/setup.sh`): runs as a separate service with `depends_on: auth: service_healthy`. It creates `public.users`, `public.tasks`, the `update_updated_at_column` trigger and all RLS policies once GoTrue has finished its 54 migrations.
- Removed `01-schema.sql` from the `db` Dockerfile (it no longer belongs to phase 1).
- Added a `healthcheck` to the `auth` service (wget `/health`) so `db-setup` waits correctly.

---

## [Docker / Kong] CORS: `x-supabase-api-version` header blocked

### Problem

The `@supabase/supabase-js` client sends the `x-supabase-api-version` header on all requests. Kong blocked it in the preflight OPTIONS with `not allowed by Access-Control-Allow-Headers`.

### Solution

Added `X-Supabase-Api-Version` to the `headers` list of the `cors` plugin in `docker/volumes/kong/kong.yml` for both services (`auth-v1` and `rest-v1`). Rebuilt the Kong image to bake the change.

---

## [Angular] CSP: connection to `localhost:5433` blocked

### Problem

The `connect-src` directive in `angular.json` only allowed `http://localhost:3000` and `https://dvyjtwsauondclauycvi.supabase.co`. Requests to the local Docker stack (`http://localhost:5433`) were blocked by the Content Security Policy.

### Solution

Added `http://localhost:5433` to the `connect-src` in `front/task-manager/angular.json`.

---

## [Backend / DB] 500 error when creating tasks: FK violation on `public.users`

### Problem

When registering a user, GoTrue creates the row in `auth.users` but `public.users` remained empty. When attempting to create a task, the FK `tasks.owner_id → public.users.id` failed with an `undefined` error (PostgREST returns the error description in a different field than expected).

### Solution

Added to the `db-setup` `setup.sh`:

1.  **Function** `public.handle_new_user()` with `SECURITY DEFINER` that automatically inserts into `public.users` when a new user is registered in `auth.users`, taking the name from `raw_user_meta_data->>'name'`.
2.  **Trigger** `on_auth_user_created` on `auth.users` (`AFTER INSERT`) that calls the function.
3.  **Backfill** using `INSERT ... ON CONFLICT DO NOTHING` to synchronize existing `auth.users` rows that had no corresponding `public.users` entry.

---

## [Docker / PostgREST] 404 on `/rest/v1/users` and `/rest/v1/tasks`

### Problem

PostgREST started before `db-setup` created the tables, so it loaded its schema cache with 0 relations and returned 404 on all endpoints.

### Solution

After running `db-setup`, sent `NOTIFY pgrst, 'reload schema'` to PostgreSQL and restarted the `rest` container. PostgREST reloaded the schema with **2 Relations** and **3 Relationships**.

---

## [Angular / AuthService] Username not updated in UI after save

### Problem

`UserProfile.handleSave()` called `userService.updateProfile()` correctly (the backend updated `public.users.name` and returned 200), but the `AuthService.currentUser$` BehaviorSubject did not update, so the UI displayed the old name.

### Solution

- Added the method `updateCurrentUserName(name: string)` to `AuthService` that emits a new value to the `currentUserSubject` with the updated name.
- `UserProfile.handleSave()` now calls `authService.updateCurrentUserName(updatedUser.name)` in the observable's `next` callback.

---

## [DB] Sample data

Inserted 10 example tasks for the existing user (`Bruno Gil`):

| #   | Title                             | Completed |
| --- | --------------------------------- | --------- |
| 1   | Set up development environment    | ✅        |
| 2   | Design database schema            | ✅        |
| 3   | Implement Supabase authentication | ✅        |
| 4   | Create backend REST API           | ❌        |
| 5   | Build task UI in Angular          | ❌        |
| 6   | Add pagination and filters        | ❌        |
| 7   | Write backend unit tests          | ❌        |
| 8   | Configure local Docker stack      | ✅        |
| 9   | Review RLS policies               | ❌        |
| 10  | Deploy to production              | ❌        |

---

## Modified / created files

| File                                                           | Operation                                                   |
| -------------------------------------------------------------- | ----------------------------------------------------------- |
| `docker-compose.yml`                                           | Created                                                     |
| `docker/.env`                                                  | Created                                                     |
| `docker/volumes/db/Dockerfile`                                 | Created                                                     |
| `docker/volumes/db/init/00-init.sh`                            | Created → refactored (roles only, + search_path)            |
| `docker/volumes/kong/Dockerfile`                               | Created                                                     |
| `docker/volumes/kong/kong.yml`                                 | Created → added `X-Supabase-Api-Version` to CORS            |
| `docker/volumes/db-setup/Dockerfile`                           | Created                                                     |
| `docker/volumes/db-setup/setup.sh`                             | Created → added `handle_new_user` trigger + backfill        |
| `front/task-manager/angular.json`                              | Modified – `connect-src` added `http://localhost:5433`      |
| `front/task-manager/src/app/core/environment.ts`               | Modified – points to local Docker stack                     |
| `back/task-manager/.env`                                       | Modified – `SUPABASE_URL` points to `http://localhost:5433` |
| `front/task-manager/src/app/auth/auth.service.ts`              | Modified – added `updateCurrentUserName()`                  |
| `front/task-manager/src/app/user/user-profile/user-profile.ts` | Modified – `handleSave` propagates name to `AuthService`    |
