# Outlay Pro - Complete Design Package
**Version**: 1.0  
**Date**: 2026-09-26  
**Status**: Ready for Designer Review & Mockup Creation

---

## 📦 What's Included in This Package

This package contains everything needed for a designer to create high-fidelity mockups for Outlay Pro features:

1. ✅ **Design System Specifications** (colors, typography, components)
2. ✅ **9 New Screen Specifications** (detailed layouts, components, interactions)
3. ✅ **Existing App Screenshots** (current design baseline)
4. ✅ **Feature Descriptions** (pricing tiers, feature matrix)
5. ✅ **Implementation Timeline** (phase breakdown)

---

## 🎨 Design System Overview

### Brand Colors
```
Primary Blue:      #2563EB (Actions, primary buttons, highlights)
Success Green:     #10B981 (Income, positive balance, confirmations)
Danger Red:        #EF4444 (Expenses, warnings, deletions)
Gray Neutral:      #6B7280 (Secondary text, borders)
Light Background:  #F9FAFB (Page background, cards)
Dark Text:         #1F2937 (Headlines, primary text)
```

### Typography
- **Headings (H1)**: Poppins Bold, 24px, #1F2937
- **Subheadings (H2)**: Poppins Semibold, 18px, #1F2937
- **Body Text**: Inter Regular, 14px, #6B7280
- **Small Text**: Inter Regular, 12px, #9CA3AF
- **Numbers/Amounts**: Courier New (monospace), 16px, bold, #1F2937

### Key Components
- **Card Corner Radius**: 12px
- **Button Corner Radius**: 8px
- **Input Corner Radius**: 4px
- **Spacing Unit**: 8px (use multiples: 8, 16, 24, 32)
- **Shadow (Elevation 1)**: 0 2px 4px rgba(0,0,0,0.05)
- **Shadow (Elevation 2)**: 0 4px 12px rgba(0,0,0,0.1)

### Multi-Language Support
- 🇬🇧 English
- 🇵🇰 اردو (Urdu) - RTL
- 🇮🇳 हिंदी (Hindi)
- 🇸🇦 العربية (Arabic) - RTL
- 🇧🇩 বাংলা (Bengali)
- 🇮🇩 Bahasa Indonesia
- 🇻🇳 Tiếng Việt
- 🇵🇭 Filipino

---

## 📱 Existing App Screenshots (Current Design Baseline)

### Current Screens (Use as Reference):
1. **Dashboard Screen**
   - File: `docs/assets/screenshots/dashboard.png`
   - Components: Top navigation bar (teal background), month/year selector, balance display, income/expenses cards, budget wheel chart, recent transactions list
   - Navigation: Bottom tab bar (Dashboard, Transactions, Budgets, Reports)

2. **Transactions Screen**
   - File: `docs/assets/screenshots/transactions.png`
   - Components: Header with filter icon, date grouping ("JULY 2026"), transaction rows with icon, description, date, and amount
   - Color coding: Red (expenses), Green (income)
   - Navigation: Same bottom tab bar

3. **Budgets Screen**
   - File: `app_store_assets/ipad_13inch_screenshots/3_budgets.png`
   - Reference for budget UI patterns

4. **Reports Screen**
   - File: `app_store_assets/ipad_13inch_screenshots/4_reports.png`
   - Reference for reporting UI patterns

---

## 🚀 NEW FEATURES FOR OUTLAY PRO

### Feature Tiers

#### **FREE (Outlay Free)**
- Manual transaction entry
- **Event-based expense splits** ← **NEW HOOK FEATURE**
- Basic categorization
- Transaction history
- Simple reports

#### **PRO (₨299/month)**
- Everything in Free +
- ✨ **SMS Auto-Logging** ← **NEW**
- ✨ **Bank Statement Import (PDF/CSV)** ← **NEW**
- ✨ **Screenshot OCR** (JazzCash/EasyPaisa) ← **NEW**
- ✨ **Multi-Account Support** (up to 3 accounts) ← **NEW**
- ✨ **Recurring Transaction Detection** ← **NEW**
- ✨ **Tax Export** (CSV/PDF) ← **NEW**
- No ads

