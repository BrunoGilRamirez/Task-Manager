-- =============================================================================
-- Task Manager – Public Schema Initialization
--
-- Este script se ejecuta una sola vez cuando el contenedor de PostgreSQL
-- arranca por primera vez (docker-entrypoint-initdb.d).
--
-- El script 00-init.sh (ejecutado antes) ya creó:
--   • Los roles: anon, authenticated, service_role, authenticator
--   • El schema auth con las funciones auth.uid(), auth.role()
--
-- Este script crea:
--   • auth.users con TODAS las columnas de la migración inicial de GoTrue
--     (GoTrue la omite con IF NOT EXISTS y sólo añade lo que falte)
--   • Las tablas del dominio público y las políticas RLS.
-- =============================================================================

-- ── auth.users ── estructura completa de la migración 00 de GoTrue ──────────
-- GoTrue usa IF NOT EXISTS, así que si encuentra esta tabla la salta y
-- continúa añadiendo columnas y constraints de migraciones posteriores.
CREATE TABLE IF NOT EXISTS auth.users (
  instance_id          uuid         NULL,
  id                   uuid         NOT NULL UNIQUE,
  aud                  varchar(255) NULL,
  "role"               varchar(255) NULL,
  email                varchar(255) NULL UNIQUE,
  encrypted_password   varchar(255) NULL,
  confirmed_at         timestamptz  NULL,
  invited_at           timestamptz  NULL,
  confirmation_token   varchar(255) NULL,
  confirmation_sent_at timestamptz  NULL,
  recovery_token       varchar(255) NULL,
  recovery_sent_at     timestamptz  NULL,
  email_change_token   varchar(255) NULL,
  email_change         varchar(255) NULL,
  email_change_sent_at timestamptz  NULL,
  last_sign_in_at      timestamptz  NULL,
  raw_app_meta_data    jsonb        NULL,
  raw_user_meta_data   jsonb        NULL,
  is_super_admin       bool         NULL,
  created_at           timestamptz  NULL,
  updated_at           timestamptz  NULL,
  CONSTRAINT users_pkey PRIMARY KEY (id)
);
ALTER TABLE auth.users OWNER TO supabase_auth_admin;
COMMENT ON TABLE auth.users IS 'Auth: Stores user login data within a secure schema.';

CREATE INDEX IF NOT EXISTS users_instance_id_email_idx ON auth.users USING btree (instance_id, email);
CREATE INDEX IF NOT EXISTS users_instance_id_idx       ON auth.users USING btree (instance_id);

-- Asegurar que estamos en el schema public
SET search_path TO public;

-- =============================================================================
-- Función helper: actualizar updated_at automáticamente
-- =============================================================================
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Tabla: public.users
-- Perfil de usuario vinculado a auth.users (1-a-1)
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.users (
  id   uuid NOT NULL,
  name text NOT NULL,
  CONSTRAINT users_pkey PRIMARY KEY (id),
  CONSTRAINT users_id_fkey FOREIGN KEY (id)
    REFERENCES auth.users (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- =============================================================================
-- Tabla: public.tasks
-- Tareas pertenecientes a un usuario
-- =============================================================================
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

-- Trigger: mantener updated_at actualizado
CREATE TRIGGER update_tasks_updated_at
  BEFORE UPDATE ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- =============================================================================
-- Row Level Security (RLS)
-- Cada usuario solo puede ver y modificar sus propios datos.
-- =============================================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- ── Políticas para public.users ──────────────────────────────────────────────

CREATE POLICY users_select_own ON public.users
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = id);

CREATE POLICY users_insert_own ON public.users
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = id);

CREATE POLICY users_update_own ON public.users
  FOR UPDATE TO authenticated
  USING  ((SELECT auth.uid()) = id)
  WITH CHECK ((SELECT auth.uid()) = id);

CREATE POLICY users_delete_own ON public.users
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = id);

-- ── Políticas para public.tasks ───────────────────────────────────────────────

CREATE POLICY tasks_select_own ON public.tasks
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = owner_id);

CREATE POLICY tasks_insert_own ON public.tasks
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = owner_id);

CREATE POLICY tasks_update_own ON public.tasks
  FOR UPDATE TO authenticated
  USING  ((SELECT auth.uid()) = owner_id)
  WITH CHECK ((SELECT auth.uid()) = owner_id);

CREATE POLICY tasks_delete_own ON public.tasks
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = owner_id);
