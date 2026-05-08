# Supabase Local – Docker

This directory contains the local Docker stack that replaces the remote Supabase project, allowing the Task Manager to run entirely locally.

## Services

| Service | Image                          | Local port | Description                                 |
| ------- | ------------------------------ | ---------- | ------------------------------------------- |
| `db`    | `supabase/postgres:15.8.1.060` | `54322`    | PostgreSQL with the `auth` schema included  |
| `auth`  | `supabase/gotrue:v2.170.0`     | internal   | JWT authentication (GoTrue)                 |
| `rest`  | `postgrest/postgrest:v12.2.3`  | internal   | REST API for the database                   |
| `kong`  | `kong:2.8.1`                   | `54321`    | API Gateway (same port as the Supabase CLI) |
| `mail`  | `axllent/mailpit:latest`       | `54324`    | Email UI (password reset capture)           |

## Quick Start

### 1. Copy and adjust environment variables

```bash
cp docker/.env.example docker/.env
```

Edit `docker/.env` and change at least `POSTGRES_PASSWORD`.  
If you change `JWT_SECRET` you should also regenerate the JWT keys:

```bash
node docker/generate-jwt-keys.mjs "your-new-32+chars-secret"
```

### 2. Bring up the stack

```bash
# From the repository root
docker compose --env-file docker/.env up -d
```

### 3. Configure the backend

Create or edit `back/task-manager/.env`:

```env
PORT=3000
NODE_ENV=development

SUPABASE_URL=http://localhost:54321
SUPABASE_PUBLISHABLE_KEY=<ANON_KEY from docker/.env>
FRONTEND_RESET_PASSWORD_URL=http://localhost:4200/reset-password
```

### 4. Configure the frontend

Edit `front/task-manager/src/app/core/environment.ts`:

```typescript
export const environment = {
  production: false,
  supabaseUrl: "http://localhost:54321",
  supabaseKey: "<ANON_KEY from docker/.env>",
  backendUrl: "http://localhost:3000",
};
```

### 5. Verify the services are running

```bash
# API Gateway (should return 404 or Kong response)
curl http://localhost:54321

# Auth (should return {"version":"..."})
curl http://localhost:54321/auth/v1/health

# REST API (should return the public schema)
curl http://localhost:54321/rest/v1/

# Direct DB access
psql -h localhost -p 54322 -U postgres -d postgres
```

### 6. View test emails (password reset)

Open **http://localhost:54324** in your browser. Mailpit captures all emails sent by GoTrue.

## Stop and cleanup

```bash
# Stop only (preserve data)
docker compose --env-file docker/.env down

# Stop and remove all data (db-data volume)
docker compose --env-file docker/.env down -v
```

## File structure

```
docker/
  .env.example              Environment variables (copy to .env)
  .env                      Active variables (DO NOT commit)
  generate-jwt-keys.mjs     Script to regenerate JWT keys
  README.md                 This file
  volumes/
    db/
      init/
        01-schema.sql       Public tables + RLS (runs when the container is created)
    kong/
      kong.yml              API Gateway routes
```

## Notes

- PostgreSQL data is persisted in the Docker volume `db-data`. If you remove the project with `docker compose down -v`, you will lose all data.
- The `supabase/postgres` image already includes the `auth` schema (GoTrue tables, roles, `auth.uid()` helpers, etc.). You don't need to create it manually.
- Setting `ENABLE_EMAIL_AUTOCONFIRM=true` will skip email verification for new users. Set it to `false` to test the full confirmation flow.
- The JWT keys included in `.env.example` are for local development only. **Never use them in production.**
