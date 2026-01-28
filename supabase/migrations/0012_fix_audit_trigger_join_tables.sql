-- =============================================================================
-- TotalKudzu V1 Schema - Migration 0012: Fix Audit Trigger for Join Tables
-- =============================================================================
-- The audit trigger fails on tables without company_id column:
-- - company (uses 'id' instead)
-- - profile (no company association)
-- - member_office (has member_id, not company_id)
-- - member_department (has member_id, not company_id)
-- - leave_request_segment (has leave_request_id, not company_id)
-- - leave_request_approval (has leave_request_id, not company_id)
-- - leave_request_attachment (has leave_request_id, not company_id)
-- - timesheet_approval (has timesheet_submission_id, not company_id)
-- =============================================================================

-- Replace the audit log function with one that handles all table types
CREATE OR REPLACE FUNCTION public.fn_audit_log()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company_id uuid;
    v_actor_member_id uuid;
    v_before jsonb;
    v_after jsonb;
    v_changed_fields text[];
    v_key text;
    v_record record;
BEGIN
    -- Get actor
    v_actor_member_id := public.audit_actor_member_id();

    -- Prepare before/after JSON
    IF TG_OP = 'DELETE' THEN
        v_before := to_jsonb(OLD);
        v_after := NULL;
        v_record := OLD;
    ELSIF TG_OP = 'INSERT' THEN
        v_before := NULL;
        v_after := to_jsonb(NEW);
        v_record := NEW;
    ELSE -- UPDATE
        v_before := to_jsonb(OLD);
        v_after := to_jsonb(NEW);
        v_record := NEW;

        -- Calculate changed fields
        FOR v_key IN SELECT jsonb_object_keys(v_after)
        LOOP
            IF v_before->v_key IS DISTINCT FROM v_after->v_key THEN
                v_changed_fields := array_append(v_changed_fields, v_key);
            END IF;
        END LOOP;
    END IF;

    -- Determine company_id based on table structure
    -- Tables with 'id' as company identifier
    IF TG_TABLE_NAME = 'company' THEN
        v_company_id := v_record.id;

    -- Tables with direct company_id column
    ELSIF TG_TABLE_NAME IN (
        'company_member', 'office', 'department', 'work_schedule',
        'office_holiday_calendar', 'office_holiday_override',
        'approval_rule', 'leave_type', 'leave_request', 'leave_ledger',
        'leave_balance_snapshot', 'project', 'time_entry', 'timer_session',
        'timesheet_period', 'timesheet_submission', 'company_billing'
    ) THEN
        v_company_id := v_record.company_id;

    -- Join tables: member_office, member_department - look up via member
    ELSIF TG_TABLE_NAME IN ('member_office', 'member_department') THEN
        SELECT cm.company_id INTO v_company_id
        FROM public.company_member cm
        WHERE cm.id = v_record.member_id;

    -- Leave sub-tables: look up via leave_request
    ELSIF TG_TABLE_NAME IN ('leave_request_segment', 'leave_request_approval', 'leave_request_attachment') THEN
        SELECT lr.company_id INTO v_company_id
        FROM public.leave_request lr
        WHERE lr.id = v_record.leave_request_id;

    -- Approval rule sub-tables: look up via approval_rule
    ELSIF TG_TABLE_NAME IN ('approval_rule_target', 'approval_rule_approver') THEN
        SELECT ar.company_id INTO v_company_id
        FROM public.approval_rule ar
        WHERE ar.id = v_record.approval_rule_id;

    -- Timesheet approval: look up via timesheet_submission
    ELSIF TG_TABLE_NAME = 'timesheet_approval' THEN
        SELECT ts.company_id INTO v_company_id
        FROM public.timesheet_submission ts
        WHERE ts.id = v_record.timesheet_submission_id;

    -- Task: look up via project
    ELSIF TG_TABLE_NAME = 'task' THEN
        SELECT p.company_id INTO v_company_id
        FROM public.project p
        WHERE p.id = v_record.project_id;

    -- Profile: no company association (user-level)
    ELSIF TG_TABLE_NAME = 'profile' THEN
        v_company_id := NULL;

    -- Leave policy: look up via leave_type
    ELSIF TG_TABLE_NAME = 'leave_policy' THEN
        SELECT lt.company_id INTO v_company_id
        FROM public.leave_type lt
        WHERE lt.id = v_record.leave_type_id;

    -- Fallback: try to get company_id if it exists, otherwise NULL
    ELSE
        v_company_id := NULL;
    END IF;

    -- Insert audit record
    INSERT INTO public.audit_log (
        company_id,
        actor_member_id,
        actor_user_id,
        action,
        entity_table,
        entity_id,
        before_json,
        after_json,
        changed_fields
    ) VALUES (
        v_company_id,
        v_actor_member_id,
        auth.uid(),
        TG_OP,
        TG_TABLE_NAME,
        CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END,
        v_before,
        v_after,
        v_changed_fields
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

-- Note: The triggers already exist from 0009_triggers.sql, they will now use
-- the updated function. No need to recreate triggers.
