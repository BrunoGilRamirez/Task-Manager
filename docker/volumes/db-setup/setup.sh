#!/usr/bin/env bash
# =============================================================================
# Phase 2 – Public domain tables + RLS
#
# Runs AFTER GoTrue has finished its migrations (auth is healthy).
# At this point auth.users already exists with its full structure and
# auth.uid() / auth.role() are defined, so we can safely create the
# public tables with FKs and RLS policies.
# =============================================================================
set -euo pipefail

echo "[db-setup] Waiting for PostgreSQL to be ready..."
until pg_isready -h db -p 5432 -U "$POSTGRES_USER" -d "$POSTGRES_DB"; do
  sleep 2
done

echo "[db-setup] Creating public schema (tables + RLS)..."
psql -v ON_ERROR_STOP=1 \
     -h db -p 5432 \
     -U "$POSTGRES_USER" \
     -d "$POSTGRES_DB" <<-'EOSQL'

-- =============================================================================
-- Public domain tables
-- =============================================================================

SET search_path TO public;

-- ── Helper function: keep updated_at up to date ──────────────────────────
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ── Tabla: public.users ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.users (
  id   uuid NOT NULL,
  name text NOT NULL,
  CONSTRAINT users_pkey PRIMARY KEY (id),
  CONSTRAINT users_id_fkey FOREIGN KEY (id)
    REFERENCES auth.users (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- ── Tabla: public.tasks ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.tasks (
  id          serial      NOT NULL,
  title       text        NOT NULL,
  description text            NULL,
  completed   boolean     NOT NULL DEFAULT false,
  owner_id    uuid        NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT tasks_pkey PRIMARY KEY (id),
  CONSTRAINT tasks_owner_id_fkey FOREIGN KEY (owner_id)
    REFERENCES public.users (id) ON UPDATE CASCADE ON DELETE CASCADE
) TABLESPACE pg_default;

-- Trigger: keep updated_at up to date on tasks
DROP TRIGGER IF EXISTS update_tasks_updated_at ON public.tasks;
CREATE TRIGGER update_tasks_updated_at
  BEFORE UPDATE ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- =============================================================================
-- Trigger: auto-crear fila en public.users cuando se registra en auth.users
-- Uses SECURITY DEFINER so the insert runs as postgres
-- (bypasses RLS) regardless of the role that triggered the event.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1))
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Quitar trigger previo si existe y recrearlo
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Backfill: sincronizar usuarios existentes en auth.users que no tienen perfil
INSERT INTO public.users (id, name)
SELECT
  id,
  COALESCE(raw_user_meta_data->>'name', split_part(email, '@', 1))
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- Row Level Security (RLS)
-- =============================================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- ── Policies for public.users ───────────────────────────────────────────────
DROP POLICY IF EXISTS users_select_own ON public.users;
CREATE POLICY users_select_own ON public.users
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = id);

DROP POLICY IF EXISTS users_insert_own ON public.users;
CREATE POLICY users_insert_own ON public.users
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = id);

DROP POLICY IF EXISTS users_update_own ON public.users;
CREATE POLICY users_update_own ON public.users
  FOR UPDATE TO authenticated
  USING  ((SELECT auth.uid()) = id)
  WITH CHECK ((SELECT auth.uid()) = id);

DROP POLICY IF EXISTS users_delete_own ON public.users;
CREATE POLICY users_delete_own ON public.users
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = id);

-- ── Policies for public.tasks ───────────────────────────────────────────────
DROP POLICY IF EXISTS tasks_select_own ON public.tasks;
CREATE POLICY tasks_select_own ON public.tasks
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = owner_id);

DROP POLICY IF EXISTS tasks_insert_own ON public.tasks;
CREATE POLICY tasks_insert_own ON public.tasks
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = owner_id);

DROP POLICY IF EXISTS tasks_update_own ON public.tasks;
CREATE POLICY tasks_update_own ON public.tasks
  FOR UPDATE TO authenticated
  USING  ((SELECT auth.uid()) = owner_id)
  WITH CHECK ((SELECT auth.uid()) = owner_id);

DROP POLICY IF EXISTS tasks_delete_own ON public.tasks;
CREATE POLICY tasks_delete_own ON public.tasks
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = owner_id);

EOSQL

echo "[db-setup] ✅ Public schema created successfully."