#### **MAX (₨599/month)**
- Everything in Pro +
- ✨ **Family Accounts** (5-10 members) ← **NEW**
- ✨ **Unlimited Accounts** ← **NEW**
- ✨ **Influencer Revenue Dashboard** ← **NEW**
- Priority support

---

## 📋 NEW SCREENS TO DESIGN (9 Total)

### 1. **Dashboard (Enhanced)**
**Changes from current**:
- Add: Total Balance card at top
- Add: Account cards row (scrollable, showing each account's balance)
- Add: "Recurring This Month" section
- Keep: Recent transactions list, budget chart
- Keep: Same bottom navigation

**Existing reference**: `docs/assets/screenshots/dashboard.png`

---

### 2. **SMS Auto-Logging Screen** ⭐
**Purpose**: Configure and monitor automatic SMS parsing

**Key Components**:
- SMS Permission toggle (green when active)
- "Active Banks" list showing:
  - HBL, UBL, MCB, Meezan, Faysal (bank logos)
  - JazzCash, EasyPaisa (wallet logos)
  - Green checkmark (SMS detected) or gray circle (waiting)
- "Captured This Week" statistics card
- Recent SMS transactions list (scrollable)
- Each transaction: Bank icon, amount, category, "Added Xh ago"
- Actions: Swipe to edit/delete

**Similar to current**: Use same card style as current app, but with SMS-specific content

---

### 3. **Bank Statement Import Screen** ⭐
**Purpose**: Upload and import bank statements

**Key Components**:
- Large drag-drop upload zone with cloud icon
- Text: "Drag PDF or CSV here" or "Tap to browse"
- Supported banks shown as icons (HBL, UBL, MCB, Meezan, Faysal)
- "Choose File" button (blue, prominent)
- Recent imports history (filename, date, status icon ✓/⚠/✗, transaction count)
- "Preview" button per import (shows table modal)

**Table Preview Modal**:
- Table: Date | Description | Category | Amount | Status
- Row colors: Green (auto-categorized), Yellow (needs review), Red (error)
- "Approve & Import" button (disabled if errors)

---

### 4. **Screenshot OCR (Mobile Money)** ⭐
**Purpose**: Extract transaction data from screenshots

**Key Components**:
- Instructions card: Camera icon + "Screenshot your JazzCash/EasyPaisa transaction list"
- Two large buttons:
  - 📷 "Take Photo" (50% width)
  - 🖼️ "Choose Photo" (50% width)
- Recent imports gallery (2-column grid with thumbnail, transaction count, date)
- Edit modal (full screen):
  - Editable table: Date | Amount | Type | Balance
  - Delete button per row
  - "Save" button to commit

---

### 5. **Multi-Account Management Screen** ⭐
**Purpose**: Manage checking, savings, credit cards, wallets

**Key Components**:
- Account list (each as card):
  - Icon (Bank/Card/Wallet), name, balance (large), account type
  - SMS status indicator
  - Tap for details, long-press for edit/delete
- "+ Add Account" button (large, blue)

**Add Account Modal**:
- Form fields:
  - Account name (text input)
  - Account type (dropdown: Bank, Card, Wallet, Cash, Investment)
  - Currency (dropdown, default: PKR)
  - Initial balance (number input)
  - Enable SMS parsing (toggle, if bank)
- Buttons: "Create", "Cancel"

**Account Transfer Feature**:
- Button: "Transfer Between Accounts"
- Modal: From account (dropdown), To account (dropdown), Amount, Category ("Transfer" auto-selected)
- "Transfer" button (executes immediately, shows confirmation)

---

### 6. **Family Accounts Screen (Max Tier Only)** ⭐
**Purpose**: Shared family budget management

**Key Components**:
- Family account card (if configured):
  - Gradient background (Blue → Green)
  - "Family Budget", member count, shared balance
  - Member avatars (circular, overlapping)
- Family dashboard:
  - Shared transactions list with "SHARED" badge
  - Individual breakdown (pie chart: who spent what)
- Member list:
  - Each member: Avatar, name, role (👑 Admin / 👤 Member / 👁️ Viewer), status
- "+ Invite Family" button (opens modal with email/phone input, role selector)

---

### 7. **Event Splits Screen** ⭐
**Purpose**: Create and manage shared expense events

**Key Components**:
- Two tabs: "Active Events" | "Settled"

**Active Events Tab**:
- Event cards: Event name & icon, member count, total amount, "Active" badge
- Event detail view:
  - Header: Event name, type icon, date
  - Members section: Avatars showing name, their share, status (✓ paid, ⏳ owes)
  - Expenses list: "Alice paid ₨2,500", breakdown per person
  - Settlement section: "Bob owes Alice ₨2,125" (red if unpaid, green if settled)
  - Payment link: "Send via WhatsApp/SMS"
  - "+ Add Expense" button (opens modal)

**Add Expense Modal**:
- Fields: Amount, description, paid by (dropdown), split type (Equal/Percentage/Custom)
- Shows calculation: "How much each person owes"
- "Add Expense" button

---

### 8. **Recurring Transactions Screen** ⭐
**Purpose**: Identify and manage recurring expenses

**Key Components**:
- Summary card: "Recurring This Month: ₨15,000"
- Breakdown: Bills ₨8,500, Subscriptions ₨2,000, Salary +₨45,000
- Recurring transactions list:
  - Icon, description (e.g., "Electricity Bill")
  - Amount + frequency ("₨2,500 / Monthly")
  - Confidence % (90%)
  - Next occurrence date ("Next: Oct 15")
  - Actions: "Confirm", "Dismiss", "Edit"
- Color badges:
  - Green (>85% confidence)
  - Yellow (70-85%)
  - Gray (<70%, dismissed)
- Annual calculation: "₨30,000/year for Electricity"

---

### 9. **Tax Export Screen** ⭐
**Purpose**: Export data for tax filing

**Key Components**:
- Export options card:
  - Date range picker ("Jan 1 - Dec 31" default: fiscal year)
  - Format selector: CSV / PDF / Excel (radio buttons)
  - Category breakdown: Income / Expenses / Transfers (checkboxes)
- Export preview:
  - Sample rows table: Date | Description | Category | Amount
  - Row count: "Showing 10 of 247 transactions"
- Action buttons:
  - "Download" (saves file)
  - "Email to Accountant" (optional email field)
  - "Cancel"

**PDF Template** (if PDF selected):
- Header: "Annual Expense Report 2026"
- Summary: Total Income / Total Expenses / Net P&L
- Categorical breakdown table
- Monthly summary chart
- Footer: "FBR Compliance Note"

---

## 🎯 Navigation Structure (Keep Consistent with Current)

### Bottom Tab Bar (5 tabs)
1. **Dashboard** (home icon) → Dashboard screen
2. **Accounts** (wallet icon) → Multi-Account Management [NEW]
3. **Splits** (share icon) → Event Splits [NEW]
4. **Family** (people icon) → Family Accounts (Max tier only) [NEW]
5. **Settings** (gear icon) → Settings screen

### Current Navigation (Reference)
- Use same teal background color for headers
- Use same card styling for components
- Keep bottom navigation style consistent

---

## 🎬 Interactions & Animations

### Transitions
- Screen changes: Slide from right (back: slide to right)
- Modal opens: Fade + slide up from bottom
- Card interactions: Slight scale (1.02x) on tap
- List items: Highlight on selection

### Swipe Gestures
- Swipe left on transaction: Reveal delete/archive
- Swipe right on transaction: Undo/restore
- Swipe left on account: Reveal edit/delete

### Haptic Feedback
- Tap feedback: Light haptic
- Payment settlement: Strong haptic
- Error: Alert pattern haptic

---

## 📐 Responsive Design

### Mobile (< 600px)
- Single column layout
- Full-width cards
- Bottom navigation tabs
- Safe area insets (notch/cutout safety)

### Tablet (600px - 1200px)
- Two-column layout (optional)
- Wider cards with padding
- Larger touch targets (48×48px)

### Desktop (> 1200px)
- Multi-column layout
- Side navigation drawer
- Compact mode for dense data

---

## 🌙 Dark Mode Support

- Same color palette, inverted backgrounds
- Use `@media (prefers-color-scheme: dark)` queries
- Maintain WCAG AA contrast (4.5:1 for text)

---

## ✅ Accessibility Requirements

- Font size minimum: 14px
- Touch targets: 44×44px minimum
- Color contrast: WCAG AA (4.5:1 for text)
- Alt text for all icons
- Screen reader labels on interactive elements

---

## 📊 Implementation Timeline

### Phase 1a (Weeks 1-2)
- [ ] SMS Auto-Logging screen
- [ ] Dashboard enhancements (account cards)
- [ ] Navigation structure (5 tabs)

### Phase 1b (Weeks 3-4)
- [ ] Bank Statement Import
- [ ] Screenshot OCR
- [ ] Multi-Account Management

### Phase 2 (Weeks 5+)
- [ ] Family Accounts
- [ ] Event Splits
- [ ] Recurring Transactions
- [ ] Tax Export

---

## 🎨 Design Deliverables Checklist

When creating mockups in Figma/Adobe XD, ensure:

- ✅ All 9 screens designed
- ✅ Design system component library created
- ✅ Multi-language text considerations (RTL for Arabic)
- ✅ Dark mode variants
- ✅ Responsive layouts (mobile/tablet/desktop)
- ✅ Interaction specs documented
- ✅ Accessibility notes included
- ✅ Icon sets defined (use Material Design Icons)
- ✅ Microinteraction animations specified
- ✅ Button states (default, hover, active, disabled)
- ✅ Error states and validation messaging
- ✅ Loading states and skeletons

---

## 📁 Design File Organization (Suggested Figma Structure)

```
Outlay Pro
├── 🎨 Design System
│   ├── Colors
│   ├── Typography
│   ├── Components
│   │   ├── Buttons
│   │   ├── Cards
│   │   ├── Forms
│   │   ├── Navigation
│   │   └── Lists
│   └── Patterns
├── 📱 Screens (Pro Features)
│   ├── 1. Dashboard (Enhanced)
│   ├── 2. SMS Auto-Logging
│   ├── 3. Bank Statement Import
│   ├── 4. Screenshot OCR
│   ├── 5. Multi-Account Management
│   ├── 6. Family Accounts
│   ├── 7. Event Splits
│   ├── 8. Recurring Transactions
│   └── 9. Tax Export
├── 🌓 Dark Mode Variants
├── 📱 Responsive (Mobile/Tablet/Desktop)
├── 🎬 Animations & Interactions
└── 📝 Specifications & Notes
```

---

## 🔗 Reference Files

All design specifications and existing screenshots are in the project:

**Design References**:
- `OUTLAY_PRO_DESIGN_REFERENCE.md` — Comprehensive screen specifications
- `OUTLAY_PRO_PRICING_STRATEGY.md` — Pricing and feature matrix

**Existing Screenshots** (Current App Baseline):
- `docs/assets/screenshots/dashboard.png`
- `docs/assets/screenshots/transactions.png`
- `docs/assets/screenshots/budgets.png`
- `docs/assets/screenshots/reports.png`
- `app_store_assets/ipad_13inch_screenshots/*` (iPad versions)

**Project Files**:
- Branch: `feature/outlay-pro-v2`
- Jira Tasks: KAN-50 to KAN-57

---

## 👤 Contact & Questions

**For questions on:**
- **Feature requirements**: Review Jira tasks (KAN-50 to KAN-57)
- **Design system details**: See OUTLAY_PRO_DESIGN_REFERENCE.md
- **Pricing tiers**: See OUTLAY_PRO_PRICING_STRATEGY.md
- **Implementation timeline**: See Phase breakdown above

---

## ✨ Next Steps

1. **Designer creates Figma mockups** using this package
2. **Review and approve designs** (iterate if needed)
3. **Developer implements screens** following approved designs
4. **Test on iOS/Android devices** for responsive behavior
5. **Iterate on visual refinements** during development

---

**Status**: ✅ Ready for Designer Review

