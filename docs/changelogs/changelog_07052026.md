# Changelog – 07/05/2026

## Summary

Session focused on centralizing the project's configuration management: a new `config.sh` script was introduced to generate and keep in sync all environment files across the stack (Docker, backend, frontend, Angular CSP). Automation scripts `start.sh` and `stop.sh` were updated to read ports dynamically from those files instead of hardcoded values. A full reference for all management scripts was added to `README.md`.

---

## [Tooling] `config.sh` — Centralized configuration script

### Added

New `config.sh` script at the repository root that writes and synchronizes the following files in a single operation:

| File                                             | Purpose                                                         |
| ------------------------------------------------ | --------------------------------------------------------------- |
| `docker/.env`                                    | Docker stack variables (PostgreSQL, JWT, Kong, Mailpit, GoTrue) |
| `back/task-manager/.env`                         | Express backend environment                                     |
| `front/task-manager/src/app/core/environment.ts` | Angular runtime configuration                                   |
| `front/task-manager/angular.json`                | Content Security Policy `connect-src` directive                 |

### Default values (hardcoded as `readonly` constants)

| Variable                        | Default                                                        |
| ------------------------------- | -------------------------------------------------------------- |
| Frontend port                   | `4200`                                                         |
| Backend port                    | `3000`                                                         |
| Supabase / Kong HTTP port       | `5433`                                                         |
| Kong HTTPS port                 | `5434`                                                         |
| PostgreSQL port                 | `5432`                                                         |
| Mailpit UI port                 | `5435`                                                         |
| `POSTGRES_PASSWORD`             | `your-super-secret-and-long-postgres-password`                 |
| `JWT_SECRET`                    | `your-super-secret-jwt-token-with-at-least-32-characters-long` |
| `ANON_KEY` / `SERVICE_ROLE_KEY` | Pre-generated for the default JWT secret                       |

### Flags implemented

**Ports**

| Flag   | Alias             | Description                   |
| ------ | ----------------- | ----------------------------- |
| `-fp`  | `--frontend-port` | Angular dev server port       |
| `-bp`  | `--backend-port`  | Express API port              |
| `-sbp` | `--supabase-port` | Kong HTTP port (Supabase URL) |
| `-dbp` | `--db-port`       | PostgreSQL port               |
| `-mp`  | `--mail-port`     | Mailpit UI port               |

**Security**

| Flag  | Alias                 | Description                                                                                                       |
| ----- | --------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `-pp` | `--postgres-password` | PostgreSQL password                                                                                               |
| `-js` | `--jwt-secret`        | JWT secret (≥ 32 chars); automatically regenerates `ANON_KEY` and `SERVICE_ROLE_KEY` via an inline Node.js script |

**Behavior**

| Flag                                 | Description                                 |
| ------------------------------------ | ------------------------------------------- |
| `--no-signup` / `--signup`           | Toggle `DISABLE_SIGNUP` in GoTrue           |
| `--autoconfirm` / `--no-autoconfirm` | Toggle `ENABLE_EMAIL_AUTOCONFIRM` in GoTrue |

**Utilities**

| Flag           | Alias    | Description                                                                                             |
| -------------- | -------- | ------------------------------------------------------------------------------------------------------- |
| `--init`       | —        | Creates missing config files with defaults; skips files that already exist (safe for first `git clone`) |
| `--reset-conf` | —        | Overwrites all config files with defaults; prompts for confirmation                                     |
| `-y`           | `--yes`  | Skips confirmation prompt in `--reset-conf`                                                             |
| `--show`       | —        | Displays current configuration with masked secrets; no writes                                           |
| `-h`           | `--help` | Prints full usage reference                                                                             |

### Implementation details

- `get_env_var()` helper reads a key from a `.env` file with a fallback default; used to capture current values before applying overrides.
- `set_env_var()` helper uses an inline Python 3 script to safely update (or append) a key in a `.env` file, correctly handling values that contain special characters.
- `update_env_ts()` uses a Python 3 regex script to update only the active (non-commented) `supabaseUrl`, `supabaseKey`, and `backendUrl` lines in `environment.ts`, preserving the commented-out remote Supabase section.
- `update_angular_csp()` replaces old `http://localhost:<port>` occurrences in `angular.json`'s `connect-src` header with the new ports.
- `write_defaults()` is shared by both `--init` and `--reset-conf`; behavior is controlled by a `mode` parameter (`"init"` skips existing files, `"reset"` overwrites all).
- After applying changes, the script computes whether a `--prune` restart (DB/JWT/Docker port changes) or a plain restart (app port/behavior changes) is needed and prints the appropriate command.
- `KONG_HTTPS_PORT` is automatically derived as `KONG_HTTP_PORT + 1`.
- Port validation: rejects values outside `1024–65535` and warns if two or more ports share the same value.

---

## [Tooling] `start.sh` / `stop.sh` — Dynamic port resolution

