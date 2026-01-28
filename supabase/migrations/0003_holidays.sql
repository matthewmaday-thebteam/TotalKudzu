-- =============================================================================
-- TotalKudzu V1 Schema - Migration 0003: Holidays
-- =============================================================================
-- Holiday calendars, holidays, office assignments, and overrides
-- =============================================================================

-- =============================================================================
-- HOLIDAY_CALENDAR (Global / System-wide reference data)
-- =============================================================================

CREATE TABLE public.holiday_calendar (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    country_code text NOT NULL, -- ISO 3166-1 alpha-2
    name text NOT NULL,
    description text,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_holiday_calendar_country_unique
    ON public.holiday_calendar(country_code, name);

ALTER TABLE public.holiday_calendar ENABLE ROW LEVEL SECURITY;

-- All authenticated users can view holiday calendars (global reference data)
CREATE POLICY "Authenticated users can view holiday_calendar"
    ON public.holiday_calendar FOR SELECT
    TO authenticated
    USING (is_active = true);

-- =============================================================================
-- HOLIDAY (Dates within calendars)
-- =============================================================================

CREATE TABLE public.holiday (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    holiday_calendar_id uuid NOT NULL REFERENCES public.holiday_calendar(id),
    date date NOT NULL,
    name text NOT NULL,
    is_half_day boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_holiday_calendar_id ON public.holiday(holiday_calendar_id);
CREATE INDEX idx_holiday_date ON public.holiday(date);
CREATE UNIQUE INDEX idx_holiday_unique
    ON public.holiday(holiday_calendar_id, date);

ALTER TABLE public.holiday ENABLE ROW LEVEL SECURITY;

-- All authenticated users can view holidays (global reference data)
CREATE POLICY "Authenticated users can view holiday"
    ON public.holiday FOR SELECT
    TO authenticated
    USING (true);

-- =============================================================================
-- OFFICE_HOLIDAY_CALENDAR (Office -> Calendar assignment)
-- =============================================================================

CREATE TABLE public.office_holiday_calendar (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    office_id uuid NOT NULL REFERENCES public.office(id),
    holiday_calendar_id uuid NOT NULL REFERENCES public.holiday_calendar(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- One calendar per office
CREATE UNIQUE INDEX idx_office_holiday_calendar_unique
    ON public.office_holiday_calendar(office_id);

ALTER TABLE public.office_holiday_calendar ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view office_holiday_calendar"
    ON public.office_holiday_calendar FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            JOIN public.office o ON o.id = office_holiday_calendar.office_id
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = o.company_id
              AND cm.deleted_at IS NULL
        )
    );

CREATE POLICY "Admins can insert office_holiday_calendar"
    ON public.office_holiday_calendar FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            JOIN public.office o ON o.id = office_holiday_calendar.office_id
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = o.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

CREATE POLICY "Admins can update office_holiday_calendar"
    ON public.office_holiday_calendar FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            JOIN public.office o ON o.id = office_holiday_calendar.office_id
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = o.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

CREATE POLICY "Admins can delete office_holiday_calendar"
    ON public.office_holiday_calendar FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            JOIN public.office o ON o.id = office_holiday_calendar.office_id
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = o.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

-- =============================================================================
-- OFFICE_HOLIDAY_OVERRIDE (Force holiday or force working day)
-- =============================================================================

CREATE TABLE public.office_holiday_override (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    office_id uuid NOT NULL REFERENCES public.office(id),
    date date NOT NULL,
    name text, -- Name for forced holiday, null for forced working day
    is_working_day_override boolean NOT NULL DEFAULT false, -- true = force working day, false = force holiday
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES auth.users(id)
);

CREATE INDEX idx_office_holiday_override_office_id ON public.office_holiday_override(office_id);
CREATE INDEX idx_office_holiday_override_date ON public.office_holiday_override(date);
CREATE UNIQUE INDEX idx_office_holiday_override_unique
    ON public.office_holiday_override(office_id, date)
    WHERE deleted_at IS NULL;

ALTER TABLE public.office_holiday_override ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view office_holiday_override"
    ON public.office_holiday_override FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            JOIN public.office o ON o.id = office_holiday_override.office_id
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = o.company_id
              AND cm.deleted_at IS NULL
        )
        AND deleted_at IS NULL
    );

CREATE POLICY "Admins can insert office_holiday_override"
    ON public.office_holiday_override FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            JOIN public.office o ON o.id = office_holiday_override.office_id
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = o.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

CREATE POLICY "Admins can update office_holiday_override"
    ON public.office_holiday_override FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            JOIN public.office o ON o.id = office_holiday_override.office_id
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = o.company_id
              AND cm.role = 'admin'
              AND cm.deleted_at IS NULL
        )
    );

-- =============================================================================
-- HELPER FUNCTION: Check if date is a holiday for an office
-- =============================================================================

CREATE OR REPLACE FUNCTION public.is_holiday_for_office(p_office_id uuid, p_date date)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_override record;
    v_is_holiday boolean := false;
BEGIN
    -- Check for office override first (takes precedence)
    SELECT is_working_day_override INTO v_override
    FROM public.office_holiday_override
    WHERE office_id = p_office_id
      AND date = p_date
      AND deleted_at IS NULL;

    IF FOUND THEN
        -- If override exists: true = forced working day (not holiday), false = forced holiday
        RETURN NOT v_override.is_working_day_override;
    END IF;

    -- Check calendar holidays
    SELECT EXISTS (
        SELECT 1
        FROM public.office_holiday_calendar ohc
        JOIN public.holiday h ON h.holiday_calendar_id = ohc.holiday_calendar_id
        WHERE ohc.office_id = p_office_id
          AND h.date = p_date
    ) INTO v_is_holiday;

    RETURN v_is_holiday;
END;
$$;

-- =============================================================================
-- GRANTS
-- =============================================================================

GRANT SELECT ON public.holiday_calendar TO authenticated;
GRANT SELECT ON public.holiday TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.office_holiday_calendar TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.office_holiday_override TO authenticated;

GRANT EXECUTE ON FUNCTION public.is_holiday_for_office(uuid, date) TO authenticated;
