import { useState } from 'react';
import { useOnboarding, getPlanDisplayInfo } from '../../../contexts/OnboardingContext';
import { useAuth } from '../../../contexts/AuthContext';
import { HighKeyBackground } from '../../../design-system/patterns/HighKeyBackground';
import { Card } from '../../Card';
import { Button } from '../../Button';
import { Alert } from '../../Alert';
import { Spinner } from '../../Spinner';
import { Badge } from '../../Badge';
import { getCountryByCode } from '../../../data/countries';
import { TRIAL_DAYS } from '../../../types/onboarding';
import type { OnboardingCompleteResponse } from '../../../types/onboarding';

interface PaymentPageProps {
  onBack: () => void;
  onSuccess: (data: OnboardingCompleteResponse) => void;
}

export function PaymentPage({ onBack, onSuccess }: PaymentPageProps) {
  const { formData } = useOnboarding();
  const { user } = useAuth();
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const planInfo = getPlanDisplayInfo(formData.planTier);
  const country = getCountryByCode(formData.hqOfficeCountryCode);

  const handlePayment = async () => {
    if (!user) {
      setError('You must be signed in to complete onboarding');
      return;
    }

    setIsLoading(true);
    setError(null);

    try {
      // Get the current session token
      const { data: sessionData } = await (await import('../../../lib/supabase')).supabase.auth.getSession();
      const accessToken = sessionData.session?.access_token;

      if (!accessToken) {
        throw new Error('No valid session');
      }

      const response = await fetch('/api/onboarding/complete', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          company_name: formData.companyName.trim(),
          hq_office_name: formData.hqOfficeName.trim(),
          hq_office_timezone: formData.hqOfficeTimezone,
          hq_office_country_code: formData.hqOfficeCountryCode.toUpperCase(),
          plan_tier: formData.planTier,
        }),
      });

      const result = await response.json();

      if (!response.ok) {
        const errorMsg = result.error?.details
          ? `${result.error?.message}: ${result.error.details}`
          : result.error?.message || 'Failed to complete onboarding';
        throw new Error(errorMsg);
      }

      onSuccess(result.data);
    } catch (err) {
      console.error('Payment failed:', err);
      setError(err instanceof Error ? err.message : 'Failed to complete payment');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen relative">
      <HighKeyBackground />

      <div className="relative z-10 min-h-screen flex items-center justify-center p-4">
        <div className="w-full max-w-md">
          <Card variant="elevated" padding="lg">
            {/* Header */}
            <div className="text-center mb-8">
              <h1 className="text-2xl font-semibold text-vercel-gray-600">Review & Start Trial</h1>
              <p className="text-sm text-vercel-gray-400 mt-2">Confirm your details and begin your {TRIAL_DAYS}-day free trial</p>
            </div>

            {/* Error */}
            {error && (
              <div className="mb-6">
                <Alert message={error} variant="error" icon="error" />
              </div>
            )}

            {/* Summary */}
            <div className="space-y-4 mb-8">
              {/* Company */}
              <div className="p-4 bg-vercel-gray-50 rounded-lg">
                <div className="text-xs font-medium text-vercel-gray-400 uppercase tracking-wider mb-2">
                  Company
                </div>
                <div className="text-vercel-gray-600 font-medium">{formData.companyName}</div>
              </div>

              {/* Office */}
              <div className="p-4 bg-vercel-gray-50 rounded-lg">
                <div className="text-xs font-medium text-vercel-gray-400 uppercase tracking-wider mb-2">
                  HQ Office
                </div>
                <div className="text-vercel-gray-600 font-medium">{formData.hqOfficeName}</div>
                <div className="text-sm text-vercel-gray-400 mt-1">
                  {country?.label || formData.hqOfficeCountryCode} &middot; {formData.hqOfficeTimezone.replace(/_/g, ' ')}
                </div>
              </div>

              {/* Plan */}
              <div className="p-4 bg-vercel-gray-50 rounded-lg">
                <div className="text-xs font-medium text-vercel-gray-400 uppercase tracking-wider mb-2">
                  Plan
                </div>
                <div className="flex items-center justify-between">
                  <div>
                    <span className="text-vercel-gray-600 font-medium">{planInfo.name}</span>
                    <span className="text-sm text-vercel-gray-400 ml-2">({planInfo.maxUsers} users)</span>
                  </div>
                  <span className="text-lg font-bold text-vercel-gray-600">${planInfo.price}/mo</span>
                </div>
              </div>

              {/* Trial Info */}
              <div className="p-4 border border-success rounded-lg bg-success-light">
                <div className="flex items-center gap-2">
                  <Badge variant="success" size="md">{TRIAL_DAYS}-Day Free Trial</Badge>
                </div>
                <p className="text-sm text-success-text mt-2">
                  No charge today. Your trial starts immediately and you can cancel anytime.
                </p>
              </div>
            </div>

            {/* Actions */}
            <div className="space-y-3">
              <Button
                type="button"
                variant="primary"
                size="lg"
                className="w-full"
                onClick={handlePayment}
                disabled={isLoading}
              >
                {isLoading ? (
                  <span className="flex items-center justify-center gap-2">
                    <Spinner size="sm" color="white" />
                    Processing...
                  </span>
                ) : (
                  'Pay & Start Trial'
                )}
              </Button>

              <Button
                type="button"
                variant="ghost"
                size="md"
                className="w-full"
                onClick={onBack}
                disabled={isLoading}
              >
                Back to Company Setup
              </Button>
            </div>

            {/* Disclaimer */}
            <p className="text-xs text-vercel-gray-300 text-center mt-6">
              By clicking "Pay & Start Trial", you agree to our Terms of Service and Privacy Policy.
              This is a simulated payment for demo purposes.
            </p>
          </Card>
        </div>
      </div>
    </div>
  );
}
