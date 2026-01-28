-- =============================================================================
-- TotalKudzu V1 Schema - Migration 0002: Organization Structure
-- =============================================================================
-- Offices, departments, join tables, and work schedules
-- =============================================================================

-- =============================================================================
-- OFFICE
-- =============================================================================

CREATE TABLE public.office (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES public.company(id),
    name text NOT NULL,
    timezone text NOT NULL, -- IANA timezone (e.g., 'America/New_York')
    country_code text NOT NULL, -- ISO 3166-1 alpha-2 (e.g., 'US', 'BG')
    address text,
    default_work_schedule_id uuid, -- FK added below after work_schedule table
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES auth.users(id)
);

CREATE INDEX idx_office_company_id ON public.office(company_id);
CREATE UNIQUE INDEX idx_office_name_unique
    ON public.office(company_id, name)
    WHERE deleted_at IS NULL;

ALTER TABLE public.office ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view company offices"
    ON public.office FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = office.company_id
              AND cm.deleted_at IS NULL
        )
        AND deleted_at IS NULL
    );

CREATE POLICY "Admins can insert offices"
    ON public.office FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = office.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

CREATE POLICY "Admins can update offices"
    ON public.office FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = office.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

-- =============================================================================
-- DEPARTMENT
-- =============================================================================

CREATE TABLE public.department (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES public.company(id),
    name text NOT NULL,
    lead_member_id uuid REFERENCES public.company_member(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES auth.users(id)
);

CREATE INDEX idx_department_company_id ON public.department(company_id);
CREATE UNIQUE INDEX idx_department_name_unique
    ON public.department(company_id, name)
    WHERE deleted_at IS NULL;

ALTER TABLE public.department ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view company departments"
    ON public.department FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = department.company_id
              AND cm.deleted_at IS NULL
        )
        AND deleted_at IS NULL
    );

CREATE POLICY "Admins can insert departments"
    ON public.department FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = department.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

CREATE POLICY "Admins can update departments"
    ON public.department FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = department.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

-- =============================================================================
-- MEMBER_OFFICE (Join Table - Many-to-Many)
-- =============================================================================

CREATE TABLE public.member_office (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id uuid NOT NULL REFERENCES public.company_member(id),
    office_id uuid NOT NULL REFERENCES public.office(id),
    is_primary boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES auth.users(id)
);

-- Unique member-office combination (when not deleted)
CREATE UNIQUE INDEX idx_member_office_unique
    ON public.member_office(member_id, office_id)
    WHERE deleted_at IS NULL;

-- Only one primary office per member
CREATE UNIQUE INDEX idx_member_office_primary_unique
    ON public.member_office(member_id)
    WHERE is_primary = true AND deleted_at IS NULL;

CREATE INDEX idx_member_office_member_id ON public.member_office(member_id);
CREATE INDEX idx_member_office_office_id ON public.member_office(office_id);

ALTER TABLE public.member_office ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view company member_office"
    ON public.member_office FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            JOIN public.company_member target ON target.id = member_office.member_id
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = target.company_id
              AND cm.deleted_at IS NULL
        )
        AND deleted_at IS NULL
    );

CREATE POLICY "Admins can insert member_office"
    ON public.member_office FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            JOIN public.company_member target ON target.id = member_office.member_id
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = target.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

CREATE POLICY "Admins can update member_office"
    ON public.member_office FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            JOIN public.company_member target ON target.id = member_office.member_id
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = target.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

-- =============================================================================
-- MEMBER_DEPARTMENT (Join Table - Many-to-Many)
-- =============================================================================

CREATE TABLE public.member_department (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id uuid NOT NULL REFERENCES public.company_member(id),
    department_id uuid NOT NULL REFERENCES public.department(id),
    is_primary boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES auth.users(id)
);

-- Unique member-department combination (when not deleted)
CREATE UNIQUE INDEX idx_member_department_unique
    ON public.member_department(member_id, department_id)
    WHERE deleted_at IS NULL;

-- Only one primary department per member (required for approval inheritance)
CREATE UNIQUE INDEX idx_member_department_primary_unique
    ON public.member_department(member_id)
    WHERE is_primary = true AND deleted_at IS NULL;

