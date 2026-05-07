# Supabase Local – Docker

Este directorio contiene el stack de Docker que reemplaza al proyecto remoto de Supabase, permitiendo correr el Task Manager completamente en local.

## Servicios

| Servicio   | Imagen                          | Puerto local | Descripción                          |
|------------|---------------------------------|-------------|--------------------------------------|
| `db`       | `supabase/postgres:15.8.1.060`  | `54322`     | PostgreSQL con schema auth incluido  |
| `auth`     | `supabase/gotrue:v2.170.0`      | interno     | Autenticación JWT (GoTrue)           |
| `rest`     | `postgrest/postgrest:v12.2.3`   | interno     | REST API de la base de datos         |
| `kong`     | `kong:2.8.1`                    | `54321`     | API Gateway (mismo puerto que CLI)   |
| `mail`     | `axllent/mailpit:latest`        | `54324`     | UI de emails (reset de contraseña)   |

## Inicio rápido

### 1. Copia y ajusta las variables de entorno

```bash
cp docker/.env.example docker/.env
```

Edita `docker/.env` y cambia al menos `POSTGRES_PASSWORD`.  
Si cambias `JWT_SECRET` también debes regenerar los JWT keys:

```bash
node docker/generate-jwt-keys.mjs "tu-nuevo-secret-de-32-caracteres-o-mas"
```

### 2. Levanta el stack

```bash
# Desde la raíz del proyecto
docker compose --env-file docker/.env up -d
```

### 3. Configura el backend

Crea/edita `back/task-manager/.env`:

```env
PORT=3000
NODE_ENV=development

SUPABASE_URL=http://localhost:54321
SUPABASE_PUBLISHABLE_KEY=<valor de ANON_KEY en docker/.env>
FRONTEND_RESET_PASSWORD_URL=http://localhost:4200/reset-password
```

### 4. Configura el frontend

Edita `front/task-manager/src/app/core/environment.ts`:

```typescript
export const environment = {
  production: false,
  supabaseUrl: 'http://localhost:54321',
  supabaseKey: '<valor de ANON_KEY en docker/.env>',
  backendUrl: 'http://localhost:3000',
};
```

### 5. Verifica que todo esté corriendo

```bash
# API Gateway (debe devolver 404 o respuesta de Kong)
curl http://localhost:54321

# Auth (debe devolver {"version":"..."})
curl http://localhost:54321/auth/v1/health

# REST API (debe devolver el schema público)
curl http://localhost:54321/rest/v1/

# Base de datos directa
psql -h localhost -p 54322 -U postgres -d postgres
```

### 6. Ver emails de prueba (reset de contraseña)

Abre **http://localhost:54324** en el navegador. Mailpit captura todos los emails enviados por GoTrue.

## Detener y limpiar

```bash
# Solo detener (mantiene los datos)
docker compose --env-file docker/.env down

# Detener y borrar todos los datos (volumen db-data)
docker compose --env-file docker/.env down -v
```

## Estructura de archivos

```
docker/
  .env.example              Variables de entorno (copiar a .env)
  .env                      Variables activas (NO commitear)
  generate-jwt-keys.mjs     Script para regenerar JWT keys
  README.md                 Este archivo
  volumes/
    db/
      init/
        01-schema.sql       Tablas públicas + RLS (se ejecuta al crear el contenedor)
    kong/
      kong.yml              Rutas del API Gateway
```

## Notas

- Los datos de PostgreSQL se persisten en el volumen Docker `db-data`. Si borras el proyecto con `docker compose down -v`, perderás todos los datos.
- La imagen `supabase/postgres` ya incluye el schema `auth` (tablas de GoTrue, roles, funciones `auth.uid()`, etc.). No necesitas crearlo manualmente.
- `ENABLE_EMAIL_AUTOCONFIRM=true` evita que los nuevos usuarios tengan que verificar su email. Cambia a `false` para probar el flujo completo de verificación.
- Los JWT keys incluidos en `.env.example` son solo para desarrollo local. **Nunca los uses en producción.**
