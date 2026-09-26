---
name: Fiscal Utility Teal
colors:
  surface: '#f9f9ff'
  surface-dim: '#d3daea'
  surface-bright: '#f9f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f0f3ff'
  surface-container: '#e7eefe'
  surface-container-high: '#e2e8f8'
  surface-container-highest: '#dce2f3'
  on-surface: '#151c27'
  on-surface-variant: '#434655'
  inverse-surface: '#2a313d'
  inverse-on-surface: '#ebf1ff'
  outline: '#737686'
  outline-variant: '#c3c6d7'
  surface-tint: '#0053db'
  primary: '#004ac6'
  on-primary: '#ffffff'
  primary-container: '#2563eb'
  on-primary-container: '#eeefff'
  inverse-primary: '#b4c5ff'
  secondary: '#1d695d'
  on-secondary: '#ffffff'
  secondary-container: '#a5eedd'
  on-secondary-container: '#236e61'
  tertiary: '#006242'
  on-tertiary: '#ffffff'
  tertiary-container: '#007d55'
  on-tertiary-container: '#bdffdb'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dbe1ff'
  primary-fixed-dim: '#b4c5ff'
  on-primary-fixed: '#00174b'
  on-primary-fixed-variant: '#003ea8'
  secondary-fixed: '#a8f0e0'
  secondary-fixed-dim: '#8dd4c4'
  on-secondary-fixed: '#00201b'
  on-secondary-fixed-variant: '#005046'
  tertiary-fixed: '#6ffbbe'
  tertiary-fixed-dim: '#4edea3'
  on-tertiary-fixed: '#002113'
  on-tertiary-fixed-variant: '#005236'
  background: '#f9f9ff'
  on-background: '#151c27'
  surface-variant: '#dce2f3'
  header-teal-deep: '#004D40'
  header-teal: '#005A4E'
  danger-red: '#EF4444'
  canvas-bg: '#F9FAFB'
  surface-white: '#FFFFFF'
  text-dark: '#1F2937'
  text-muted: '#9CA3AF'
  border-subtle: '#E5E7EB'
  surface-neutral-tint: '#F3F4F6'
  warning-amber: '#F59E0B'
typography:
  headline-xl:
    fontFamily: Space Grotesk
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  headline-xl-mobile:
    fontFamily: Space Grotesk
    fontSize: 26px
    fontWeight: '700'
    lineHeight: 34px
  headline-lg:
    fontFamily: Space Grotesk
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  headline-md:
    fontFamily: Space Grotesk
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 26px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  currency-display:
    fontFamily: Space Mono
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
  currency-md:
    fontFamily: Space Mono
    fontSize: 16px
    fontWeight: '700'
    lineHeight: 22px
  label-sm:
    fontFamily: Space Mono
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-tablet: 1.5rem
  margin: 1rem
  margin-tablet: 2rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

The design system establishes a high-trust, utilitarian personal and family finance interface tailored for cross-channel tracking (manual entry, SMS auto-parsing, OCR bill extraction, and shared expense splitting). 

The visual style combines **Corporate / Modern FinTech** precision with **functional utility**:
- **Demeanor**: Authoritative, disciplined, transparent, and uncluttered.
- **Visual Structure**: Anchor surfaces are anchored by an authoritative deep teal bar across the top navigation framing, transitioning down to soft neutral canvases (`#F9FAFB`) and crisp, elevated white card modules.
- **Information Architecture**: Clear numeric dominance. Monetary figures, balances, and confidence scores are immediately scan-friendly and distinct from narrative categories and metadata.
- **Emotional Intent**: Removing stress from budgeting and complex split reconciliation through reassuring green positive indicators, decisive expense alerts, and accessible layout rhythms.

## Colors

The color hierarchy separates structural branding from functional transactions:

- **Primary Interactive (`#2563EB`)**: Drives primary calls to action, active navigation affordances, FAB highlights, toggles, and critical flow progressions.
- **Secondary Branding (`#005A4E` / `#004D40`)**: Serves as the signature structural cap, grounding top app bars, primary balance headers, and major screen titles.
- **Tertiary & Semantics**:
  - **Success / Income (`#10B981`)**: Positively accents incoming cash flows, auto-categorized OCR items, active SMS sync statuses, and settled debts.
  - **Expense / Danger (`#EF4444`)**: Accents outgoing transactions, high-variance alerts, unlinked bills, deletion triggers, and debt arrears.
  - **Warning / Review (`#F59E0B`)**: Used for borderline OCR parses and unconfirmed recurring payments.
- **Neutrals & Surfaces**:
  - Canvas backdrops leverage `#F9FAFB` to distinguish boundary edges against `#FFFFFF` elevated cards.
  - Text maintains crisp legibility using `#1F2937` for primary titles and metrics, with `#6B7280` and `#9CA3AF` assigned to secondary descriptions and metadata.
  - Borders rely on `#E5E7EB` for low-noise structure.

## Typography

The type system implements a deliberate structural division:
- **Headings (`Space Grotesk`)**: Geometric, structured, and modern display characteristics that command clarity in headers, modal banners, and major aggregate summary sections.
- **Interface & Text (`Inter`)**: A utilitarian workhorse engineered for maximum legibility in multi-language context, form fields, descriptions, and list item structures.
- **Numeric & Monetary Ledger (`Space Mono`)**: Dedicated monospaced tabular figures applied to all currency amounts (`₨`, `$`), transaction logs, tax lines, and confidence metrics. This ensures numbers align vertically without jitter, allowing users to scan balance totals instantaneously.

## Layout & Spacing

The layout model is based on an **8px rhythmic baseline** within a fluid grid framework designed mobile-first:

- **Mobile Canvas (< 600px)**: 
  - Standard edge margin of `16px` (`margin`).
  - Gutter spacing of `16px` (`gutter`) between sequential stacked cards.
  - Safe-area insets at the top (under the deep teal status bar) and bottom (behind the 56px sticky navigation tab bar).
- **Tablet & Split Panes (600px – 1200px)**:
  - Margins expand to `32px` (`margin-tablet`).
  - Two-column grid reflow for analytics, statement preview tables, and account lists with a `24px` column gutter (`gutter-tablet`).
- **Touch Target Integrity**: Every clickable control (buttons, toggles, icon triggers, list item action zones) strictly conforms to a minimum floor of `44×44px` on mobile, scaling to `48×48px` on larger tablets.

## Elevation & Depth

Visual hierarchy utilizes a balance of crisp surface boundaries and ambient low-contrast diffusion:

- **Base Flat Surface**: Screen canvas utilizes flat `#F9FAFB` with zero elevation.
- **Elevation 1 (Cards, Account Modules, Row Groups)**:
  - Shadow: `0 2px 4px rgba(0, 0, 0, 0.05)`
  - Outlines: `1px solid #E5E7EB` to maintain contrast separation when rendered against light backgrounds.
- **Elevation 2 (Floating Summaries, Active Cards, Sticky Bars)**:
  - Shadow: `0 4px 12px rgba(0, 0, 0, 0.10)`
  - Used for persistent balance headers, dropdown popovers, and elevated action trays.
- **Elevation 3 (Floating Action Button / FAB)**:
  - Shadow: `0 8px 24px rgba(37, 99, 235, 0.30)`
  - Creates a distinct focal point hovering above the bottom tab navigation.
- **Overlay & Sheets**:
  - Full-screen modal sheets feature semi-opaque black scrims (`rgba(0, 0, 0, 0.40)`) with cards sliding upwards via linear vertical displacement.

## Shapes

The geometric framework follows a predictable 3-tier corner radius rhythm:

- **Form Controls & Inputs (`4px`)**: Text fields, numeric amount boxes, dropdown triggers, and filter chips use minimal 4px roundedness to preserve functional density and structured form alignments.
- **Buttons & Interactive Tags (`8px`)**: Primary action buttons, file import zones, and secondary modal triggers use 8px corners.
- **Cards & Surface Containers (`12px`)**: Standard transaction lists, budget cards, and recurring item modules utilize 12px corners for a soft modern edge.
- **Circular Indicators (`50% / Pill`)**: User profile avatars, category icon container backgrounds (`40px` and `48px` circles), confidence score pills, and floating action buttons utilize full circular geometry.

## Components

### Buttons
- **Primary**: Solid `#2563EB` fill, white `#FFFFFF` text, `8px` corner radius, `48px` default height (`56px` for primary bottom action bars). Active state: `#1D4ED8`.
- **Secondary**: `#FFFFFF` background with `1px solid #E5E7EB` border, `#1F2937` text.
- **Danger / Destructive**: Light tint background (`rgba(239, 68, 68, 0.10)`) with `#EF4444` label, shifting to solid `#EF4444` with white text on explicit confirmation modals.
- **Minimum Tap Target**: Always constrained to `min-height: 44px; min-width: 44px`.

### Cards & Summary Modules
- Built on `#FFFFFF` surfaces with `12px` border radii and Elevation 1 (`0 2px 4px rgba(0,0,0,0.05)`).
- **Metric Cards**: Display title in `body-sm` (`#6B7280`), big metric value in `Space Mono` (`currency-display`), and trend chips (green/red) tucked at the top right.
- **Account Strip**: Horizontal scrolling row of cards (`160×120px`) with bank/wallet branding icon, account name, masked account number, and bold balance.

### Form Inputs & Dropdowns
- **Height**: Standard `44px` height.
- **Border**: `1px solid #E5E7EB` resting, shifting to `2px solid #2563EB` on focus, and `1px solid #EF4444` on validation error.
- **Background**: `#FFFFFF` with `#1F2937` input text and `#9CA3AF` placeholder text.
- **Currency Input**: Fixed prefix adornment (`₨` or `$`) rendered in `Space Mono`, right-aligned tabular digits.

### Transaction & List Rows
- **Row Heights**: `64px` for standard single-row transactions; `72px` when showing recurring metadata or SMS confidence badges.
- **Structure**: 
  - Left: `40px` circular icon container with category icon, tinted at 10% opacity matching category color.
  - Middle: Primary merchant/payee name in `body-md` (`font-weight: 500`), sub-row with date and account/category tags in `body-sm` (`#9CA3AF`).
  - Right: Tabular transaction amount rendered in `Space Mono` (`currency-md`). Income marked with `+` in `#10B981`; expenses marked with `-` in `#EF4444` (or `#1F2937`).

### Badges & Category Chips
- **Pills**: Height `24px`, horizontal padding `8px`, border radius `12px`.
- **Success / Confirmed**: Background `rgba(16, 185, 129, 0.12)`, text `#10B981`.
- **Review / Pending**: Background `rgba(245, 158, 11, 0.12)`, text `#D97706`.
- **Expense / Rejected**: Background `rgba(239, 68, 68, 0.12)`, text `#EF4444`.

### Top Structural Bar & Bottom Tab Navigation
- **Top Header Bar**: Solid deep teal background (`#005A4E`), white `#FFFFFF` title text (`headline-md`), and circular utility actions (search, profile avatar initials).
- **Bottom Tab Bar**: Height `56px`, background `#FFFFFF`, top border `1px solid #E5E7EB`. Contains 5 primary destinations (Dashboard, Accounts, Splits, Family, Settings) with active tab highlighted in `#2563EB` and centered FAB trigger docked into the tab line.