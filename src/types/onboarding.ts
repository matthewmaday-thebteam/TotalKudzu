// Onboarding Types

export type PlanTier = 'starter_10' | 'unlimited';
export type BillingStatus = 'trialing' | 'active' | 'past_due' | 'restricted' | 'canceled';
export type BillingProvider = 'simulated' | 'stripe';

export interface OnboardingFormData {
  companyName: string;
  hqOfficeName: string;
  hqOfficeTimezone: string;
  hqOfficeCountryCode: string;
  planTier: PlanTier;
}

export interface OnboardingCompleteRequest {
  company_name: string;
  hq_office_name: string;
  hq_office_timezone: string;
  hq_office_country_code: string;
  plan_tier: PlanTier;
}

export interface OnboardingCompleteResponse {
  company_id: string;
  hq_office_id: string;
  member_id: string;
  billing_status: BillingStatus;
  trial_started_at: string;
  trial_ends_at: string;
  plan_tier: PlanTier;
}

export interface CompanyBilling {
  company_id: string;
  plan_tier: PlanTier;
  billing_status: BillingStatus;
  billing_provider: BillingProvider;
  trial_started_at: string;
  trial_ends_at: string;
  grace_ends_at: string | null;
  max_users: number | null;
  stripe_customer_id: string | null;
  stripe_subscription_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface CompanyMembership {
  id: string;
  company_id: string;
  user_id: string;
  role: 'admin' | 'manager' | 'employee';
  status: 'invited' | 'active' | 'disabled';
  company: {
    id: string;
    name: string;
  };
}

export const PLAN_DETAILS: Record<PlanTier, {
  name: string;
  price: number;
  maxUsers: number | null;
  features: string[];
}> = {
  starter_10: {
    name: 'Starter',
    price: 50,
    maxUsers: 10,
    features: ['Up to 10 users', 'All core features', 'Email support'],
  },
  unlimited: {
    name: 'Unlimited',
    price: 100,
    maxUsers: null,
    features: ['Unlimited users', 'All core features', 'Priority support'],
  },
};

export const TRIAL_DAYS = 7;
