-- =============================================================================
-- TotalKudzu V1 Schema - Migration 0005: Leave
-- =============================================================================
-- Leave types, policies, requests, approvals, ledger, and balance snapshots
-- =============================================================================

-- =============================================================================
-- TABLES (created first, RLS added after all tables exist)
-- =============================================================================

-- LEAVE_TYPE
CREATE TABLE public.leave_type (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES public.company(id),
    name text NOT NULL,
    is_paid boolean NOT NULL DEFAULT true,
    requires_approval boolean NOT NULL DEFAULT true,
    unit_display text NOT NULL DEFAULT 'days' CHECK (unit_display IN ('hours', 'days')),
    color text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES auth.users(id)
);

CREATE INDEX idx_leave_type_company_id ON public.leave_type(company_id);
CREATE UNIQUE INDEX idx_leave_type_name_unique
    ON public.leave_type(company_id, name)
    WHERE deleted_at IS NULL;

-- LEAVE_POLICY (1:1 with leave_type)
CREATE TABLE public.leave_policy (
    leave_type_id uuid PRIMARY KEY REFERENCES public.leave_type(id) ON DELETE CASCADE,
    accrual_enabled boolean NOT NULL DEFAULT false,
    accrual_rate_minutes_per_day int NOT NULL DEFAULT 0,
    accrual_basis text NOT NULL DEFAULT 'working_days' CHECK (accrual_basis IN ('calendar_days', 'working_days')),
    annual_reset_month int NOT NULL DEFAULT 1 CHECK (annual_reset_month BETWEEN 1 AND 12),
    annual_reset_day int NOT NULL DEFAULT 1 CHECK (annual_reset_day BETWEEN 1 AND 31),
    carryover_enabled boolean NOT NULL DEFAULT false,
    carryover_cap_minutes int,
    carryover_expiry_enabled boolean NOT NULL DEFAULT false,
    carryover_expiry_month int CHECK (carryover_expiry_month BETWEEN 1 AND 12),
    carryover_expiry_day int CHECK (carryover_expiry_day BETWEEN 1 AND 31),
    attachment_required_rule text NOT NULL DEFAULT 'never' CHECK (attachment_required_rule IN ('never', 'always', 'threshold')),
    attachment_threshold_minutes int,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- LEAVE_REQUEST
CREATE TABLE public.leave_request (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES public.company(id),
    member_id uuid NOT NULL REFERENCES public.company_member(id),
    leave_type_id uuid NOT NULL REFERENCES public.leave_type(id),
    department_id uuid NOT NULL REFERENCES public.department(id),
    office_id uuid NOT NULL REFERENCES public.office(id),
    request_date date NOT NULL,
    requested_minutes int NOT NULL,
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
    comment text,
    batch_id uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES auth.users(id)
);

CREATE INDEX idx_leave_request_company_id ON public.leave_request(company_id);
CREATE INDEX idx_leave_request_member_id ON public.leave_request(member_id);
CREATE INDEX idx_leave_request_leave_type_id ON public.leave_request(leave_type_id);
CREATE INDEX idx_leave_request_date ON public.leave_request(request_date);
CREATE INDEX idx_leave_request_batch_id ON public.leave_request(batch_id);
CREATE INDEX idx_leave_request_status ON public.leave_request(status);

CREATE UNIQUE INDEX idx_leave_request_unique
    ON public.leave_request(member_id, leave_type_id, request_date)
    WHERE deleted_at IS NULL AND status != 'cancelled';

-- LEAVE_REQUEST_SEGMENT
CREATE TABLE public.leave_request_segment (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    leave_request_id uuid NOT NULL REFERENCES public.leave_request(id) ON DELETE CASCADE,
    start_time_local time,
    end_time_local time,
    minutes int NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_leave_request_segment_request_id ON public.leave_request_segment(leave_request_id);

-- LEAVE_REQUEST_APPROVAL
CREATE TABLE public.leave_request_approval (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    leave_request_id uuid NOT NULL REFERENCES public.leave_request(id) ON DELETE CASCADE,
    approver_member_id uuid NOT NULL REFERENCES public.company_member(id),
    decision text NOT NULL DEFAULT 'pending' CHECK (decision IN ('pending', 'approved', 'rejected')),
    decided_at timestamptz,
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES auth.users(id)
);

CREATE INDEX idx_leave_request_approval_request_id ON public.leave_request_approval(leave_request_id);
CREATE INDEX idx_leave_request_approval_approver_id ON public.leave_request_approval(approver_member_id);

CREATE UNIQUE INDEX idx_leave_request_approval_unique
    ON public.leave_request_approval(leave_request_id)
    WHERE deleted_at IS NULL;

-- LEAVE_REQUEST_ATTACHMENT
CREATE TABLE public.leave_request_attachment (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    leave_request_id uuid NOT NULL REFERENCES public.leave_request(id) ON DELETE CASCADE,
    uploaded_by_member_id uuid NOT NULL REFERENCES public.company_member(id),
    file_name text NOT NULL,
    mime_type text NOT NULL CHECK (mime_type IN ('application/pdf', 'image/jpeg', 'image/png')),
    storage_key text NOT NULL,
    file_size_bytes int,
    created_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES auth.users(id)
);

CREATE INDEX idx_leave_request_attachment_request_id ON public.leave_request_attachment(leave_request_id);

-- LEAVE_LEDGER (Immutable)
CREATE TABLE public.leave_ledger (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES public.company(id),
    member_id uuid NOT NULL REFERENCES public.company_member(id),
    leave_type_id uuid NOT NULL REFERENCES public.leave_type(id),
    policy_year int NOT NULL,
    transaction_type text NOT NULL CHECK (transaction_type IN ('accrual', 'usage', 'adjustment', 'carryover', 'expiry', 'reversal')),
    minutes int NOT NULL,
    effective_date date NOT NULL,
    reference_id uuid,
    note text,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_leave_ledger_member_type_year ON public.leave_ledger(member_id, leave_type_id, policy_year);
CREATE INDEX idx_leave_ledger_company_id ON public.leave_ledger(company_id);
CREATE INDEX idx_leave_ledger_effective_date ON public.leave_ledger(effective_date);

-- LEAVE_BALANCE_SNAPSHOT
CREATE TABLE public.leave_balance_snapshot (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES public.company(id),
    member_id uuid NOT NULL REFERENCES public.company_member(id),
    leave_type_id uuid NOT NULL REFERENCES public.leave_type(id),
    policy_year int NOT NULL,
    available_minutes int NOT NULL DEFAULT 0,
    pending_minutes int NOT NULL DEFAULT 0,
    used_minutes int NOT NULL DEFAULT 0,
    last_calculated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_leave_balance_snapshot_unique
    ON public.leave_balance_snapshot(member_id, leave_type_id, policy_year);
CREATE INDEX idx_leave_balance_snapshot_company_id ON public.leave_balance_snapshot(company_id);

-- =============================================================================
-- RLS POLICIES (created after all tables exist)
-- =============================================================================

-- LEAVE_TYPE RLS
ALTER TABLE public.leave_type ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view company leave_type"
    ON public.leave_type FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = leave_type.company_id
              AND cm.deleted_at IS NULL
        )
        AND deleted_at IS NULL
    );

CREATE POLICY "Admins can insert leave_type"
    ON public.leave_type FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = leave_type.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

CREATE POLICY "Admins can update leave_type"
    ON public.leave_type FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = leave_type.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

-- LEAVE_POLICY RLS
ALTER TABLE public.leave_policy ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view leave_policy"
    ON public.leave_policy FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            JOIN public.leave_type lt ON lt.id = leave_policy.leave_type_id
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = lt.company_id
              AND cm.deleted_at IS NULL
        )
    );

