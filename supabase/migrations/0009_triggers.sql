-- =============================================================================
-- TotalKudzu V1 Schema - Migration 0009: Triggers
-- =============================================================================
-- All triggers for data integrity, sync, and audit
-- =============================================================================

-- =============================================================================
-- 1. trg_set_updated_at - Auto-update updated_at timestamp
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

-- Apply to all tables with updated_at
DO $$
DECLARE
    t text;
BEGIN
    FOR t IN
        SELECT table_name
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND column_name = 'updated_at'
          AND table_name NOT IN ('audit_log', 'leave_ledger')
    LOOP
        EXECUTE format('
            DROP TRIGGER IF EXISTS trg_set_updated_at ON public.%I;
            CREATE TRIGGER trg_set_updated_at
                BEFORE UPDATE ON public.%I
                FOR EACH ROW
                EXECUTE FUNCTION public.fn_set_updated_at();
        ', t, t);
    END LOOP;
END;
$$;

-- =============================================================================
-- 2. trg_sync_primary_office - Bidirectional sync for primary office
-- =============================================================================

-- Part A: member_office.is_primary -> company_member.primary_office_id
CREATE OR REPLACE FUNCTION public.fn_sync_primary_office_from_join()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- When is_primary is set to true, update company_member
    IF NEW.is_primary = true AND NEW.deleted_at IS NULL THEN
        UPDATE public.company_member
        SET primary_office_id = NEW.office_id
        WHERE id = NEW.member_id;
    END IF;

    -- When is_primary is set to false or row is deleted, clear if it was the primary
    IF (NEW.is_primary = false OR NEW.deleted_at IS NOT NULL)
       AND OLD.is_primary = true THEN
        UPDATE public.company_member
        SET primary_office_id = NULL
        WHERE id = NEW.member_id
          AND primary_office_id = OLD.office_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_sync_primary_office_from_join
    AFTER INSERT OR UPDATE OF is_primary, deleted_at ON public.member_office
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_sync_primary_office_from_join();

-- Part B: company_member.primary_office_id -> member_office.is_primary
CREATE OR REPLACE FUNCTION public.fn_sync_primary_office_to_join()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Skip if no change
    IF OLD.primary_office_id IS NOT DISTINCT FROM NEW.primary_office_id THEN
        RETURN NEW;
    END IF;

    -- Clear old primary
    IF OLD.primary_office_id IS NOT NULL THEN
        UPDATE public.member_office
        SET is_primary = false
        WHERE member_id = NEW.id
          AND office_id = OLD.primary_office_id
          AND deleted_at IS NULL;
    END IF;

    -- Set new primary (must have membership)
    IF NEW.primary_office_id IS NOT NULL THEN
        -- Ensure membership exists
        IF NOT EXISTS (
            SELECT 1 FROM public.member_office
            WHERE member_id = NEW.id
              AND office_id = NEW.primary_office_id
              AND deleted_at IS NULL
        ) THEN
            RAISE EXCEPTION 'Cannot set primary_office_id: member is not assigned to that office';
        END IF;

        UPDATE public.member_office
        SET is_primary = true
        WHERE member_id = NEW.id
          AND office_id = NEW.primary_office_id
          AND deleted_at IS NULL;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_sync_primary_office_to_join
    AFTER UPDATE OF primary_office_id ON public.company_member
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_sync_primary_office_to_join();

-- =============================================================================
-- 3. trg_validate_leave_department - Block leave requests without primary dept
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_validate_leave_department()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_primary_dept_id uuid;
BEGIN
    -- Get member's primary department
    v_primary_dept_id := public.primary_department_id(NEW.member_id);

    -- Must have primary department
    IF v_primary_dept_id IS NULL THEN
        RAISE EXCEPTION 'Cannot create leave request: member has no primary department assigned';
    END IF;

    -- Verify department_id matches primary department
    IF NEW.department_id != v_primary_dept_id THEN
        RAISE EXCEPTION 'Leave request department_id must match member''s primary department';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_leave_department
    BEFORE INSERT ON public.leave_request
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_validate_leave_department();

-- =============================================================================
-- 4. trg_timesheet_reapproval - Mark approved timesheets as needs_reapproval
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_timesheet_reapproval()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_member_id uuid;
    v_work_date date;
BEGIN
    -- Determine member_id and work_date based on operation
    IF TG_OP = 'DELETE' THEN
        v_member_id := OLD.member_id;
        v_work_date := OLD.work_date;
    ELSE
        v_member_id := NEW.member_id;
        v_work_date := NEW.work_date;
    END IF;

    -- Find and update any approved submissions covering this date
    UPDATE public.timesheet_submission ts
    SET status = 'needs_reapproval',
        approved_at = NULL,
        approved_by_member_id = NULL
    FROM public.timesheet_period tp
    WHERE ts.timesheet_period_id = tp.id
      AND ts.member_id = v_member_id
      AND ts.status = 'approved'
      AND ts.deleted_at IS NULL
      AND v_work_date BETWEEN tp.start_date AND tp.end_date;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

CREATE TRIGGER trg_timesheet_reapproval
    AFTER INSERT OR UPDATE OR DELETE ON public.time_entry
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_timesheet_reapproval();

-- =============================================================================
-- 5. trg_leave_ledger_on_approval - Create usage transaction on approval
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_leave_ledger_on_approval()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_request record;
    v_policy_year int;
BEGIN
    -- Only act when decision changes to 'approved'
    IF NEW.decision = 'approved' AND (OLD.decision IS NULL OR OLD.decision != 'approved') THEN
        -- Get the leave request details
        SELECT lr.*, lt.company_id as leave_type_company_id
        INTO v_request
        FROM public.leave_request lr
        JOIN public.leave_type lt ON lt.id = lr.leave_type_id
        WHERE lr.id = NEW.leave_request_id;

        -- Determine policy year (use request_date year for now)
        v_policy_year := EXTRACT(YEAR FROM v_request.request_date)::int;

        -- Insert usage transaction (negative minutes)
        INSERT INTO public.leave_ledger (
            company_id,
            member_id,
            leave_type_id,
            policy_year,
            transaction_type,
            minutes,
            effective_date,
            reference_id,
            note
        ) VALUES (
            v_request.company_id,
            v_request.member_id,
            v_request.leave_type_id,
            v_policy_year,
            'usage',
            -v_request.requested_minutes, -- Negative for debit
            v_request.request_date,
            v_request.id,
            'Leave approved'
        );

        -- Update request status
        UPDATE public.leave_request
        SET status = 'approved'
        WHERE id = NEW.leave_request_id;
    END IF;

    -- Handle rejection
    IF NEW.decision = 'rejected' AND (OLD.decision IS NULL OR OLD.decision != 'rejected') THEN
        UPDATE public.leave_request
        SET status = 'rejected'
        WHERE id = NEW.leave_request_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_leave_ledger_on_approval
    AFTER UPDATE OF decision ON public.leave_request_approval
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_leave_ledger_on_approval();

-- =============================================================================
-- 6. trg_leave_ledger_reversal - Create reversal on cancellation
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_leave_ledger_reversal()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_original_entry record;
    v_policy_year int;
BEGIN
    -- Only act when status changes to 'cancelled' from 'approved'
    IF NEW.status = 'cancelled' AND OLD.status = 'approved' THEN
        -- Find the original usage entry
        SELECT * INTO v_original_entry
        FROM public.leave_ledger
        WHERE reference_id = NEW.id
          AND transaction_type = 'usage'
        LIMIT 1;

        IF v_original_entry IS NOT NULL THEN
            v_policy_year := EXTRACT(YEAR FROM NEW.request_date)::int;

            -- Insert reversal transaction (opposite sign)
            INSERT INTO public.leave_ledger (
                company_id,
                member_id,
                leave_type_id,
                policy_year,
                transaction_type,
                minutes,
                effective_date,
                reference_id,
                note
            ) VALUES (
                NEW.company_id,
                NEW.member_id,
                NEW.leave_type_id,
                v_policy_year,
                'reversal',
                -v_original_entry.minutes, -- Opposite of original (positive)
                NEW.request_date,
                NEW.id,
                'Leave cancelled - reversal'
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_leave_ledger_reversal
    AFTER UPDATE OF status ON public.leave_request
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_leave_ledger_reversal();

-- =============================================================================
-- 7. trg_update_balance_snapshot - Update snapshots after ledger insert
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_update_balance_snapshot()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_available int;
    v_used int;
BEGIN
    -- Calculate totals from ledger
    SELECT
        COALESCE(SUM(CASE WHEN minutes > 0 THEN minutes ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN minutes < 0 THEN -minutes ELSE 0 END), 0)
    INTO v_available, v_used
    FROM public.leave_ledger
    WHERE member_id = NEW.member_id
      AND leave_type_id = NEW.leave_type_id
      AND policy_year = NEW.policy_year;

    -- Upsert snapshot
    INSERT INTO public.leave_balance_snapshot (
        company_id,
        member_id,
        leave_type_id,
        policy_year,
        available_minutes,
        used_minutes,
        last_calculated_at
    ) VALUES (
        NEW.company_id,
        NEW.member_id,
        NEW.leave_type_id,
        NEW.policy_year,
        v_available - v_used,
        v_used,
        now()
    )
    ON CONFLICT (member_id, leave_type_id, policy_year)
    DO UPDATE SET
        available_minutes = v_available - v_used,
        used_minutes = v_used,
        last_calculated_at = now();

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_update_balance_snapshot
    AFTER INSERT ON public.leave_ledger
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_update_balance_snapshot();

-- =============================================================================
-- 8. trg_update_pending_minutes - Track pending leave requests
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_update_pending_minutes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_pending int;
    v_policy_year int;
BEGIN
    v_policy_year := EXTRACT(YEAR FROM NEW.request_date)::int;

    -- Calculate pending minutes for this member/type/year
    SELECT COALESCE(SUM(requested_minutes), 0)
    INTO v_pending
    FROM public.leave_request
    WHERE member_id = NEW.member_id
      AND leave_type_id = NEW.leave_type_id
      AND EXTRACT(YEAR FROM request_date) = v_policy_year
      AND status = 'pending'
      AND deleted_at IS NULL;

    -- Update snapshot
    UPDATE public.leave_balance_snapshot
    SET pending_minutes = v_pending,
        last_calculated_at = now()
    WHERE member_id = NEW.member_id
      AND leave_type_id = NEW.leave_type_id
      AND policy_year = v_policy_year;

    -- If no snapshot exists, create one
    IF NOT FOUND THEN
        INSERT INTO public.leave_balance_snapshot (
            company_id,
            member_id,
            leave_type_id,
            policy_year,
            available_minutes,
            pending_minutes,
            used_minutes,
            last_calculated_at
        ) VALUES (
            NEW.company_id,
            NEW.member_id,
            NEW.leave_type_id,
            v_policy_year,
            0,
            v_pending,
            0,
            now()
        )
        ON CONFLICT (member_id, leave_type_id, policy_year)
        DO UPDATE SET
            pending_minutes = v_pending,
            last_calculated_at = now();
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_update_pending_minutes
    AFTER INSERT OR UPDATE OF status ON public.leave_request
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_update_pending_minutes();

-- =============================================================================
-- 9. trg_leave_ledger_immutable - Prevent updates/deletes on ledger
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_leave_ledger_immutable()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'leave_ledger is immutable - use reversal transactions instead';
END;
$$;

CREATE TRIGGER trg_leave_ledger_immutable
    BEFORE UPDATE OR DELETE ON public.leave_ledger
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_leave_ledger_immutable();

-- =============================================================================
-- 10. trg_compute_duration - Auto-compute duration_minutes
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_compute_duration()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.duration_minutes := EXTRACT(EPOCH FROM (NEW.end_time_utc - NEW.start_time_utc))::int / 60;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_compute_duration
    BEFORE INSERT OR UPDATE OF start_time_utc, end_time_utc ON public.time_entry
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_compute_duration();

-- =============================================================================
-- 11. trg_audit_log - Audit trail for all business tables
-- =============================================================================

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
BEGIN
    -- Get actor
    v_actor_member_id := public.audit_actor_member_id();

    -- Determine company_id
    IF TG_OP = 'DELETE' THEN
        v_company_id := CASE
            WHEN TG_TABLE_NAME IN ('company') THEN OLD.id
            ELSE OLD.company_id
        END;
        v_before := to_jsonb(OLD);
        v_after := NULL;
    ELSIF TG_OP = 'INSERT' THEN
        v_company_id := CASE
            WHEN TG_TABLE_NAME IN ('company') THEN NEW.id
            ELSE NEW.company_id
        END;
        v_before := NULL;
        v_after := to_jsonb(NEW);
    ELSE -- UPDATE
        v_company_id := CASE
            WHEN TG_TABLE_NAME IN ('company') THEN NEW.id
            ELSE NEW.company_id
        END;
        v_before := to_jsonb(OLD);
        v_after := to_jsonb(NEW);

        -- Calculate changed fields
        FOR v_key IN SELECT jsonb_object_keys(v_after)
        LOOP
            IF v_before->v_key IS DISTINCT FROM v_after->v_key THEN
                v_changed_fields := array_append(v_changed_fields, v_key);
            END IF;
        END LOOP;
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

-- Apply audit trigger to all business tables (except audit_log, holiday_calendar, holiday)
DO $$
DECLARE
    t text;
    excluded_tables text[] := ARRAY['audit_log', 'holiday_calendar', 'holiday'];
BEGIN
    FOR t IN
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_type = 'BASE TABLE'
          AND table_name NOT IN (SELECT unnest(excluded_tables))
    LOOP
        -- Check if table has an 'id' column
        IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = t
              AND column_name = 'id'
        ) THEN
            EXECUTE format('
                DROP TRIGGER IF EXISTS trg_audit_log ON public.%I;
                CREATE TRIGGER trg_audit_log
                    AFTER INSERT OR UPDATE OR DELETE ON public.%I
                    FOR EACH ROW
                    EXECUTE FUNCTION public.fn_audit_log();
            ', t, t);
        END IF;
    END LOOP;
END;
$$;

-- =============================================================================
-- 12. trg_create_leave_approval - Auto-create approval record on request
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_create_leave_approval()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_approver_id uuid;
BEGIN
    -- Get the approver for this request
    v_approver_id := public.resolve_leave_approver(NEW.member_id, NEW.company_id);

    IF v_approver_id IS NULL THEN
        RAISE EXCEPTION 'No approver configured for this leave request';
    END IF;

    -- Create approval record
    INSERT INTO public.leave_request_approval (
        leave_request_id,
        approver_member_id,
        decision
    ) VALUES (
        NEW.id,
        v_approver_id,
        'pending'
    );

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_create_leave_approval
    AFTER INSERT ON public.leave_request
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_create_leave_approval();
