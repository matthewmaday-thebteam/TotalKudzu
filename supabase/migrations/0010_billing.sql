-- =============================================================================
-- TotalKudzu V1 Schema - Migration 0010: Billing
-- =============================================================================
-- Company billing table for subscription management
-- =============================================================================

-- =============================================================================
-- COMPANY_BILLING
-- =============================================================================

CREATE TABLE public.company_billing (
    company_id uuid PRIMARY KEY REFERENCES public.company(id) ON DELETE CASCADE,
    plan_tier text NOT NULL CHECK (plan_tier IN ('starter_10', 'unlimited')),
    billing_status text NOT NULL CHECK (billing_status IN ('trialing', 'active', 'past_due', 'restricted', 'canceled')),
    billing_provider text NOT NULL DEFAULT 'simulated' CHECK (billing_provider IN ('simulated', 'stripe')),
    trial_started_at timestamptz NOT NULL DEFAULT now(),
    trial_ends_at timestamptz NOT NULL,
    grace_ends_at timestamptz,
    max_users int,
    stripe_customer_id text,
    stripe_subscription_id text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    -- Ensure max_users matches plan tier
    CONSTRAINT chk_max_users_plan CHECK (
        (plan_tier = 'starter_10' AND max_users = 10)
        OR (plan_tier = 'unlimited' AND max_users IS NULL)
    )
);

-- =============================================================================
-- INDEXES
-- =============================================================================

-- For billing status queries and cron jobs
CREATE INDEX idx_company_billing_status ON public.company_billing(billing_status);

-- For billing provider filtering
CREATE INDEX idx_company_billing_provider ON public.company_billing(billing_provider);

-- For finding expiring trials
CREATE INDEX idx_company_billing_trial_ends_at
    ON public.company_billing(trial_ends_at)
    WHERE billing_status = 'trialing';

-- For Stripe webhook lookups (future)
CREATE UNIQUE INDEX idx_company_billing_stripe_customer
    ON public.company_billing(stripe_customer_id)
    WHERE stripe_customer_id IS NOT NULL;

CREATE UNIQUE INDEX idx_company_billing_stripe_subscription
    ON public.company_billing(stripe_subscription_id)
    WHERE stripe_subscription_id IS NOT NULL;

-- =============================================================================
-- RLS
-- =============================================================================

ALTER TABLE public.company_billing ENABLE ROW LEVEL SECURITY;

-- Members can view their company's billing info (for trial banner, status checks)
CREATE POLICY "Members can view company billing"
    ON public.company_billing FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.company_member cm
            WHERE cm.user_id = auth.uid()
              AND cm.company_id = company_billing.company_id
              AND cm.deleted_at IS NULL
        )
    );

-- No INSERT/UPDATE/DELETE policies for authenticated users
-- All modifications via service_role (onboarding API, Stripe webhooks)

-- =============================================================================
-- TRIGGERS
-- =============================================================================

-- Auto-update updated_at
CREATE TRIGGER trg_set_updated_at
    BEFORE UPDATE ON public.company_billing
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_set_updated_at();

-- =============================================================================
-- HELPER FUNCTION: Get active user count for a company
-- =============================================================================
-- Counts members with status IN ('invited', 'active') toward max_users limit
-- Excludes 'disabled' members from the count

CREATE OR REPLACE FUNCTION public.company_active_user_count(p_company_id uuid)
RETURNS int
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COUNT(*)::int
    FROM public.company_member
    WHERE company_id = p_company_id
      AND deleted_at IS NULL
      AND status IN ('invited', 'active');
$$;

-- =============================================================================
-- GRANTS
-- =============================================================================

GRANT SELECT ON public.company_billing TO authenticated;
GRANT EXECUTE ON FUNCTION public.company_active_user_count(uuid) TO authenticated;
