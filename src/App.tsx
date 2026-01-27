import { useState } from 'react';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import { MainHeader, type NavRoute } from './components/MainHeader';
import { Spinner } from './components/Spinner';
import { UsersPage } from './components/pages/UsersPage';
import { LoginPage } from './components/pages/LoginPage';
import { ForgotPasswordPage } from './components/pages/ForgotPasswordPage';
import { ResetPasswordPage } from './components/pages/ResetPasswordPage';

type AuthView = 'login' | 'forgot-password' | 'reset-password';

function AuthenticatedApp() {
  const [activeRoute, setActiveRoute] = useState<NavRoute>('home');

  const renderPage = () => {
    switch (activeRoute) {
      case 'home':
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
    <div className="min-h-screen bg-vercel-gray-50">
      <MainHeader
        activeRoute={activeRoute}
        onRouteChange={setActiveRoute}
      />
      {renderPage()}
    </div>
  );
}

// Compute initial auth view from URL path
function getInitialAuthView(): AuthView {
  if (window.location.pathname === '/reset-password') {
    return 'reset-password';
  }
  return 'login';
}

function UnauthenticatedApp() {
  const { isRecoverySession } = useAuth();
  const [authView, setAuthView] = useState<AuthView>(getInitialAuthView);

  const handleResetComplete = () => {
    // Clear the URL path
    window.history.replaceState({}, '', '/');
    setAuthView('login');
  };

  // Derive effective view - recovery session takes precedence
  const effectiveView = isRecoverySession ? 'reset-password' : authView;

  if (effectiveView === 'reset-password') {
    return <ResetPasswordPage onComplete={handleResetComplete} />;
  }

  if (effectiveView === 'forgot-password') {
    return <ForgotPasswordPage onBackToLogin={() => setAuthView('login')} />;
  }

  return <LoginPage onForgotPassword={() => setAuthView('forgot-password')} />;
}

function AppContent() {
  const { user, loading, isRecoverySession } = useAuth();

  if (loading) {
    return (
      <div className="min-h-screen bg-vercel-gray-50 flex items-center justify-center">
        <div className="flex items-center gap-3">
          <Spinner size="md" />
          <span className="text-sm text-vercel-gray-400">Loading...</span>
        </div>
      </div>
    );
  }

  // Show reset password page if in recovery session, even if user is logged in
  if (isRecoverySession || window.location.pathname === '/reset-password') {
    return <UnauthenticatedApp />;
  }

  if (!user) {
    return <UnauthenticatedApp />;
  }

  return <AuthenticatedApp />;
}

function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  );
}

export default App;
