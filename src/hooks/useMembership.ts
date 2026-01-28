import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import type { BillingStatus, PlanTier } from '../types/onboarding';

interface Membership {
  id: string;
  company_id: string;
  role: 'admin' | 'manager' | 'employee';
  status: 'invited' | 'active' | 'disabled';
  company: {
    id: string;
    name: string;
  } | null;
}

interface Billing {
  billing_status: BillingStatus;
  trial_started_at: string;
  trial_ends_at: string;
  plan_tier: PlanTier;
}

interface UseMembershipReturn {
  membership: Membership | null;
  billing: Billing | null;
  loading: boolean;
  error: Error | null;
  refetch: () => Promise<void>;
}

export function useMembership(): UseMembershipReturn {
  const { user } = useAuth();
  const [membership, setMembership] = useState<Membership | null>(null);
  const [billing, setBilling] = useState<Billing | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const fetchMembership = async () => {
    if (!user) {
      setMembership(null);
      setBilling(null);
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      setError(null);

      // Fetch membership with company
      const { data: memberData, error: memberError } = await supabase
        .from('company_member')
        .select(`
          id,
          company_id,
          role,
          status,
          company:company_id (
            id,
            name
          )
        `)
        .eq('user_id', user.id)
        .is('deleted_at', null)
        .single();

      // PGRST116 = no rows returned, which is expected for new users
      if (memberError && memberError.code !== 'PGRST116') {
        throw memberError;
      }

      if (!memberData) {
        setMembership(null);
        setBilling(null);
        setLoading(false);
        return;
      }

      // Transform the company data (Supabase returns it as an object or array)
      const company = Array.isArray(memberData.company)
        ? memberData.company[0]
        : memberData.company;

      setMembership({
        id: memberData.id,
        company_id: memberData.company_id,
        role: memberData.role,
        status: memberData.status,
        company,
      });

      // Fetch billing
      const { data: billingData, error: billingError } = await supabase
        .from('company_billing')
        .select('billing_status, trial_started_at, trial_ends_at, plan_tier')
        .eq('company_id', memberData.company_id)
        .single();

      if (billingError && billingError.code !== 'PGRST116') {
        throw billingError;
      }

      setBilling(billingData);
    } catch (err) {
      console.error('Failed to fetch membership:', err);
      setError(err instanceof Error ? err : new Error('Failed to fetch membership'));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchMembership();
  }, [user?.id]);

  return { membership, billing, loading, error, refetch: fetchMembership };
}