CREATE POLICY "Admins can insert leave_policy"
    ON public.leave_policy FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            JOIN public.leave_type lt ON lt.id = leave_policy.leave_type_id
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = lt.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

CREATE POLICY "Admins can update leave_policy"
    ON public.leave_policy FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            JOIN public.leave_type lt ON lt.id = leave_policy.leave_type_id
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = lt.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

-- LEAVE_REQUEST RLS
ALTER TABLE public.leave_request ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view own leave_request"
    ON public.leave_request FOR SELECT
    USING (
        member_id = public.current_member_id()
        AND deleted_at IS NULL
    );

CREATE POLICY "Approvers can view leave_request"
    ON public.leave_request FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.leave_request_approval lra
            WHERE lra.leave_request_id = leave_request.id
              AND lra.approver_member_id = public.current_member_id()
        )
        AND deleted_at IS NULL
    );

CREATE POLICY "Admins can view company leave_request"
    ON public.leave_request FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = leave_request.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
        AND deleted_at IS NULL
    );

CREATE POLICY "Members can insert own leave_request"
    ON public.leave_request FOR INSERT
    WITH CHECK (
        member_id = public.current_member_id()
        AND company_id = public.current_company_id()
    );

CREATE POLICY "Members can update own pending leave_request"
    ON public.leave_request FOR UPDATE
    USING (
        member_id = public.current_member_id()
        AND status = 'pending'
    );

