# TotalKudzu - Style Guide

**Version:** 1.0.0
**Last Updated:** 2026-01-27
**Status:** ENFORCED

This document is the mandatory source of truth for all UI development. Claude Code MUST reference this guide before implementing any UI changes.

---

## Table of Contents

1. [Design Tokens](#design-tokens)
2. [Color System](#color-system)
3. [Typography](#typography)
4. [Spacing](#spacing)
5. [Component Library](#component-library)
6. [Enforcement Rules](#enforcement-rules)

---

## Design Tokens

### Token Configuration

Design tokens are defined in `src/index.css` using Tailwind CSS v4's `@theme` directive.

**Full Token Reference:**

```css
@theme {
  /* Vercel Gray Scale */
  --color-vercel-gray-50: #fafafa;
  --color-vercel-gray-100: #eaeaea;
  --color-vercel-gray-200: #999999;
  --color-vercel-gray-300: #888888;
  --color-vercel-gray-400: #666666;
  --color-vercel-gray-500: #333333;
  --color-vercel-gray-600: #000000;

  /* Semantic - Error */
  --color-error: #EE0000;
  --color-error-hover: #CC0000;
  --color-error-light: #FEF2F2;
  --color-error-border: #FECACA;
  --color-error-text: #DC2626;

  /* Semantic - Success */
  --color-success: #50E3C2;
  --color-success-light: #F0FDF4;
  --color-success-border: #BBF7D0;
  --color-success-text: #166534;

  /* Semantic - Warning */
  --color-warning: #F5A623;
  --color-warning-light: #FFF7ED;
  --color-warning-border: #FFEDD5;
  --color-warning-text: #9A3412;

  /* Semantic - Info */
  --color-info: #4338CA;
  --color-info-light: #EEF2FF;
  --color-info-border: #C7D2FE;

  /* Brand / Mesh Gradient */
  --color-brand-indigo: #667eea;
  --color-brand-purple: #764ba2;
  --color-mesh-1 through --color-mesh-4

  /* Typography */
  --font-size-2xs: 10px;
  --font-size-xs through --font-size-2xl

  /* Shadows */
  --shadow-vercel-dropdown, --shadow-modal, --shadow-elevated, --shadow-card

  /* Radius */
  --radius-sm through --radius-full
}
```

### Using Tokens

Always use token-based classes instead of arbitrary values:

```tsx
// DO: Use token classes
<div className="bg-vercel-gray-50 border-vercel-gray-100">

// DON'T: Use arbitrary values
<div className="bg-[#FAFAFA] border-[#EAEAEA]">
```

---

## Component Library

### Official Atoms

| Component | File | Status |
|-----------|------|--------|
| Avatar | `src/components/Avatar.tsx` | Official |
| AvatarUpload | `src/components/AvatarUpload.tsx` | Official |
| Select | `src/components/Select.tsx` | Official |
| Modal | `src/components/Modal.tsx` | Official |
| MetricCard | `src/components/MetricCard.tsx` | Official |
| DropdownMenu | `src/components/DropdownMenu.tsx` | Official |
| NavItem | `src/components/NavItem.tsx` | Official |
| **Button** | `src/components/Button.tsx` | **Official** |
| **Spinner** | `src/components/Spinner.tsx` | **Official** |
| **Input** | `src/components/Input.tsx` | **Official** |
| **Card** | `src/components/Card.tsx` | **Official** |
| **Badge** | `src/components/Badge.tsx` | **Official** |
| **Toggle** | `src/components/Toggle.tsx` | **Official** |
| **Alert** | `src/components/Alert.tsx` | **Official** |

---

## Enforcement Rules

### Automated Enforcement

ESLint rules automatically enforce design token compliance:

```bash
# Check for design token violations
npm run lint:tokens

# Full CI check (TypeScript + token linting)
npm run ci:check
```

**CI Pipeline:** Vercel builds automatically run `npm run ci:check` before build. Deployments will **fail** if arbitrary hex colors are detected.

### Prohibited Patterns

The following are NOT allowed without explicit approval:

1. **Arbitrary Tailwind Values**
   - `text-[#RRGGBB]`
   - `bg-[#RRGGBB]`
   - `border-[#RRGGBB]`

2. **Inline Styles**
   - `style={{ color: '#...' }}`
   - `style={{ backgroundColor: '#...' }}`
   - Exception: Dynamic positioning (dropdown/modal placement)

3. **Raw HTML Elements**
   - Raw `<button>` where `Button` component exists
   - Raw `<input>` where `Input` component exists
   - Raw "card-like" `<div>` patterns
