import { useState, useEffect } from 'react';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import { OnboardingProvider } from './contexts/OnboardingContext';
import { useMembership } from './hooks/useMembership';
import { MainHeader, type NavRoute } from './components/MainHeader';
import { Spinner } from './components/Spinner';
import { Badge } from './components/Badge';
import { UsersPage } from './components/pages/UsersPage';
import { AuthPage } from './components/pages/AuthPage';
import { ForgotPasswordPage } from './components/pages/ForgotPasswordPage';
import { ResetPasswordPage } from './components/pages/ResetPasswordPage';
import { BillingPage } from './components/pages/BillingPage';
import { CompanyPage } from './components/pages/onboarding/CompanyPage';
import { PaymentPage } from './components/pages/onboarding/PaymentPage';
import { SuccessPage } from './components/pages/onboarding/SuccessPage';
import { StyleReviewPage } from './design-system/style-review/StyleReviewPage';
import { HighKeyBackground } from './design-system/patterns/HighKeyBackground';
import type { OnboardingCompleteResponse } from './types/onboarding';
import { format } from 'date-fns';

type AuthView = 'auth' | 'forgot-password' | 'reset-password';
type OnboardingStep = 'company' | 'payment' | 'success';

function AuthenticatedApp() {
  const { signOut } = useAuth();
  const { membership, billing, loading: membershipLoading, refetch } = useMembership();
  const [activeRoute, setActiveRoute] = useState<NavRoute>('home');
  const [onboardingStep, setOnboardingStep] = useState<OnboardingStep>('company');
  const [onboardingResult, setOnboardingResult] = useState<OnboardingCompleteResponse | null>(null);

  // If showing design system page, render it full-screen without header
  if (activeRoute === 'design-system') {
    return (
      <StyleReviewPage onClose={() => setActiveRoute('home')} />
    );
  }

  // Loading state while checking membership
  if (membershipLoading) {
    return (
      <div className="min-h-screen relative">
        <HighKeyBackground />
        <div className="relative z-10 min-h-screen flex items-center justify-center">
          <div className="flex items-center gap-3">
            <Spinner size="md" />
            <span className="text-sm text-vercel-gray-400">Loading your workspace...</span>
          </div>
        </div>
      </div>
    );
  }

  // No membership - show onboarding
  if (!membership) {
    if (onboardingStep === 'company') {
      return (
        <OnboardingProvider>
          <CompanyPage onContinue={() => setOnboardingStep('payment')} />
        </OnboardingProvider>
      );
    }

    if (onboardingStep === 'payment') {
      return (
        <OnboardingProvider>
          <PaymentPage
            onBack={() => setOnboardingStep('company')}
            onSuccess={(data) => {
              setOnboardingResult(data);
              setOnboardingStep('success');
            }}
          />
        </OnboardingProvider>
      );
    }

    if (onboardingStep === 'success' && onboardingResult) {
      return (
        <OnboardingProvider>
          <SuccessPage
            data={onboardingResult}
            onGoToApp={async () => {
              // Clear onboarding state
              setOnboardingResult(null);
              // Refetch membership - once this completes, the !membership check
              // will fail and the main app will be shown
              await refetch();
              // Reset step only after refetch completes (in case user needs to re-onboard later)
              setOnboardingStep('company');
            }}
          />
        </OnboardingProvider>
      );
    }
  }

  // Has membership but billing is restricted or canceled - show billing page
  if (billing && (billing.billing_status === 'restricted' || billing.billing_status === 'canceled')) {
    return <BillingPage onSignOut={signOut} />;
  }

  // Main app
  const renderPage = () => {
    switch (activeRoute) {
      case 'home':
        return (
          <div className="max-w-7xl mx-auto px-6 py-8">
            <div className="space-y-8">
              {/* Welcome Banner */}
              <div className="bg-white rounded-lg border border-vercel-gray-100 p-6">
                <div className="flex items-start justify-between">
                  <div>
                    <h1 className="text-2xl font-semibold text-vercel-gray-600">
                      Welcome to {membership?.company?.name || 'TotalKudzu'}
                    </h1>
                    <p className="text-sm text-vercel-gray-400 mt-1">
                      You are signed in as <span className="font-medium">{membership?.role}</span>
                    </p>
                  </div>
                  {billing && (
                    <div className="text-right">
                      <Badge
                        variant={billing.billing_status === 'trialing' ? 'info' : 'success'}
                        size="md"
                      >
                        {billing.billing_status === 'trialing' ? 'Trial' : billing.billing_status}
                      </Badge>
                      {billing.billing_status === 'trialing' && (
                        <p className="text-xs text-vercel-gray-400 mt-1">
                          Ends {format(new Date(billing.trial_ends_at), 'MMM d, yyyy')}
                        </p>
                      )}
                    </div>
                  )}
                </div>
              </div>

              {/* Placeholder Content */}
              <div className="bg-vercel-gray-50 rounded-lg p-8 text-center">
                <p className="text-sm text-vercel-gray-400">
                  Your application is ready. Start building your features here.
                </p>
              </div>
            </div>
          </div>
        );
      case 'users':
        return <UsersPage />;
      default:
        return (
          <div className="max-w-7xl mx-auto px-6 py-8">
            <div className="text-center py-16">
              <h1 className="text-2xl font-semibold text-vercel-gray-600 mb-4">
                Welcome to TotalKudzu
              </h1>
              <p className="text-sm text-vercel-gray-400">
                Your application is ready. Start building your features here.
              </p>
            </div>
          </div>
        );
    }
  };

  return (
    <div className="min-h-screen relative">
      <HighKeyBackground />
      <div className="relative z-10">
        <MainHeader
          activeRoute={activeRoute}
          onRouteChange={setActiveRoute}
        />
        {renderPage()}
      </div>
    </div>
  );
}

