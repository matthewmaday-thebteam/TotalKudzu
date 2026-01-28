-- =============================================================================
-- TotalKudzu V1 Schema - Migration 0007: Timesheets
-- =============================================================================
-- Timesheet periods, submissions, and approvals
-- =============================================================================

-- =============================================================================
-- TABLES (created first, RLS added after all tables exist)
-- =============================================================================

-- TIMESHEET_PERIOD
CREATE TABLE public.timesheet_period (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES public.company(id),
    period_type text NOT NULL CHECK (period_type IN ('weekly', 'monthly')),
    start_date date NOT NULL,
    end_date date NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES auth.users(id),

    CONSTRAINT chk_timesheet_period_dates CHECK (end_date >= start_date)
);

CREATE INDEX idx_timesheet_period_company_id ON public.timesheet_period(company_id);
CREATE INDEX idx_timesheet_period_dates ON public.timesheet_period(start_date, end_date);

CREATE UNIQUE INDEX idx_timesheet_period_unique
    ON public.timesheet_period(company_id, period_type, start_date)
    WHERE deleted_at IS NULL;

-- TIMESHEET_SUBMISSION
CREATE TABLE public.timesheet_submission (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES public.company(id),
    member_id uuid NOT NULL REFERENCES public.company_member(id),
    timesheet_period_id uuid NOT NULL REFERENCES public.timesheet_period(id),
    status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'submitted', 'approved', 'rejected', 'needs_reapproval')),
    submitted_at timestamptz,
    approved_at timestamptz,
    approved_by_member_id uuid REFERENCES public.company_member(id),
    approved_snapshot_hash text,
    approved_total_minutes int,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES auth.users(id)
);

CREATE INDEX idx_timesheet_submission_company_id ON public.timesheet_submission(company_id);
CREATE INDEX idx_timesheet_submission_member_id ON public.timesheet_submission(member_id);
CREATE INDEX idx_timesheet_submission_period_id ON public.timesheet_submission(timesheet_period_id);
CREATE INDEX idx_timesheet_submission_status ON public.timesheet_submission(status);

CREATE UNIQUE INDEX idx_timesheet_submission_unique
    ON public.timesheet_submission(member_id, timesheet_period_id)
    WHERE deleted_at IS NULL;

-- TIMESHEET_APPROVAL
CREATE TABLE public.timesheet_approval (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    timesheet_submission_id uuid NOT NULL REFERENCES public.timesheet_submission(id) ON DELETE CASCADE,
    approver_member_id uuid NOT NULL REFERENCES public.company_member(id),
    decision text NOT NULL DEFAULT 'pending' CHECK (decision IN ('pending', 'approved', 'rejected')),
    decided_at timestamptz,
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_timesheet_approval_submission_id ON public.timesheet_approval(timesheet_submission_id);
CREATE INDEX idx_timesheet_approval_approver_id ON public.timesheet_approval(approver_member_id);

-- =============================================================================
-- RLS POLICIES (created after all tables exist)
-- =============================================================================

-- TIMESHEET_PERIOD RLS
ALTER TABLE public.timesheet_period ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view company timesheet_period"
    ON public.timesheet_period FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = timesheet_period.company_id
              AND cm.deleted_at IS NULL
        )
        AND deleted_at IS NULL
    );

CREATE POLICY "Admins can insert timesheet_period"
    ON public.timesheet_period FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = timesheet_period.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

CREATE POLICY "Admins can update timesheet_period"
    ON public.timesheet_period FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = timesheet_period.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

-- TIMESHEET_SUBMISSION RLS
ALTER TABLE public.timesheet_submission ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view own timesheet_submission"
    ON public.timesheet_submission FOR SELECT
    USING (
        member_id = public.current_member_id()
        AND deleted_at IS NULL
    );

CREATE POLICY "Approvers can view timesheet_submission"
    ON public.timesheet_submission FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.timesheet_approval ta
            WHERE ta.timesheet_submission_id = timesheet_submission.id
              AND ta.approver_member_id = public.current_member_id()
        )
        AND deleted_at IS NULL
    );

CREATE POLICY "Admins can view company timesheet_submission"
    ON public.timesheet_submission FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = timesheet_submission.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
        AND deleted_at IS NULL
    );

CREATE POLICY "Members can insert own timesheet_submission"
    ON public.timesheet_submission FOR INSERT
    WITH CHECK (
        member_id = public.current_member_id()
        AND company_id = public.current_company_id()
    );

CREATE POLICY "Members can update own timesheet_submission"
    ON public.timesheet_submission FOR UPDATE
    USING (member_id = public.current_member_id());

CREATE POLICY "Approvers can update timesheet_submission"
    ON public.timesheet_submission FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.timesheet_approval ta
            WHERE ta.timesheet_submission_id = timesheet_submission.id
              AND ta.approver_member_id = public.current_member_id()
        )
    );

-- TIMESHEET_APPROVAL RLS
ALTER TABLE public.timesheet_approval ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Submitter can view timesheet_approval"
    ON public.timesheet_approval FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.timesheet_submission ts
            WHERE ts.id = timesheet_approval.timesheet_submission_id
              AND ts.member_id = public.current_member_id()
        )
    );

CREATE POLICY "Approver can view timesheet_approval"
    ON public.timesheet_approval FOR SELECT
    USING (approver_member_id = public.current_member_id());

CREATE POLICY "Admins can view timesheet_approval"
    ON public.timesheet_approval FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.timesheet_submission ts
            JOIN public.company_member cm ON cm.company_id = ts.company_id
            WHERE ts.id = timesheet_approval.timesheet_submission_id
              AND cm.user_id = auth.uid()
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

CREATE POLICY "System can insert timesheet_approval"
    ON public.timesheet_approval FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Approver can update timesheet_approval"
    ON public.timesheet_approval FOR UPDATE
    USING (
        approver_member_id = public.current_member_id()
        AND decision = 'pending'
    );

-- =============================================================================
-- GRANTS
-- =============================================================================

GRANT SELECT, INSERT, UPDATE ON public.timesheet_period TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.timesheet_submission TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.timesheet_approval TO authenticated;
