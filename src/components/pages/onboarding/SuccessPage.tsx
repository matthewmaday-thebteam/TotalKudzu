import { format } from 'date-fns';
import { useOnboarding, getPlanDisplayInfo } from '../../../contexts/OnboardingContext';
import { HighKeyBackground } from '../../../design-system/patterns/HighKeyBackground';
import { Card } from '../../Card';
import { Button } from '../../Button';
import { Badge } from '../../Badge';
import type { OnboardingCompleteResponse } from '../../../types/onboarding';

interface SuccessPageProps {
  data: OnboardingCompleteResponse;
  onGoToApp: () => void;
}

export function SuccessPage({ data, onGoToApp }: SuccessPageProps) {
  const { formData, clearOnboarding } = useOnboarding();
  const planInfo = getPlanDisplayInfo(data.plan_tier);

  const trialEndDate = new Date(data.trial_ends_at);
  const formattedEndDate = format(trialEndDate, 'MMMM d, yyyy');

  const handleGoToApp = () => {
    clearOnboarding();
    onGoToApp();
  };

  return (
    <div className="min-h-screen relative">
      <HighKeyBackground />

      <div className="relative z-10 min-h-screen flex items-center justify-center p-4">
        <div className="w-full max-w-md">
          <Card variant="elevated" padding="lg">
            {/* Success Icon */}
            <div className="flex justify-center mb-6">
              <div className="w-16 h-16 bg-success-light rounded-full flex items-center justify-center">
                <svg className="w-8 h-8 text-success" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                </svg>
              </div>
            </div>

            {/* Header */}
            <div className="text-center mb-8">
              <h1 className="text-2xl font-semibold text-vercel-gray-600">Trial Started!</h1>
              <p className="text-sm text-vercel-gray-400 mt-2">
                Welcome to TotalKudzu, {formData.companyName}
              </p>
            </div>

            {/* Summary */}
            <div className="space-y-4 mb-8">
              {/* Plan Badge */}
              <div className="flex justify-center">
                <Badge variant="success" size="md">
                  {planInfo.name} Plan
                </Badge>
              </div>

              {/* Details */}
              <div className="p-4 bg-vercel-gray-50 rounded-lg space-y-3">
                <div className="flex justify-between items-center">
                  <span className="text-sm text-vercel-gray-400">Status</span>
                  <Badge variant="info">Trialing</Badge>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-vercel-gray-400">Trial Ends</span>
                  <span className="text-sm font-medium text-vercel-gray-600">{formattedEndDate}</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-vercel-gray-400">Monthly Price</span>
                  <span className="text-sm font-medium text-vercel-gray-600">${planInfo.price}/mo</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-vercel-gray-400">Users</span>
                  <span className="text-sm font-medium text-vercel-gray-600">{planInfo.maxUsers}</span>
                </div>
              </div>

              {/* Next Steps */}
              <div className="p-4 border border-vercel-gray-100 rounded-lg">
                <div className="text-xs font-medium text-vercel-gray-400 uppercase tracking-wider mb-3">
                  Next Steps
                </div>
                <ul className="space-y-2">
                  <li className="flex items-start gap-2 text-sm text-vercel-gray-600">
                    <span className="text-vercel-gray-300">1.</span>
                    <span>Explore your dashboard</span>
                  </li>
                  <li className="flex items-start gap-2 text-sm text-vercel-gray-600">
                    <span className="text-vercel-gray-300">2.</span>
                    <span>Invite team members</span>
                  </li>
                  <li className="flex items-start gap-2 text-sm text-vercel-gray-600">
                    <span className="text-vercel-gray-300">3.</span>
                    <span>Configure leave policies</span>
                  </li>
                </ul>
              </div>
            </div>

            {/* Action */}
            <Button
              type="button"
              variant="primary"
              size="lg"
              className="w-full"
              onClick={handleGoToApp}
            >
              Go to Dashboard
            </Button>
          </Card>
        </div>
      </div>
    </div>
  );
}
