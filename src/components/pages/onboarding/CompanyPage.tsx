import { useState } from 'react';
import { useOnboarding } from '../../../contexts/OnboardingContext';
import { HighKeyBackground } from '../../../design-system/patterns/HighKeyBackground';
import { Card } from '../../Card';
import { Input } from '../../Input';
import { Select } from '../../Select';
import { Button } from '../../Button';
import { TIMEZONES, getUserTimezone } from '../../../data/timezones';
import { COUNTRIES } from '../../../data/countries';
import type { PlanTier } from '../../../types/onboarding';
import { PLAN_DETAILS } from '../../../types/onboarding';

interface CompanyPageProps {
  onContinue: () => void;
}

export function CompanyPage({ onContinue }: CompanyPageProps) {
  const { formData, updateFormData, isValid } = useOnboarding();
  const [errors, setErrors] = useState<Record<string, string>>({});

  // Initialize timezone if empty
  if (!formData.hqOfficeTimezone) {
    updateFormData({ hqOfficeTimezone: getUserTimezone() });
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    // Validate
    const newErrors: Record<string, string> = {};
    if (formData.companyName.trim().length < 2) {
      newErrors.companyName = 'Company name must be at least 2 characters';
    }
    if (formData.hqOfficeName.trim().length < 2) {
      newErrors.hqOfficeName = 'Office name must be at least 2 characters';
    }
    if (!formData.hqOfficeTimezone) {
      newErrors.hqOfficeTimezone = 'Timezone is required';
    }
    if (formData.hqOfficeCountryCode.length !== 2) {
      newErrors.hqOfficeCountryCode = 'Country is required';
    }

    setErrors(newErrors);

    if (Object.keys(newErrors).length === 0) {
      onContinue();
    }
  };

  const selectPlan = (plan: PlanTier) => {
    updateFormData({ planTier: plan });
  };

  const timezoneOptions = TIMEZONES.map(tz => ({ value: tz.value, label: tz.label }));
  const countryOptions = COUNTRIES.map(c => ({ value: c.value, label: c.label }));

  return (
    <div className="min-h-screen relative">
      <HighKeyBackground />

      <div className="relative z-10 min-h-screen flex items-center justify-center p-4">
        <div className="w-full max-w-2xl">
          <Card variant="elevated" padding="lg">
            {/* Header */}
            <div className="text-center mb-8">
              <h1 className="text-2xl font-semibold text-vercel-gray-600">Set Up Your Company</h1>
              <p className="text-sm text-vercel-gray-400 mt-2">Tell us about your organization</p>
            </div>

            <form onSubmit={handleSubmit} className="space-y-6">
              {/* Company Details */}
              <div className="space-y-4">
                <Input
                  label="Company Name"
                  value={formData.companyName}
                  onChange={(e) => updateFormData({ companyName: e.target.value })}
                  placeholder="Acme Inc"
                  error={errors.companyName}
                />

                <Input
                  label="HQ Office Name"
                  value={formData.hqOfficeName}
                  onChange={(e) => updateFormData({ hqOfficeName: e.target.value })}
                  placeholder="Main Office"
                  helperText="Name for your primary office location"
                  error={errors.hqOfficeName}
                />

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-vercel-gray-600 mb-1">
                      Timezone
                    </label>
                    <Select
                      value={formData.hqOfficeTimezone}
                      onChange={(value) => updateFormData({ hqOfficeTimezone: value })}
                      options={timezoneOptions}
                      placeholder="Select timezone"
                      className="w-full"
                    />
                    {errors.hqOfficeTimezone && (
                      <p className="mt-1 text-xs font-mono text-bteam-brand">{errors.hqOfficeTimezone}</p>
                    )}
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-vercel-gray-600 mb-1">
                      Country
                    </label>
                    <Select
                      value={formData.hqOfficeCountryCode}
                      onChange={(value) => updateFormData({ hqOfficeCountryCode: value })}
                      options={countryOptions}
                      placeholder="Select country"
                      className="w-full"
                    />
                    {errors.hqOfficeCountryCode && (
                      <p className="mt-1 text-xs font-mono text-bteam-brand">{errors.hqOfficeCountryCode}</p>
                    )}
                  </div>
                </div>
              </div>

              {/* Plan Selection */}
              <div>
                <label className="block text-sm font-medium text-vercel-gray-600 mb-3">
                  Select Your Plan
                </label>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {(Object.entries(PLAN_DETAILS) as [PlanTier, typeof PLAN_DETAILS[PlanTier]][]).map(([tier, details]) => (
                    <button
                      key={tier}
                      type="button"
                      onClick={() => selectPlan(tier)}
                      className={`text-left p-4 rounded-lg border-2 transition-colors ${
                        formData.planTier === tier
                          ? 'border-vercel-gray-600 bg-vercel-gray-50'
                          : 'border-vercel-gray-100 hover:border-vercel-gray-200'
                      }`}
                    >
                      <div className="flex items-center justify-between mb-2">
                        <span className="font-semibold text-vercel-gray-600">{details.name}</span>
                        <span className="text-lg font-bold text-vercel-gray-600">${details.price}/mo</span>
                      </div>
                      <ul className="space-y-1">
                        {details.features.map((feature, idx) => (
                          <li key={idx} className="text-xs text-vercel-gray-400 flex items-center gap-1">
                            <svg className="w-3 h-3 text-success" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                            </svg>
                            {feature}
                          </li>
                        ))}
                      </ul>
                    </button>
                  ))}
                </div>
              </div>

              {/* Submit */}
              <Button
                type="submit"
                variant="primary"
                size="lg"
                className="w-full"
                disabled={!isValid}
              >
                Continue to Payment
              </Button>
            </form>
          </Card>
        </div>
      </div>
    </div>
  );
}
