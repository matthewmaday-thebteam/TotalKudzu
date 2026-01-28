-- =============================================================================
-- TotalKudzu V1 Schema - Migration 0006: Time Tracking
-- =============================================================================
-- Projects, tasks, time entries, and timer sessions
-- =============================================================================

-- =============================================================================
-- PROJECT (Department-scoped)
-- =============================================================================

CREATE TABLE public.project (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES public.company(id),
    department_id uuid NOT NULL REFERENCES public.department(id),
    name text NOT NULL,
    description text,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES auth.users(id)
);

CREATE INDEX idx_project_company_id ON public.project(company_id);
CREATE INDEX idx_project_department_id ON public.project(department_id);
CREATE UNIQUE INDEX idx_project_name_unique
    ON public.project(department_id, name)
    WHERE deleted_at IS NULL;

ALTER TABLE public.project ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view company project"
    ON public.project FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = project.company_id
              AND cm.deleted_at IS NULL
        )
        AND deleted_at IS NULL
    );

CREATE POLICY "Admins can insert project"
    ON public.project FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = project.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

CREATE POLICY "Admins can update project"
    ON public.project FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = project.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

-- =============================================================================
-- TASK
-- =============================================================================

CREATE TABLE public.task (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id uuid NOT NULL REFERENCES public.project(id),
    name text NOT NULL,
    description text,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES auth.users(id)
);

CREATE INDEX idx_task_project_id ON public.task(project_id);
CREATE UNIQUE INDEX idx_task_name_unique
    ON public.task(project_id, name)
    WHERE deleted_at IS NULL;

ALTER TABLE public.task ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view company task"
    ON public.task FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.project p
            JOIN public.company_member cm ON cm.company_id = p.company_id
            WHERE p.id = task.project_id
              AND cm.user_id = auth.uid()
              AND cm.deleted_at IS NULL
        )
        AND deleted_at IS NULL
    );

CREATE POLICY "Admins can insert task"
    ON public.task FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.project p
            JOIN public.company_member cm ON cm.company_id = p.company_id
            WHERE p.id = task.project_id
              AND cm.user_id = auth.uid()
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

CREATE POLICY "Admins can update task"
    ON public.task FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.project p
            JOIN public.company_member cm ON cm.company_id = p.company_id
            WHERE p.id = task.project_id
              AND cm.user_id = auth.uid()
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

-- =============================================================================
-- TIME_ENTRY
-- =============================================================================

CREATE TABLE public.time_entry (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES public.company(id),
    member_id uuid NOT NULL REFERENCES public.company_member(id),
    office_id uuid NOT NULL REFERENCES public.office(id), -- Timezone context
    project_id uuid NOT NULL REFERENCES public.project(id),
    task_id uuid REFERENCES public.task(id),
    work_date date NOT NULL, -- Business day in office timezone
    start_time_utc timestamptz NOT NULL,
    end_time_utc timestamptz NOT NULL,
    duration_minutes int NOT NULL, -- Computed: (end - start) in minutes
    description text,
    billable boolean NOT NULL DEFAULT false,
    status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'submitted', 'approved', 'rejected')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES auth.users(id),

    CONSTRAINT chk_time_entry_times CHECK (end_time_utc > start_time_utc)
);

CREATE INDEX idx_time_entry_company_id ON public.time_entry(company_id);
CREATE INDEX idx_time_entry_member_id ON public.time_entry(member_id);
CREATE INDEX idx_time_entry_project_id ON public.time_entry(project_id);
CREATE INDEX idx_time_entry_work_date ON public.time_entry(work_date);
CREATE INDEX idx_time_entry_member_date ON public.time_entry(member_id, work_date);

ALTER TABLE public.time_entry ENABLE ROW LEVEL SECURITY;

-- Members can view their own entries
CREATE POLICY "Members can view own time_entry"
    ON public.time_entry FOR SELECT
    USING (
        member_id = public.current_member_id()
        AND deleted_at IS NULL
    );

-- Admins can view company entries
CREATE POLICY "Admins can view company time_entry"
    ON public.time_entry FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = time_entry.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
        AND deleted_at IS NULL
    );

-- Members can insert entries for projects in their departments
CREATE POLICY "Members can insert own time_entry"
    ON public.time_entry FOR INSERT
    WITH CHECK (
        member_id = public.current_member_id()
        AND company_id = public.current_company_id()
        -- Must be member of project's department
        AND EXISTS (
            SELECT 1 FROM public.project p
            JOIN public.member_department md ON md.department_id = p.department_id
            WHERE p.id = time_entry.project_id
              AND md.member_id = public.current_member_id()
              AND md.deleted_at IS NULL
        )
    );

-- Members can update their own entries
CREATE POLICY "Members can update own time_entry"
    ON public.time_entry FOR UPDATE
    USING (
        member_id = public.current_member_id()
    );

-- =============================================================================
-- TIMER_SESSION
-- =============================================================================

CREATE TABLE public.timer_session (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES public.company(id),
    member_id uuid NOT NULL REFERENCES public.company_member(id),
    office_id uuid NOT NULL REFERENCES public.office(id),
    project_id uuid NOT NULL REFERENCES public.project(id),
    task_id uuid REFERENCES public.task(id),
    work_date date NOT NULL, -- Business day in office timezone
    started_at_utc timestamptz NOT NULL,
    stopped_at_utc timestamptz,
    is_running boolean NOT NULL DEFAULT true,
    description text,
    billable boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES auth.users(id)
);

CREATE INDEX idx_timer_session_member_id ON public.timer_session(member_id);
CREATE INDEX idx_timer_session_is_running ON public.timer_session(is_running);

-- Only one running timer per member
CREATE UNIQUE INDEX idx_timer_session_one_running
    ON public.timer_session(member_id)
    WHERE is_running = true AND deleted_at IS NULL;

ALTER TABLE public.timer_session ENABLE ROW LEVEL SECURITY;

-- Members can view their own timer sessions
CREATE POLICY "Members can view own timer_session"
    ON public.timer_session FOR SELECT
    USING (
        member_id = public.current_member_id()
        AND deleted_at IS NULL
    );

-- Members can insert their own timer sessions
CREATE POLICY "Members can insert own timer_session"
    ON public.timer_session FOR INSERT
    WITH CHECK (
        member_id = public.current_member_id()
        AND company_id = public.current_company_id()
        -- Must be member of project's department
        AND EXISTS (
            SELECT 1 FROM public.project p
            JOIN public.member_department md ON md.department_id = p.department_id
            WHERE p.id = timer_session.project_id
              AND md.member_id = public.current_member_id()
              AND md.deleted_at IS NULL
        )
    );

-- Members can update their own timer sessions
CREATE POLICY "Members can update own timer_session"
    ON public.timer_session FOR UPDATE
    USING (member_id = public.current_member_id());

-- Members can delete their own timer sessions
CREATE POLICY "Members can delete own timer_session"
    ON public.timer_session FOR DELETE
    USING (member_id = public.current_member_id());

-- =============================================================================
-- GRANTS
-- =============================================================================

GRANT SELECT, INSERT, UPDATE ON public.project TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.task TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.time_entry TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.timer_session TO authenticated;
