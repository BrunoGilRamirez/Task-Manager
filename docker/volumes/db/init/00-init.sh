#!/usr/bin/env bash
# =============================================================================
# Fase 1 – Roles de Supabase en PostgreSQL estándar
#
# Solo crea los roles y el schema auth vacío.
# GoTrue creará todas las tablas y funciones de auth al arrancar.
# Las tablas del dominio público (users, tasks) las crea el servicio db-setup
# una vez que GoTrue haya terminado sus migraciones.
# =============================================================================
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL

  -- ── Roles sin login (usados como grants) ────────────────────────────────
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
      CREATE ROLE anon NOLOGIN NOINHERIT;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN
      CREATE ROLE authenticated NOLOGIN NOINHERIT;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'service_role') THEN
      CREATE ROLE service_role NOLOGIN NOINHERIT BYPASSRLS;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'supabase_auth_admin') THEN
      CREATE ROLE supabase_auth_admin NOLOGIN CREATEROLE;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'supabase_admin') THEN
      CREATE ROLE supabase_admin NOLOGIN BYPASSRLS;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'supabase_replication_admin') THEN
      CREATE ROLE supabase_replication_admin LOGIN REPLICATION;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'supabase_read_only_user') THEN
      CREATE ROLE supabase_read_only_user LOGIN BYPASSRLS;
    END IF;
  END \$\$;

  -- ── Rol authenticator (login) usado por PostgREST ───────────────────────
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticator') THEN
      CREATE ROLE authenticator NOINHERIT LOGIN PASSWORD '$POSTGRES_PASSWORD';
    ELSE
      ALTER ROLE authenticator WITH PASSWORD '$POSTGRES_PASSWORD';
    END IF;
  END \$\$;

  -- ── Activar login + password en supabase_auth_admin ─────────────────────
  ALTER ROLE supabase_auth_admin WITH LOGIN PASSWORD '$POSTGRES_PASSWORD';
  -- Fijar search_path para que los objetos no-calificados vayan a auth, no a public
  ALTER ROLE supabase_auth_admin SET search_path TO auth, public;

  -- ── Otorgar roles a authenticator (PostgREST los usa para cambiar rol) ───
  GRANT anon          TO authenticator;
  GRANT authenticated TO authenticator;
  GRANT service_role  TO authenticator;

  -- ── Otorgar supabase_admin a postgres ────────────────────────────────────
  GRANT supabase_admin TO postgres;

  -- ── Config JWT para PostgREST ─────────────────────────────────────────────
  ALTER DATABASE postgres SET "app.settings.jwt_secret" TO '$JWT_SECRET';
  ALTER DATABASE postgres SET "app.settings.jwt_exp"    TO '$JWT_EXP';

  -- ── Schema auth vacío (GoTrue lo puebla completo con sus migraciones) ─────
  CREATE SCHEMA IF NOT EXISTS auth;
  ALTER SCHEMA auth OWNER TO supabase_auth_admin;
  GRANT ALL PRIVILEGES ON SCHEMA auth   TO supabase_auth_admin;
  GRANT ALL PRIVILEGES ON SCHEMA public TO supabase_auth_admin;
  GRANT USAGE ON SCHEMA auth TO postgres;

  -- ── Permisos en public para los roles de la API ───────────────────────────
  GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
  ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL ON TABLES    TO anon, authenticated, service_role;
  ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
  ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL ON FUNCTIONS TO anon, authenticated, service_role;

EOSQL
