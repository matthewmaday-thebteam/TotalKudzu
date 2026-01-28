import { createContext, useContext, useState, useEffect, useCallback } from 'react';
import type { OnboardingFormData, PlanTier } from '../types/onboarding';

const STORAGE_KEY = 'totalkudzu_onboarding';

const defaultFormData: OnboardingFormData = {
  companyName: '',
  hqOfficeName: '',
  hqOfficeTimezone: Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC',
  hqOfficeCountryCode: '',
  planTier: 'starter_10',
};

interface OnboardingContextType {
  formData: OnboardingFormData;
  updateFormData: (updates: Partial<OnboardingFormData>) => void;
  clearOnboarding: () => void;
  isValid: boolean;
}

const OnboardingContext = createContext<OnboardingContextType | undefined>(undefined);

export function OnboardingProvider({ children }: { children: React.ReactNode }) {
  const [formData, setFormData] = useState<OnboardingFormData>(() => {
    // Hydrate from sessionStorage on mount
    try {
      const stored = sessionStorage.getItem(STORAGE_KEY);
      if (stored) {
        const parsed = JSON.parse(stored) as OnboardingFormData;
        return { ...defaultFormData, ...parsed };
      }
    } catch {
      // Ignore parse errors
    }
    return defaultFormData;
  });

  // Persist to sessionStorage on every change
  useEffect(() => {
    try {
      sessionStorage.setItem(STORAGE_KEY, JSON.stringify(formData));
    } catch {
      // Ignore storage errors
    }
  }, [formData]);

  const updateFormData = useCallback((updates: Partial<OnboardingFormData>) => {
    setFormData(prev => ({ ...prev, ...updates }));
  }, []);

  const clearOnboarding = useCallback(() => {
    try {
      sessionStorage.removeItem(STORAGE_KEY);
    } catch {
      // Ignore storage errors
    }
    setFormData(defaultFormData);
  }, []);

  // Validation
  const isValid =
    formData.companyName.trim().length >= 2 &&
    formData.hqOfficeName.trim().length >= 2 &&
    formData.hqOfficeTimezone.length > 0 &&
    formData.hqOfficeCountryCode.length === 2;

  return (
    <OnboardingContext.Provider
      value={{
        formData,
        updateFormData,
        clearOnboarding,
        isValid,
      }}
    >
      {children}
    </OnboardingContext.Provider>
  );
}

export function useOnboarding() {
  const context = useContext(OnboardingContext);
  if (context === undefined) {
    throw new Error('useOnboarding must be used within an OnboardingProvider');
  }
  return context;
}

// Helper function to get plan tier display info
export function getPlanDisplayInfo(planTier: PlanTier) {
  if (planTier === 'unlimited') {
    return { name: 'Unlimited', price: 100, maxUsers: 'Unlimited' };
  }
  return { name: 'Starter', price: 50, maxUsers: '10' };
}
