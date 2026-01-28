import { useState } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import { supabase } from '../../lib/supabase';
import { Button } from '../Button';
import { Input } from '../Input';
import { Spinner } from '../Spinner';
import { Alert } from '../Alert';
import { HighKeyBackground } from '../../design-system/patterns/HighKeyBackground';

type AuthMode = 'signin' | 'signup';

interface AuthPageProps {
  onForgotPassword: () => void;
  onSuccess: () => void;
}

export function AuthPage({ onForgotPassword, onSuccess }: AuthPageProps) {
  const { signIn } = useAuth();
  const [mode, setMode] = useState<AuthMode>('signin');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [fullName, setFullName] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsLoading(true);

    try {
      if (mode === 'signup') {
        // Sign up with Supabase
        const { data, error: signUpError } = await supabase.auth.signUp({
          email,
          password,
          options: {
            data: {
              full_name: fullName.trim() || null,
            },
          },
        });

        if (signUpError) {
          setError(signUpError.message);
          setIsLoading(false);
          return;
        }

        // If email confirmation is required, show message
        if (data.user && !data.session) {
          setError('Please check your email to confirm your account.');
          setIsLoading(false);
          return;
        }

        // Auto sign-in after signup
        if (data.session) {
          onSuccess();
        }
      } else {
        // Sign in
        const { error: signInError } = await signIn(email, password);
        if (signInError) {
          setError(signInError.message);
          setIsLoading(false);
          return;
        }
        onSuccess();
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setIsLoading(false);
    }
  };

  const toggleMode = () => {
    setMode(mode === 'signin' ? 'signup' : 'signin');
    setError(null);
  };

  return (
    <div className="min-h-screen relative">
      <HighKeyBackground />

      <div className="relative z-10 min-h-screen flex items-center justify-center p-4">
        <div className="w-full max-w-sm">
          <div className="bg-white rounded-xl p-8" style={{ boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)' }}>
            {/* Header */}
            <div className="text-center mb-8">
              <h1 className="text-2xl font-semibold text-vercel-gray-600">TotalKudzu</h1>
              <p className="text-sm text-vercel-gray-400 mt-2">
                {mode === 'signin' ? 'Sign in to your account' : 'Create your account'}
              </p>
            </div>

            {/* Error Message */}
            {error && (
              <div className="mb-6">
                <Alert
                  message={error}
                  variant={error.includes('check your email') ? 'default' : 'error'}
                  icon={error.includes('check your email') ? 'info' : 'error'}
                />
              </div>
            )}

            {/* Form */}
            <form onSubmit={handleSubmit} className="space-y-6">
              {mode === 'signup' && (
                <Input
                  label="Full Name"
                  type="text"
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  placeholder="John Doe"
                  disabled={isLoading}
                  autoComplete="name"
                />
              )}

              <Input
                label="Email Address"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@example.com"
                disabled={isLoading}
                autoComplete="email"
              />

              <Input
                label="Password"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder={mode === 'signup' ? 'Create a password' : 'Enter your password'}
                disabled={isLoading}
                autoComplete={mode === 'signin' ? 'current-password' : 'new-password'}
              />

              <Button
                type="submit"
                variant="primary"
                className="w-full"
                disabled={isLoading || !email || !password}
              >
                {isLoading ? (
                  <span className="flex items-center justify-center gap-2">
                    <Spinner size="sm" color="white" />
                    {mode === 'signin' ? 'Signing in...' : 'Creating account...'}
                  </span>
                ) : (
                  mode === 'signin' ? 'Sign In' : 'Create Account'
                )}
              </Button>
            </form>

            {/* Toggle Mode */}
            <div className="mt-6 text-center">
              <button
                type="button"
                onClick={toggleMode}
                className="text-sm text-vercel-gray-400 hover:text-vercel-gray-600 transition-colors focus:outline-none focus:underline"
              >
                {mode === 'signin'
                  ? "Don't have an account? Sign up"
                  : 'Already have an account? Sign in'}
              </button>
            </div>

            {/* Forgot Password (sign-in only) */}
            {mode === 'signin' && (
              <div className="mt-4 text-center">
                <button
                  type="button"
                  onClick={onForgotPassword}
                  className="text-sm text-vercel-gray-300 hover:text-vercel-gray-400 transition-colors focus:outline-none focus:underline"
                >
                  Forgot your password?
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
