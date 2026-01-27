/**
 * HighKeyBackground - Approved Global Pattern
 *
 * A premium, high-key minimalist background inspired by AWS IoT Core.
 * Features 'barely there' animated pastels with organic fluid motion.
 * Designed to feel like sunlight hitting a pearl—calm, expensive, professional.
 *
 * @approved 2026-01-27
 * @category Global Pattern
 *
 * Usage:
 *   <HighKeyBackground />
 *   // Place as first child of layout, siblings should have relative positioning
 *
 * DO:
 *   - Use as a global background behind all content
 *   - Ensure content above has `position: relative` and z-index > 0
 *   - Keep the default nearly-white pastels for premium feel
 *
 * DON'T:
 *   - Override colors with saturated values (breaks the high-key aesthetic)
 *   - Use inside scrollable containers
 *   - Nest multiple instances
 */

import './HighKeyBackground.css';

interface HighKeyBackgroundProps {
  /** Optional className for additional styling */
  className?: string;
  /** Blur intensity in pixels (default: 140) */
  blur?: number;
  /** Opacity of blobs 0-1 (default: 0.18) */
  opacity?: number;
  /** Duration multiplier (default: 1) - higher = slower */
  durationMultiplier?: number;
}

export function HighKeyBackground({
  className = '',
  blur = 140,
  opacity = 0.85,
  durationMultiplier = 1,
}: HighKeyBackgroundProps) {
  const style = {
    '--highkey-blur': `${blur}px`,
    '--highkey-opacity': opacity,
    '--highkey-duration-1': `${25 * durationMultiplier}s`,
    '--highkey-duration-2': `${35 * durationMultiplier}s`,
    '--highkey-duration-3': `${45 * durationMultiplier}s`,
  } as React.CSSProperties;

  return (
    <div
      className={`highkey-background ${className}`}
      style={style}
      aria-hidden="true"
    >
      <div className="highkey-blob highkey-blob-1" />
      <div className="highkey-blob highkey-blob-2" />
      <div className="highkey-blob highkey-blob-3" />
      <div className="highkey-noise" />
    </div>
  );
}

export default HighKeyBackground;
