# Task Manager

Full-stack task management application with Angular 21 (frontend), Express + TypeScript (backend), and Supabase (database + auth).

## Overview

Task Manager includes:

- User authentication (sign up, sign in, forgot/reset password)
- Task CRUD (create, read, update, delete, toggle complete)
- User profile management
- Protected frontend routes with auth guards
- Backend validation, centralized errors, logging, compression, and cache headers

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

## Scripts de Gestión del Stack

El proyecto incluye tres scripts Bash para gestionar el ciclo de vida del stack completo (Docker + backend + frontend). Requieren [Git Bash](https://git-scm.com/downloads) en Windows.

### `config.sh` — Configurar el entorno

Genera o actualiza de forma sincronizada todos los archivos de configuración (`docker/.env`, `back/task-manager/.env`, `environment.ts`, `angular.json`).

#### Primer uso (tras `git clone`)

```bash
bash config.sh --init
```

Crea los tres archivos ignorados por git (`docker/.env`, `back/task-manager/.env`, `environment.ts`) con los valores por defecto listos para arrancar. No modifica archivos que ya existan.

#### Resetear a configuración por defecto

```bash
bash config.sh --reset-conf        # pide confirmación
bash config.sh --reset-conf -y     # sin confirmación
```

Sobreescribe todos los archivos de configuración con los valores por defecto, incluyendo `angular.json` (CSP). Útil cuando la configuración está inconsistente o se quiere volver al estado original.

#### Personalización

```bash
# Ver configuración actual
bash config.sh --show

# Cambiar puertos
bash config.sh -fp 2020 -bp 2333 -sbp 8080

# Cambiar contraseña de PostgreSQL
bash config.sh -pp "mi-nueva-contrasena-segura"

# Cambiar JWT secret (regenera ANON_KEY y SERVICE_ROLE_KEY automáticamente)
bash config.sh -js "mi-jwt-secret-de-al-menos-32-caracteres"

# Deshabilitar registro + requerir verificación de email
bash config.sh --no-signup --no-autoconfirm

# Ayuda completa
bash config.sh --help
```

| Opción                               | Alias                 | Descripción                                                 | Defecto         |
| ------------------------------------ | --------------------- | ----------------------------------------------------------- | --------------- |
| `--init`                             | —                     | Crea archivos de config faltantes con valores por defecto   | —               |
| `--reset-conf`                       | —                     | Resetea toda la config a valores por defecto (sobreescribe) | —               |
| `-y`                                 | `--yes`               | Salta la confirmación en `--reset-conf`                     | —               |
| `-fp`                                | `--frontend-port`     | Puerto Angular dev server                                   | `4200`          |
| `-bp`                                | `--backend-port`      | Puerto Express API                                          | `3000`          |
| `-sbp`                               | `--supabase-port`     | Puerto Kong / Supabase HTTP                                 | `5433`          |
| `-dbp`                               | `--db-port`           | Puerto PostgreSQL                                           | `5432`          |
| `-mp`                                | `--mail-port`         | Puerto UI Mailpit                                           | `5435`          |
| `-pp`                                | `--postgres-password` | Contraseña de PostgreSQL                                    | —               |
| `-js`                                | `--jwt-secret`        | JWT secret (≥ 32 chars)                                     | —               |
| `--no-signup` / `--signup`           | —                     | Deshabilita / habilita el registro                          | `--signup`      |
| `--autoconfirm` / `--no-autoconfirm` | —                     | Auto-confirma / requiere verificación de email              | `--autoconfirm` |
| `--show`                             | —                     | Muestra la configuración actual sin modificar nada          | —               |

> Tras cambiar contraseñas, puertos Docker o JWT secret, reinicia con:
> `bash stop.sh --prune && bash start.sh`
>
> Tras cambiar solo puertos de aplicación (frontend / backend):
> `bash stop.sh && bash start.sh`

---

### `start.sh` — Levantar el stack

```bash
# Levantar todo: Docker + backend + frontend
bash start.sh

# Solo levantar / verificar los contenedores Docker
bash start.sh --docker
```

| Opción           | Descripción                                             |
| ---------------- | ------------------------------------------------------- |
| _(sin opciones)_ | Levanta Docker, backend (nodemon) y frontend (ng serve) |
| `--docker`       | Solo verifica / levanta los contenedores Docker         |

Lee los puertos desde `docker/.env` y `back/task-manager/.env` automáticamente.
Para detener el proceso, presiona **Ctrl+C** (los contenedores Docker siguen corriendo).

---

### `stop.sh` — Detener el stack

```bash
# Detener procesos Node + contenedores Docker (conserva la base de datos)
bash stop.sh

# Solo detener los contenedores Docker
bash stop.sh --docker

# Detener contenedores y eliminar volúmenes (reset total de la DB)
bash stop.sh --prune
```

| Opción           | Descripción                                                               |
| ---------------- | ------------------------------------------------------------------------- |
| _(sin opciones)_ | Mata todos los procesos `node.exe` y detiene los contenedores             |
| `--docker`       | Solo detiene los contenedores (conserva procesos Node)                    |
| `--prune`        | Detiene contenedores **y borra los volúmenes** (elimina la base de datos) |

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