-- LEAVE_REQUEST_SEGMENT RLS
ALTER TABLE public.leave_request_segment ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view leave_request_segment"
    ON public.leave_request_segment FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.leave_request lr
            WHERE lr.id = leave_request_segment.leave_request_id
              AND (
                  lr.member_id = public.current_member_id()
                  OR EXISTS (
                      SELECT 1 FROM public.company_member cm
                      WHERE cm.user_id = auth.uid()
                        AND cm.company_id = lr.company_id
                        AND cm.role = 'admin'
                        AND cm.deleted_at IS NULL
                  )
              )
        )
    );

CREATE POLICY "Members can insert leave_request_segment"
    ON public.leave_request_segment FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.leave_request lr
            WHERE lr.id = leave_request_segment.leave_request_id
              AND lr.member_id = public.current_member_id()
              AND lr.status = 'pending'
        )
    );

CREATE POLICY "Members can update leave_request_segment"
    ON public.leave_request_segment FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.leave_request lr
            WHERE lr.id = leave_request_segment.leave_request_id
              AND lr.member_id = public.current_member_id()
              AND lr.status = 'pending'
        )
    );

-- LEAVE_REQUEST_APPROVAL RLS
ALTER TABLE public.leave_request_approval ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Requestor can view leave_request_approval"
    ON public.leave_request_approval FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.leave_request lr
            WHERE lr.id = leave_request_approval.leave_request_id
              AND lr.member_id = public.current_member_id()
        )
        AND deleted_at IS NULL
    );

CREATE POLICY "Approver can view leave_request_approval"
    ON public.leave_request_approval FOR SELECT
    USING (
        approver_member_id = public.current_member_id()
        AND deleted_at IS NULL
    );

CREATE POLICY "Admins can view leave_request_approval"
    ON public.leave_request_approval FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.leave_request lr
            JOIN public.company_member cm ON cm.company_id = lr.company_id
            WHERE lr.id = leave_request_approval.leave_request_id
              AND cm.user_id = auth.uid()
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
        AND deleted_at IS NULL
    );

CREATE POLICY "System can insert leave_request_approval"
    ON public.leave_request_approval FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Approver can update leave_request_approval"
    ON public.leave_request_approval FOR UPDATE
    USING (
        approver_member_id = public.current_member_id()
        AND decision = 'pending'
    );

-- LEAVE_REQUEST_ATTACHMENT RLS
ALTER TABLE public.leave_request_attachment ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view leave_request_attachment"
    ON public.leave_request_attachment FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.leave_request lr
            WHERE lr.id = leave_request_attachment.leave_request_id
              AND (
                  lr.member_id = public.current_member_id()
                  OR EXISTS (
                      SELECT 1 FROM public.leave_request_approval lra
                      WHERE lra.leave_request_id = lr.id
                        AND lra.approver_member_id = public.current_member_id()
                  )
                  OR EXISTS (
                      SELECT 1 FROM public.company_member cm
                      WHERE cm.user_id = auth.uid()
                        AND cm.company_id = lr.company_id
                        AND cm.role = 'admin'
                        AND cm.deleted_at IS NULL
                  )
              )
        )
        AND deleted_at IS NULL
    );

CREATE POLICY "Members can insert own leave_request_attachment"
    ON public.leave_request_attachment FOR INSERT
    WITH CHECK (
        uploaded_by_member_id = public.current_member_id()
        AND EXISTS (
            SELECT 1 FROM public.leave_request lr
            WHERE lr.id = leave_request_attachment.leave_request_id
              AND lr.member_id = public.current_member_id()
        )
    );

CREATE POLICY "Members can delete own leave_request_attachment"
    ON public.leave_request_attachment FOR UPDATE
    USING (uploaded_by_member_id = public.current_member_id());

-- LEAVE_LEDGER RLS
ALTER TABLE public.leave_ledger ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view own leave_ledger"
    ON public.leave_ledger FOR SELECT
    USING (member_id = public.current_member_id());

CREATE POLICY "Admins can view company leave_ledger"
    ON public.leave_ledger FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = leave_ledger.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

-- LEAVE_BALANCE_SNAPSHOT RLS
ALTER TABLE public.leave_balance_snapshot ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view own leave_balance_snapshot"
    ON public.leave_balance_snapshot FOR SELECT
    USING (member_id = public.current_member_id());

CREATE POLICY "Admins can view company leave_balance_snapshot"
    ON public.leave_balance_snapshot FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = leave_balance_snapshot.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

-- =============================================================================
-- GRANTS
-- =============================================================================

GRANT SELECT, INSERT, UPDATE ON public.leave_type TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.leave_policy TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.leave_request TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.leave_request_segment TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.leave_request_approval TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.leave_request_attachment TO authenticated;
GRANT SELECT ON public.leave_ledger TO authenticated;
GRANT SELECT ON public.leave_balance_snapshot TO authenticated;
