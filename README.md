# Task Manager

Full-stack task management application using Angular 21 (frontend), Express + TypeScript (backend), and Supabase (database + auth).

## Overview

Task Manager includes:

- User authentication (sign up, sign in, forgot/reset password)
- Task CRUD (create, read, update, delete, toggle complete)
- User profile management
- Protected frontend routes with auth guards
- Backend validation, centralized error handling, logging, compression, and cache headers

## Tech Stack

- Frontend: Angular 21, TypeScript, RxJS, Supabase JS
- Backend: Express 5, TypeScript, Zod, Jose, Supabase JS
- Database/Auth: Supabase PostgreSQL + Supabase Auth
- Testing: Vitest (frontend), Jest (backend)

## Repository Layout

```text
Task Manager/
|- back/task-manager/          # Backend API
|- front/task-manager/         # Angular frontend
|- docs/                       # Support docs
|  |- TESTING.md
|  |- support_auth.md
|  |- support_material.md
|  '- screenshots/             # Installation screenshot references
'- TODO.md
```

## Stack management scripts

The project includes three Bash scripts to manage the full stack lifecycle (Docker + backend + frontend). On Windows, use [Git Bash](https://git-scm.com/downloads).

### `config.sh` — Configure environment

Generates or synchronizes all configuration files (`docker/.env`, `back/task-manager/.env`, `environment.ts`, `angular.json`).

#### First use (after `git clone`)

```bash
bash config.sh --init
```

Creates the three git-ignored files (`docker/.env`, `back/task-manager/.env`, `environment.ts`) with default values ready to start. It does not modify files that already exist.

#### Reset to default configuration

```bash
bash config.sh --reset-conf        # prompts for confirmation
bash config.sh --reset-conf -y     # no confirmation
```

Overwrites all configuration files with default values, including `angular.json` (CSP). Useful when the configuration is inconsistent or you want to return to the original state.

#### Customization

```bash
# Show current configuration
bash config.sh --show

# Change ports
bash config.sh -fp 2020 -bp 2333 -sbp 8080

# Change PostgreSQL password
bash config.sh -pp "my-new-secure-password"

# Change JWT secret (regenerates ANON_KEY and SERVICE_ROLE_KEY automatically)
bash config.sh -js "my-jwt-secret-at-least-32-chars"

# Disable signup + require email verification
bash config.sh --no-signup --no-autoconfirm

# Full help
bash config.sh --help
```

| Option                               | Alias                 | Description                                     | Default         |
| ------------------------------------ | --------------------- | ----------------------------------------------- | --------------- |
| `--init`                             | —                     | Create missing config files with default values | —               |
| `--reset-conf`                       | —                     | Reset all config to defaults (overwrites)       | —               |
| `-y`                                 | `--yes`               | Skip confirmation for `--reset-conf`            | —               |
| `-fp`                                | `--frontend-port`     | Angular dev server port                         | `4200`          |
| `-bp`                                | `--backend-port`      | Express API port                                | `3000`          |
| `-sbp`                               | `--supabase-port`     | Kong / Supabase HTTP port                       | `5433`          |
| `-dbp`                               | `--db-port`           | PostgreSQL port                                 | `5432`          |
| `-mp`                                | `--mail-port`         | Mailpit UI port                                 | `5435`          |
| `-pp`                                | `--postgres-password` | PostgreSQL password                             | —               |
| `-js`                                | `--jwt-secret`        | JWT secret (≥ 32 chars)                         | —               |
| `--no-signup` / `--signup`           | —                     | Disable / enable user signup                    | `--signup`      |
| `--autoconfirm` / `--no-autoconfirm` | —                     | Auto-confirm / require email verification       | `--autoconfirm` |
| `--show`                             | —                     | Show current configuration without changes      | —               |

> After changing passwords, Docker ports, or the JWT secret, restart with:
> `bash stop.sh --prune && bash start.sh`
>
> After changing only application ports (frontend / backend):
> `bash stop.sh && bash start.sh`

---

### `start.sh` — Start the stack

```bash
# Start everything: Docker + backend + frontend
bash start.sh

# Only start / check Docker containers
bash start.sh --docker
```

| Option        | Description                                              |
| ------------- | -------------------------------------------------------- |
| _(no option)_ | Starts Docker, backend (nodemon) and frontend (ng serve) |
| `--docker`    | Only checks / starts the Docker containers               |

Reads ports from `docker/.env` and `back/task-manager/.env` automatically.
To stop the process, press **Ctrl+C** (Docker containers will keep running).

---

### `stop.sh` — Stop the stack

```bash
# Stop Node processes + Docker containers (keep DB data)
bash stop.sh

# Only stop Docker containers
bash stop.sh --docker

# Stop containers and remove volumes (full DB reset)
bash stop.sh --prune
```

| Option        | Description                                                     |
| ------------- | --------------------------------------------------------------- |
| _(no option)_ | Kills all `node.exe` processes and stops Docker containers      |
| `--docker`    | Only stops containers (keeps Node processes)                    |
| `--prune`     | Stops containers **and removes volumes** (deletes the database) |

---

## Quick Start

### 1) Backend

```bash
cd back/task-manager
npm install
```

Create `back/task-manager/.env`:

```env
PORT=3000
NODE_ENV=development
CORS_ORIGIN=http://localhost:4200,http://127.0.0.1:4200
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_YOUR_KEY
FRONTEND_RESET_PASSWORD_URL=http://localhost:4200/reset-password
LOG_LEVEL=info
LOG_PRETTY=true
SLOW_QUERY_MS=200
```

Run backend:

```bash
npm run dev
```

Backend URL: `http://localhost:3000`

### 2) Frontend

```bash
cd front/task-manager
npm install
npm start
```

Frontend URL: `http://localhost:4200`

---

## One-step: clone, configure and run (recommended)

This project provides bash helpers to configure and run the full stack (Docker + backend + frontend). Below are concise commands and a Windows batch example to get the entire stack up and running quickly.

Notes:

- On Windows, run these commands from Git Bash (recommended) or WSL. Git Bash is required for the provided bash scripts (`config.sh`, `start.sh`, `stop.sh`).
- The `config.sh` script generates the git-ignored `.env` files used by Docker and the backend.

Unix / Git Bash (recommended):

```bash
git clone https://github.com/BrunoGilRamirez/Task-Manager.git
cd Task-Manager
# Initialize configuration files (creates docker/.env and back/task-manager/.env)
bash config.sh --init

# Start the full stack: Docker containers + backend + frontend
bash start.sh
```

To start only Docker containers:

```bash
bash start.sh --docker
```

To stop everything (keep DB data):

```bash
bash stop.sh
```

To stop and remove volumes (full reset of the database):

```bash
bash stop.sh --prune
```

Windows batch (example) — requires Git Bash in PATH

Create a file named `windows-start.bat` with the following contents and run it (double-click or `cmd.exe /c windows-start.bat`):

```bat
@echo off
REM Requires Git Bash installed and available in PATH (sh.exe)
set REPO=https://github.com/BrunoGilRamirez/Task-Manager.git

if not exist Task-Manager (
  git clone %REPO%
)
cd Task-Manager

REM Run config and start using bash (Git Bash or WSL)
bash config.sh --init
bash start.sh

pause
```

PowerShell one-liner (if Git Bash is available):

```powershell
bash -c './config.sh --init; ./start.sh'
```

If you prefer WSL, open a WSL shell and run the Unix commands above.

---

## Usage Examples

### UI Flow

1. Open `http://localhost:4200/auth/login`.
2. Register a new user at `http://localhost:4200/auth/register`.
3. Log in and create tasks from `http://localhost:4200/tasks`.
4. Open task details at `http://localhost:4200/tasks/details/:id`.
5. Manage your profile at `http://localhost:4200/me`.

### API Examples

Health check:

```bash
curl http://localhost:3000/health
```

Forgot password:

```bash
curl -X POST http://localhost:3000/api/auth/forgot-password \
  -H "Content-Type: application/json" \
  -d '{"email":"you@example.com"}'
```

Get tasks (requires JWT):

```bash
curl http://localhost:3000/api/tasks \
  -H "Authorization: Bearer <access_token>"
```

## API Summary

- Tasks: `/api/tasks` (GET, POST, GET by id, PUT, PATCH toggle, DELETE)
- Users: `/api/users/me` (GET, PUT, DELETE)
- Auth: `/api/auth/forgot-password`, `/api/auth/reset-password`
- Health: `/health`

## Testing

Backend:

```bash
cd back/task-manager
npm test
```

Frontend:

```bash
cd front/task-manager
npm test
```

Detailed guidance: `docs/TESTING.md`.

## Additional Docs

- Backend details: `back/task-manager/README.md`
- Frontend details: `front/task-manager/README.md`
- Components: `front/task-manager/COMPONENTES.md`
- Auth support: `docs/support_auth.md`
- Support material: `docs/support_material.md`

## License

ISC
