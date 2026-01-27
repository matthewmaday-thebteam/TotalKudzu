import { useState } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import { Button } from '../Button';
import { Input } from '../Input';
import { Spinner } from '../Spinner';
import { HighKeyBackground } from '../../design-system/patterns/HighKeyBackground';

interface ForgotPasswordPageProps {
  onBackToLogin: () => void;
}

export function ForgotPasswordPage({ onBackToLogin }: ForgotPasswordPageProps) {
  const { sendPasswordResetEmail } = useAuth();
  const [email, setEmail] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsLoading(true);

    const { error } = await sendPasswordResetEmail(email);

    if (error) {
      setError(error.message);
    } else {
      setIsSuccess(true);
    }
    setIsLoading(false);
  };

  if (isSuccess) {
    return (
      <div className="min-h-screen relative">
        <HighKeyBackground />

        <div className="relative z-10 min-h-screen flex items-center justify-center p-4">
          <div className="w-full max-w-sm">
            <div className="bg-white rounded-xl p-8" style={{ boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)' }}>
              {/* Success Icon */}
              <div className="flex justify-center mb-6">
                <div className="w-16 h-16 rounded-full bg-success-light flex items-center justify-center">
                  <svg className="w-8 h-8 text-success" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                </div>
              </div>

              {/* Success Message */}
              <div className="text-center mb-8">
                <h1 className="text-2xl font-semibold text-vercel-gray-600">Check Your Email</h1>
                <p className="text-sm text-vercel-gray-400 mt-2">
                  We've sent a password reset link to <span className="font-medium text-vercel-gray-600">{email}</span>
                </p>
              </div>

              {/* Back to Login */}
              <Button
                type="button"
                variant="secondary"
                className="w-full"
                onClick={onBackToLogin}
              >
                Back to Sign In
              </Button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen relative">
      <HighKeyBackground />

      <div className="relative z-10 min-h-screen flex items-center justify-center p-4">
        <div className="w-full max-w-sm">
          {/* Card */}
          <div className="bg-white rounded-xl p-8" style={{ boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)' }}>
            {/* Header */}
            <div className="text-center mb-8">
              <h1 className="text-2xl font-semibold text-vercel-gray-600">Reset Password</h1>
              <p className="text-sm text-vercel-gray-400 mt-2">
                Enter your email address and we'll send you a link to reset your password.
              </p>
            </div>

            {/* Error Message */}
            {error && (
              <div className="mb-6 p-3 bg-error-light border border-error rounded-lg">
                <div className="flex items-center gap-2">
                  <svg className="w-4 h-4 text-error" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  <span className="text-sm text-error">{error}</span>
                </div>
              </div>
            )}

            {/* Form */}
            <form onSubmit={handleSubmit} className="space-y-6">
              <div>
                <label className="block text-xs font-medium text-vercel-gray-400 uppercase tracking-wider mb-2">
                  Email Address
                </label>
                <Input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@example.com"
                  disabled={isLoading}
                  autoComplete="email"
                />
              </div>

              <Button
                type="submit"
                variant="primary"
                className="w-full"
                disabled={isLoading || !email}
              >
                {isLoading ? (
                  <span className="flex items-center justify-center gap-2">
                    <Spinner size="sm" color="white" />
                    Sending...
                  </span>
                ) : (
                  'Send Reset Link'
                )}
              </Button>
            </form>

            {/* Back to Login Link */}
            <div className="mt-6 text-center">
              <button
                type="button"
                onClick={onBackToLogin}
                className="text-sm text-vercel-gray-400 hover:text-vercel-gray-600 transition-colors focus:outline-none focus:underline"
              >
                Back to Sign In
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
