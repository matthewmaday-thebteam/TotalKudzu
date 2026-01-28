-- =============================================================================
-- TotalKudzu V1 Schema - Migration 0001: Init
-- =============================================================================
-- Extensions, base tables, helper functions, and RLS policies
-- =============================================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

-- =============================================================================
-- BASE TABLES (no RLS yet - policies added after all tables exist)
-- =============================================================================

-- Profile (extends auth.users)
CREATE TABLE public.profile (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name text,
    avatar_url text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Company
CREATE TABLE public.company (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended')),
    settings jsonb NOT NULL DEFAULT '{}',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES auth.users(id)
);

-- Company Member
CREATE TABLE public.company_member (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES public.company(id),
    user_id uuid NOT NULL REFERENCES auth.users(id),
    role text NOT NULL CHECK (role IN ('admin', 'manager', 'employee')),
    manager_member_id uuid REFERENCES public.company_member(id),
    primary_office_id uuid, -- FK added in 0002_org.sql (deferred)
    work_schedule_id uuid,  -- FK added in 0002_org.sql (deferred)
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('invited', 'active', 'disabled')),
    employment_start_date date,
    employment_end_date date,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES auth.users(id)
);

-- V1: One user belongs to one company (active membership)
CREATE UNIQUE INDEX idx_company_member_user_active
    ON public.company_member(user_id)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_company_member_company_id ON public.company_member(company_id);
CREATE INDEX idx_company_member_manager ON public.company_member(manager_member_id);
CREATE INDEX idx_company_member_user_id ON public.company_member(user_id);

-- =============================================================================
-- HELPER FUNCTIONS (created after tables they reference)
-- =============================================================================

-- Returns the current authenticated user's auth.uid()
CREATE OR REPLACE FUNCTION public.current_user_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT auth.uid();
$$;

-- Returns the company_member.id for the current authenticated user
-- V1: single membership per user
CREATE OR REPLACE FUNCTION public.current_member_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT id
    FROM public.company_member
    WHERE user_id = auth.uid()
      AND deleted_at IS NULL
    LIMIT 1;
$$;

-- Returns the company_id for the current authenticated user
CREATE OR REPLACE FUNCTION public.current_company_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT company_id
    FROM public.company_member
    WHERE user_id = auth.uid()
      AND deleted_at IS NULL
    LIMIT 1;
$$;

-- Returns true if the current user is an admin in their company
CREATE OR REPLACE FUNCTION public.is_company_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.company_member
        WHERE user_id = auth.uid()
          AND role = 'admin'
          AND deleted_at IS NULL
    );
$$;

-- Returns true if the current user is a manager in their company
CREATE OR REPLACE FUNCTION public.is_company_manager()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.company_member
        WHERE user_id = auth.uid()
          AND role = 'manager'
          AND deleted_at IS NULL
    );
$$;

-- =============================================================================
-- RLS POLICIES (created after tables and functions exist)
-- =============================================================================

-- Profile RLS
ALTER TABLE public.profile ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own profile"
    ON public.profile FOR SELECT
    USING (id = auth.uid());

CREATE POLICY "Users can update their own profile"
    ON public.profile FOR UPDATE
    USING (id = auth.uid());

CREATE POLICY "Users can insert their own profile"
    ON public.profile FOR INSERT
    WITH CHECK (id = auth.uid());

-- Company RLS
ALTER TABLE public.company ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view their company"
    ON public.company FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = company.id
              AND cm.deleted_at IS NULL
        )
    );

CREATE POLICY "Admins can update their company"
    ON public.company FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = company.id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

-- Company Member RLS
ALTER TABLE public.company_member ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view their own membership"
    ON public.company_member FOR SELECT
    USING (user_id = auth.uid() AND deleted_at IS NULL);

CREATE POLICY "Members can view company members"
    ON public.company_member FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = company_member.company_id
              AND cm.deleted_at IS NULL
        )
        AND deleted_at IS NULL
    );

CREATE POLICY "Admins can insert members"
    ON public.company_member FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = company_member.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

CREATE POLICY "Admins can update members"
    ON public.company_member FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = company_member.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.profile TO authenticated;
GRANT SELECT, UPDATE ON public.company TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.company_member TO authenticated;

GRANT EXECUTE ON FUNCTION public.current_user_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_member_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_company_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_company_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_company_manager() TO authenticated;