// Compute initial auth view from URL path
function getInitialAuthView(): AuthView {
  if (window.location.pathname === '/reset-password') {
    return 'reset-password';
  }
  return 'auth';
}

function UnauthenticatedApp({ onAuthSuccess }: { onAuthSuccess: () => void }) {
  const { isRecoverySession } = useAuth();
  const [authView, setAuthView] = useState<AuthView>(getInitialAuthView);

  const handleResetComplete = () => {
    // Clear the URL path
    window.history.replaceState({}, '', '/');
    setAuthView('auth');
  };

  // Derive effective view - recovery session takes precedence
  const effectiveView = isRecoverySession ? 'reset-password' : authView;

  if (effectiveView === 'reset-password') {
    return <ResetPasswordPage onComplete={handleResetComplete} />;
  }

  if (effectiveView === 'forgot-password') {
    return <ForgotPasswordPage onBackToLogin={() => setAuthView('auth')} />;
  }

  return (
    <AuthPage
      onForgotPassword={() => setAuthView('forgot-password')}
      onSuccess={onAuthSuccess}
    />
  );
}

function AppContent() {
  const { user, loading, isRecoverySession } = useAuth();
  const [authSucceeded, setAuthSucceeded] = useState(false);

  // Reset auth succeeded state when user changes
  useEffect(() => {
    if (!user) {
      setAuthSucceeded(false);
    }
  }, [user]);

  if (loading) {
    return (
      <div className="min-h-screen relative">
        <HighKeyBackground />
        <div className="relative z-10 min-h-screen flex items-center justify-center">
          <div className="flex items-center gap-3">
            <Spinner size="md" />
            <span className="text-sm text-vercel-gray-400">Loading...</span>
          </div>
        </div>
      </div>
    );
  }

  // Show reset password page if in recovery session, even if user is logged in
  if (isRecoverySession || window.location.pathname === '/reset-password') {
    return <UnauthenticatedApp onAuthSuccess={() => setAuthSucceeded(true)} />;
  }

  if (!user) {
    return <UnauthenticatedApp onAuthSuccess={() => setAuthSucceeded(true)} />;
  }

  return <AuthenticatedApp key={authSucceeded ? 'auth-success' : 'normal'} />;
}

function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  );
}

export default App;
