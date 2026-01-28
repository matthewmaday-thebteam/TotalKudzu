-- =============================================================================
-- TotalKudzu V1 Schema - Migration 0004: Approvals
-- =============================================================================
-- Approval rules with inheritance: member -> department -> company default
-- =============================================================================

-- =============================================================================
-- APPROVAL_RULE
-- =============================================================================

CREATE TABLE public.approval_rule (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES public.company(id),
    rule_type text NOT NULL CHECK (rule_type IN ('leave', 'timesheet')),
    name text NOT NULL,
    priority int NOT NULL DEFAULT 0, -- Higher priority takes precedence
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES auth.users(id)
);

CREATE INDEX idx_approval_rule_company_id ON public.approval_rule(company_id);
CREATE INDEX idx_approval_rule_type ON public.approval_rule(rule_type);

ALTER TABLE public.approval_rule ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view company approval_rule"
    ON public.approval_rule FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = approval_rule.company_id
              AND cm.deleted_at IS NULL
        )
        AND deleted_at IS NULL
    );

CREATE POLICY "Admins can insert approval_rule"
    ON public.approval_rule FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = approval_rule.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

CREATE POLICY "Admins can update approval_rule"
    ON public.approval_rule FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = approval_rule.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

-- =============================================================================
-- APPROVAL_RULE_TARGET
-- Defines what the rule applies to: company_default, department, or member
-- =============================================================================

CREATE TABLE public.approval_rule_target (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    approval_rule_id uuid NOT NULL REFERENCES public.approval_rule(id) ON DELETE CASCADE,
    target_type text NOT NULL CHECK (target_type IN ('company_default', 'department', 'member')),
    department_id uuid REFERENCES public.department(id), -- Required when target_type = 'department'
    member_id uuid REFERENCES public.company_member(id), -- Required when target_type = 'member'
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    -- Ensure correct FK is set based on target_type
    CONSTRAINT chk_target_type_department CHECK (
        (target_type = 'department' AND department_id IS NOT NULL) OR
        (target_type != 'department' AND department_id IS NULL)
    ),
    CONSTRAINT chk_target_type_member CHECK (
        (target_type = 'member' AND member_id IS NOT NULL) OR
        (target_type != 'member' AND member_id IS NULL)
    )
);

CREATE INDEX idx_approval_rule_target_rule_id ON public.approval_rule_target(approval_rule_id);
CREATE INDEX idx_approval_rule_target_department_id ON public.approval_rule_target(department_id);
CREATE INDEX idx_approval_rule_target_member_id ON public.approval_rule_target(member_id);

-- One target per rule
CREATE UNIQUE INDEX idx_approval_rule_target_unique
    ON public.approval_rule_target(approval_rule_id);

ALTER TABLE public.approval_rule_target ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view approval_rule_target"
    ON public.approval_rule_target FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            JOIN public.approval_rule ar ON ar.id = approval_rule_target.approval_rule_id
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = ar.company_id
              AND cm.deleted_at IS NULL
        )
    );

CREATE POLICY "Admins can insert approval_rule_target"
    ON public.approval_rule_target FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            JOIN public.approval_rule ar ON ar.id = approval_rule_target.approval_rule_id
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = ar.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

CREATE POLICY "Admins can update approval_rule_target"
    ON public.approval_rule_target FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            JOIN public.approval_rule ar ON ar.id = approval_rule_target.approval_rule_id
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = ar.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

-- =============================================================================
-- APPROVAL_RULE_APPROVER
-- The specific member who approves (V1: single approver)
-- =============================================================================

CREATE TABLE public.approval_rule_approver (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    approval_rule_id uuid NOT NULL REFERENCES public.approval_rule(id) ON DELETE CASCADE,
    approver_member_id uuid NOT NULL REFERENCES public.company_member(id),
    effective_from date, -- Optional: rule effective date range
    effective_to date,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_approval_rule_approver_rule_id ON public.approval_rule_approver(approval_rule_id);
CREATE INDEX idx_approval_rule_approver_member_id ON public.approval_rule_approver(approver_member_id);

-- One approver per rule (V1: single approver)
CREATE UNIQUE INDEX idx_approval_rule_approver_unique
    ON public.approval_rule_approver(approval_rule_id);

ALTER TABLE public.approval_rule_approver ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view approval_rule_approver"
    ON public.approval_rule_approver FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            JOIN public.approval_rule ar ON ar.id = approval_rule_approver.approval_rule_id
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = ar.company_id
              AND cm.deleted_at IS NULL
        )
    );

