-- =============================================================================
-- TotalKudzu V1 Schema - Migration 0008: Audit Log
-- =============================================================================
-- Audit log for tracking all changes
-- =============================================================================

-- =============================================================================
-- AUDIT_LOG
-- =============================================================================

CREATE TABLE public.audit_log (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid REFERENCES public.company(id), -- Can be NULL for system-level actions
    actor_member_id uuid REFERENCES public.company_member(id), -- Can be NULL for system actions
    actor_user_id uuid REFERENCES auth.users(id), -- Backup if member not yet created
    action text NOT NULL, -- 'INSERT', 'UPDATE', 'DELETE'
    entity_table text NOT NULL,
    entity_id uuid NOT NULL,
    before_json jsonb, -- NULL for INSERT
    after_json jsonb, -- NULL for DELETE
    changed_fields text[], -- List of changed column names (for UPDATE)
    ip_address inet,
    user_agent text,
    created_at timestamptz NOT NULL DEFAULT now()
    -- No updated_at, deleted_at - audit logs are immutable!
);

CREATE INDEX idx_audit_log_company_id ON public.audit_log(company_id);
CREATE INDEX idx_audit_log_actor_member_id ON public.audit_log(actor_member_id);
CREATE INDEX idx_audit_log_entity ON public.audit_log(entity_table, entity_id);
CREATE INDEX idx_audit_log_created_at ON public.audit_log(created_at);
CREATE INDEX idx_audit_log_action ON public.audit_log(action);

ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

-- Only admins can view audit logs
CREATE POLICY "Admins can view company audit_log"
    ON public.audit_log FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = audit_log.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

-- No INSERT/UPDATE/DELETE policies for users - only triggers can write

-- =============================================================================
-- HELPER FUNCTION: Get current member ID for audit (handles NULL gracefully)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.audit_actor_member_id()
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

-- =============================================================================
-- GRANTS
-- =============================================================================

GRANT SELECT ON public.audit_log TO authenticated;
GRANT EXECUTE ON FUNCTION public.audit_actor_member_id() TO authenticated;
