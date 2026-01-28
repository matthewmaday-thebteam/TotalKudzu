import { HighKeyBackground } from '../../design-system/patterns/HighKeyBackground';
import { Card } from '../Card';
import { Button } from '../Button';
import { Alert } from '../Alert';

interface BillingPageProps {
  onSignOut: () => void;
}

export function BillingPage({ onSignOut }: BillingPageProps) {
  return (
    <div className="min-h-screen relative">
      <HighKeyBackground />

      <div className="relative z-10 min-h-screen flex items-center justify-center p-4">
        <div className="w-full max-w-md">
          <Card variant="elevated" padding="lg">
            {/* Warning Icon */}
            <div className="flex justify-center mb-6">
              <div className="w-16 h-16 bg-warning-light rounded-full flex items-center justify-center">
                <svg className="w-8 h-8 text-warning" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                </svg>
              </div>
            </div>

            {/* Header */}
            <div className="text-center mb-6">
              <h1 className="text-2xl font-semibold text-vercel-gray-600">Billing Issue</h1>
              <p className="text-sm text-vercel-gray-400 mt-2">
                Your account access has been restricted
              </p>
            </div>

            {/* Alert */}
            <div className="mb-6">
              <Alert
                message="Please update your payment method to continue using TotalKudzu."
                variant="warning"
                icon="warning"
              />
            </div>

            {/* Info */}
            <div className="p-4 bg-vercel-gray-50 rounded-lg mb-6">
              <p className="text-sm text-vercel-gray-400">
                This page is a placeholder. In a future update, you'll be able to:
              </p>
              <ul className="mt-2 space-y-1 text-sm text-vercel-gray-400">
                <li>&middot; Update your payment method</li>
                <li>&middot; View billing history</li>
                <li>&middot; Change your plan</li>
              </ul>
            </div>

            {/* Actions */}
            <div className="space-y-3">
              <Button
                type="button"
                variant="primary"
                size="lg"
                className="w-full"
                disabled
              >
                Update Payment Method (Coming Soon)
              </Button>

              <Button
                type="button"
                variant="ghost"
                size="md"
                className="w-full"
                onClick={onSignOut}
              >
                Sign Out
              </Button>
            </div>
          </Card>
        </div>
      </div>
    </div>
  );
}