CREATE POLICY "Admins can insert approval_rule_approver"
    ON public.approval_rule_approver FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            JOIN public.approval_rule ar ON ar.id = approval_rule_approver.approval_rule_id
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = ar.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

CREATE POLICY "Admins can update approval_rule_approver"
    ON public.approval_rule_approver FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            JOIN public.approval_rule ar ON ar.id = approval_rule_approver.approval_rule_id
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = ar.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

-- =============================================================================
-- HELPER FUNCTION: Resolve Approver for Leave Request
-- Priority: member override -> primary department rule -> company default
-- =============================================================================

CREATE OR REPLACE FUNCTION public.resolve_leave_approver(p_member_id uuid, p_company_id uuid)
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_approver_id uuid;
    v_primary_department_id uuid;
BEGIN
    -- 1. Check for member-targeted rule
    SELECT ara.approver_member_id INTO v_approver_id
    FROM public.approval_rule ar
    JOIN public.approval_rule_target art ON art.approval_rule_id = ar.id
    JOIN public.approval_rule_approver ara ON ara.approval_rule_id = ar.id
    WHERE ar.company_id = p_company_id
      AND ar.rule_type = 'leave'
      AND ar.is_active = true
      AND ar.deleted_at IS NULL
      AND art.target_type = 'member'
      AND art.member_id = p_member_id
      AND (ara.effective_from IS NULL OR ara.effective_from <= CURRENT_DATE)
      AND (ara.effective_to IS NULL OR ara.effective_to >= CURRENT_DATE)
    ORDER BY ar.priority DESC
    LIMIT 1;

    IF v_approver_id IS NOT NULL THEN
        RETURN v_approver_id;
    END IF;

    -- 2. Check for primary department rule
    v_primary_department_id := public.primary_department_id(p_member_id);

    IF v_primary_department_id IS NOT NULL THEN
        SELECT ara.approver_member_id INTO v_approver_id
        FROM public.approval_rule ar
        JOIN public.approval_rule_target art ON art.approval_rule_id = ar.id
        JOIN public.approval_rule_approver ara ON ara.approval_rule_id = ar.id
        WHERE ar.company_id = p_company_id
          AND ar.rule_type = 'leave'
          AND ar.is_active = true
          AND ar.deleted_at IS NULL
          AND art.target_type = 'department'
          AND art.department_id = v_primary_department_id
          AND (ara.effective_from IS NULL OR ara.effective_from <= CURRENT_DATE)
          AND (ara.effective_to IS NULL OR ara.effective_to >= CURRENT_DATE)
        ORDER BY ar.priority DESC
        LIMIT 1;

        IF v_approver_id IS NOT NULL THEN
            RETURN v_approver_id;
        END IF;
    END IF;

    -- 3. Fall back to company default
    SELECT ara.approver_member_id INTO v_approver_id
    FROM public.approval_rule ar
    JOIN public.approval_rule_target art ON art.approval_rule_id = ar.id
    JOIN public.approval_rule_approver ara ON ara.approval_rule_id = ar.id
    WHERE ar.company_id = p_company_id
      AND ar.rule_type = 'leave'
      AND ar.is_active = true
      AND ar.deleted_at IS NULL
      AND art.target_type = 'company_default'
      AND (ara.effective_from IS NULL OR ara.effective_from <= CURRENT_DATE)
      AND (ara.effective_to IS NULL OR ara.effective_to >= CURRENT_DATE)
    ORDER BY ar.priority DESC
    LIMIT 1;

    RETURN v_approver_id;
END;
$$;

-- =============================================================================
-- GRANTS
-- =============================================================================

GRANT SELECT, INSERT, UPDATE ON public.approval_rule TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.approval_rule_target TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.approval_rule_approver TO authenticated;

GRANT EXECUTE ON FUNCTION public.resolve_leave_approver(uuid, uuid) TO authenticated;