CREATE INDEX idx_member_department_member_id ON public.member_department(member_id);
CREATE INDEX idx_member_department_department_id ON public.member_department(department_id);

ALTER TABLE public.member_department ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view company member_department"
    ON public.member_department FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            JOIN public.company_member target ON target.id = member_department.member_id
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = target.company_id
              AND cm.deleted_at IS NULL
        )
        AND deleted_at IS NULL
    );

CREATE POLICY "Admins can insert member_department"
    ON public.member_department FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            JOIN public.company_member target ON target.id = member_department.member_id
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = target.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

CREATE POLICY "Admins can update member_department"
    ON public.member_department FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            JOIN public.company_member target ON target.id = member_department.member_id
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = target.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

-- =============================================================================
-- HELPER FUNCTIONS: Primary Department/Office
-- =============================================================================

-- Get primary department ID for a member (from join table only)
CREATE OR REPLACE FUNCTION public.primary_department_id(p_member_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT department_id
    FROM public.member_department
    WHERE member_id = p_member_id
      AND is_primary = true
      AND deleted_at IS NULL
    LIMIT 1;
$$;

-- Get primary office ID for a member (from join table)
CREATE OR REPLACE FUNCTION public.primary_office_id_from_join(p_member_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT office_id
    FROM public.member_office
    WHERE member_id = p_member_id
      AND is_primary = true
      AND deleted_at IS NULL
    LIMIT 1;
$$;

-- =============================================================================
-- WORK_SCHEDULE
-- =============================================================================

CREATE TABLE public.work_schedule (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES public.company(id),
    office_id uuid REFERENCES public.office(id), -- NULL = company-wide schedule
    name text NOT NULL,
    mon_minutes int NOT NULL DEFAULT 480, -- 8 hours
    tue_minutes int NOT NULL DEFAULT 480,
    wed_minutes int NOT NULL DEFAULT 480,
    thu_minutes int NOT NULL DEFAULT 480,
    fri_minutes int NOT NULL DEFAULT 480,
    sat_minutes int NOT NULL DEFAULT 0,
    sun_minutes int NOT NULL DEFAULT 0,
    is_default boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES auth.users(id)
);

CREATE INDEX idx_work_schedule_company_id ON public.work_schedule(company_id);
CREATE INDEX idx_work_schedule_office_id ON public.work_schedule(office_id);

-- Only one default schedule per company (when not deleted)
CREATE UNIQUE INDEX idx_work_schedule_default_unique
    ON public.work_schedule(company_id)
    WHERE is_default = true AND deleted_at IS NULL;

ALTER TABLE public.work_schedule ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view company work_schedule"
    ON public.work_schedule FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = work_schedule.company_id
              AND cm.deleted_at IS NULL
        )
        AND deleted_at IS NULL
    );

CREATE POLICY "Admins can insert work_schedule"
    ON public.work_schedule FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = work_schedule.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

CREATE POLICY "Admins can update work_schedule"
    ON public.work_schedule FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = work_schedule.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

-- =============================================================================
-- ADD DEFERRED FOREIGN KEYS
-- =============================================================================

-- company_member.primary_office_id -> office
ALTER TABLE public.company_member
    ADD CONSTRAINT fk_company_member_primary_office
    FOREIGN KEY (primary_office_id) REFERENCES public.office(id);

-- company_member.work_schedule_id -> work_schedule
ALTER TABLE public.company_member
    ADD CONSTRAINT fk_company_member_work_schedule
    FOREIGN KEY (work_schedule_id) REFERENCES public.work_schedule(id);

-- office.default_work_schedule_id -> work_schedule
ALTER TABLE public.office
    ADD CONSTRAINT fk_office_default_work_schedule
    FOREIGN KEY (default_work_schedule_id) REFERENCES public.work_schedule(id);

-- =============================================================================
-- GRANTS
-- =============================================================================

GRANT SELECT, INSERT, UPDATE ON public.office TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.department TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.member_office TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.member_department TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.work_schedule TO authenticated;

GRANT EXECUTE ON FUNCTION public.primary_department_id(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.primary_office_id_from_join(uuid) TO authenticated;
