/**
 * Chart Data Transformers
 *
 * Utility functions to transform application data into chart-ready formats.
 *
 * @official 2026-01-11
 * @category Utils
 */

import type {
  PieChartDataPoint,
  LineGraphDataPoint,
} from '../types/charts';
import { ANNUAL_BUDGET, TARGET_RATIO } from '../config/chartConfig';

/**
 * Generate mock line chart data for preview/testing.
 * Shows cumulative values with revenue extending as flat line into future months.
 *
 * @param annualBudget - Annual budget (default: $1M)
 * @param targetRatio - Target multiplier (default: 1.8x)
 * @param monthsWithData - Number of months with actual revenue data (default: current month)
 * @returns Array of 12 line graph data points with cumulative values
 */
export function generateMockLineData(
  annualBudget: number = ANNUAL_BUDGET,
  targetRatio: number = TARGET_RATIO,
  monthsWithData: number = new Date().getMonth() + 1
): LineGraphDataPoint[] {
  const annualTarget = annualBudget * targetRatio;
  const monthlyTarget = annualTarget / 12;
  const monthlyBudget = annualBudget / 12;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  // Seed-based pseudo-random for consistent preview
  const seededRandom = (seed: number) => {
    const x = Math.sin(seed * 9999) * 10000;
    return x - Math.floor(x);
  };

  let cumulativeRevenue = 0;
  const avgMonthlyRevenue = monthlyBudget * 0.9; // Mock average

  return months.map((month, index) => {
    // Cumulative target and budget
    const cumulativeTarget = Math.round(monthlyTarget * (index + 1));
    const cumulativeBudget = Math.round(monthlyBudget * (index + 1));

    // Generate monthly revenue with some variance for months with actual data
    if (index < monthsWithData) {
      const monthlyRevenue = monthlyBudget * (0.85 + seededRandom(index) * 0.15);
      cumulativeRevenue += monthlyRevenue;
    }
    // For future months, cumulativeRevenue stays at last earned value (flat line)

    // Calculate projections for future months
    let bestCase: number | null = null;
    let worstCase: number | null = null;

    if (index >= monthsWithData) {
      const monthsAhead = index - monthsWithData + 1;
      bestCase = Math.round(cumulativeRevenue + (monthsAhead * avgMonthlyRevenue * 1.2));
      worstCase = Math.round(cumulativeRevenue + (monthsAhead * avgMonthlyRevenue * 0.8));
    }

    return {
      month,
      target: cumulativeTarget,
      budget: cumulativeBudget,
      revenue: Math.round(cumulativeRevenue),
      bestCase,
      worstCase,
    };
  });
}

/**
 * Generate mock pie chart data for preview/testing.
 *
 * @returns Array of pie chart data points
 */
export function generateMockPieData(): PieChartDataPoint[] {
  return [
    { name: 'Kalin Tomanov', value: 42.5 },
    { name: 'Milen Anastasov', value: 38.0 },
    { name: 'Matthew Maday', value: 32.5 },
    { name: 'Ivan Petrov', value: 24.0 },
    { name: 'Other', value: 18.0, color: 'other' },
  ];
}
