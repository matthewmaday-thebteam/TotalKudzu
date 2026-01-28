-- =============================================================================
-- TotalKudzu V1 Schema - Migration 0011: Fix Audit Trigger
-- =============================================================================
-- Drop audit trigger from company table (it doesn't have company_id field)
-- =============================================================================

-- Drop the audit trigger from the company table
-- The company table uses 'id' not 'company_id', which causes the trigger to fail
DROP TRIGGER IF EXISTS trg_audit_log ON public.company;