### Changed

Both scripts previously had ports `3000` and `4200` hardcoded. They now read the active configuration at startup:

```bash
_cfg() { ... }   # reads a key from a .env file with fallback

FRONT_PORT=$(_cfg "$DOCKER_ENV"               "FRONTEND_PORT"  "4200")
BACK_PORT=$( _cfg "$SCRIPT_DIR/back/.../.env" "PORT"           "3000")
SB_PORT=$(   _cfg "$DOCKER_ENV"               "KONG_HTTP_PORT" "5433")
MAIL_PORT=$( _cfg "$DOCKER_ENV"               "MAILPIT_UI_PORT" "5435")
```

- `start.sh`: `kill_port`, health-check URLs, `ng serve --port`, and the final summary banner all use these variables.
- `stop.sh`: the port kill loop (`for PORT in "$BACK_PORT" "$FRONT_PORT"`) now targets the configured ports.

---

## [Docker] `docker/.env` — `FRONTEND_PORT` variable added

### Changed

`FRONTEND_PORT=4200` was added to the `docker/.env` file under the `# Frontend (Angular)` section. This variable is:

- Read by `start.sh` / `stop.sh` to know which port Angular is serving on.
- Written/updated by `config.sh` whenever the frontend port is changed.
- Used by GoTrue's `SITE_URL` and `ADDITIONAL_REDIRECT_URLS` generation in `config.sh`.

---

## [Docs] `README.md` — Management scripts reference

### Added

New top-level section **"Scripts de Gestión del Stack"** placed before _Quick Start_, documenting all three management scripts with:

- Purpose and usage patterns for `config.sh`, `start.sh`, and `stop.sh`.
- Subsections for `--init` (first-time setup) and `--reset-conf` (reset to defaults) under `config.sh`.
- Full option tables for each script.
- Inline notes indicating which restart type is required after each category of change.

---

## Files modified / created

| File          | Operation                                                                              |
| ------------- | -------------------------------------------------------------------------------------- |
| `config.sh`   | **Created** — centralized configuration script                                         |
| `docker/.env` | Modified — added `FRONTEND_PORT=4200`                                                  |
| `start.sh`    | Modified — dynamic port resolution via `_cfg()` helper; `ng serve` now passes `--port` |
| `stop.sh`     | Modified — dynamic port resolution via `_cfg()` helper                                 |
| `README.md`   | Modified — added management scripts reference section                                  |

---

## Summary

Session focused on introducing workspace-level Copilot customization for repeatable development workflows: a full-stack custom agent was added with stricter TypeScript and Angular quality gates, plus two specialized subagents (testing and changelog writing) and a reusable slash prompt for changelog updates.

---

## [Tooling] Workspace custom agents for development quality

### Added

Created a new custom agent architecture under `.github/agents/`:

- `Task Manager Dev` as the primary full-stack agent (`fullstack-dev.agent.md`)
- `testing-specialist` for test-specific workflows (`testing-specialist.agent.md`)
- `changelog-writer` for changelog-only updates (`changelog-writer.agent.md`)

### Changed

`Task Manager Dev` now enforces stronger quality and separation rules:

- Explicit model selection for implementation-heavy tasks: `Claude Sonnet 4.5 (copilot)`
- Strict TypeScript quality gate with explicit checks (`tsc --noEmit`, no `any`)
- Explicit architectural rule: no inline interfaces/types inside components or services
- Delegation configuration to route testing tasks to `testing-specialist` and changelog tasks to `changelog-writer`

### Implementation details

| File                                         | Key behavior introduced                                                                                                                                   |
| -------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.github/agents/fullstack-dev.agent.md`      | Full-stack role, tool access (`read/edit/execute/search/todo/agent`), quality gate, and subagent delegation rules                                         |
| `.github/agents/testing-specialist.agent.md` | Jest + Vitest testing conventions, mock strategy, no-network test constraints, and strict typing rules                                                    |
| `.github/agents/changelog-writer.agent.md`   | Changelog-only responsibilities, append-only policy, mandatory date/file naming format, and `GPT-5 mini (copilot)` model for lightweight repetitive tasks |
| `.github/prompts/changelog.prompt.md`        | Reusable slash prompt to create or append same-day changelog entries following project format                                                             |

---

## Files modified / created (this session)

| File                                         | Operation                                                                                |
| -------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `.github/agents/fullstack-dev.agent.md`      | **Created** — primary full-stack custom agent with quality gates and subagent delegation |
| `.github/agents/testing-specialist.agent.md` | **Created** — specialized testing subagent for Jest/Vitest workflows                     |
| `.github/agents/changelog-writer.agent.md`   | **Created** — specialized changelog subagent (append-only, English, fixed format)        |
| `.github/prompts/changelog.prompt.md`        | **Created** — slash prompt for standardized changelog updates                            |
