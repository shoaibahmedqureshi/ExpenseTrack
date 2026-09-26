# Outlay Pro - Google Stitch Design Generation Prompt

## 📋 Project Overview

**App**: Outlay Pro - Premium expense tracking app with SMS auto-logging, family budgeting, and expense splitting
**Platform**: iOS & Android (mobile-first)
**Target Market**: Pakistan & South Asia
**Design Style**: Modern, clean, minimalist with strong data visualization

---

## 🎨 Complete Design System

### Color Palette
- **Primary**: #2563EB (Blue) - Actions, buttons, highlights
- **Success**: #10B981 (Green) - Income, positive, confirmations
- **Danger**: #EF4444 (Red) - Expenses, warnings
- **Neutral Gray**: #6B7280 - Secondary text, borders
- **Background Light**: #F9FAFB - Page background
- **Text Dark**: #1F2937 - Headlines, primary text
- **White**: #FFFFFF - Cards, surfaces

### Typography
- **Headlines (H1)**: Poppins Bold, 24px, #1F2937
- **Subheadings (H2)**: Poppins Semibold, 18px, #1F2937
- **Body**: Inter Regular, 14px, #6B7280
- **Small**: Inter Regular, 12px, #9CA3AF
- **Numbers**: Courier New (monospace), 16px bold, #1F2937

### Component Specs
- **Card Corner Radius**: 12px with shadow elevation 1 (0 2px 4px rgba(0,0,0,0.05))
- **Button Corner Radius**: 8px
- **Input Corner Radius**: 4px
- **Spacing**: 8px base unit (multiples: 16, 24, 32)
- **Safe Area**: 16px from edges (mobile notch-safe)
- **Touch Targets**: 44×44px minimum

### Navigation
- **Header Style**: Teal/dark green background with white text (reference existing app)
- **Bottom Tab Bar**: 5 tabs - Dashboard, Accounts, Splits, Family, Settings
- **Tab Style**: Light background for active tab, minimal icon + label

---

## 📱 SCREEN 1: Enhanced Dashboard

**Purpose**: Overview of accounts, balances, transactions, and recurring expenses

**Header**: 
- Teal background with white text "Dashboard"
- User avatar/initial circle (top right)
- Time display (top left)

**Layout** (Top to Bottom):
1. **Total Balance Card** (sticky, top)
   - Background: Linear gradient (Blue → Lighter Blue)
   - Display: Large "₨125,450" in white
   - Small text: "Total Balance"
   - Height: 140px, full width with 16px padding

2. **Account Cards Row** (horizontally scrollable)
   - Each card: 160×120px, white background, elevation 1
   - Contains: Account icon, name, balance (large), sync time ("Updated 2m ago"), mini 7-day chart
   - 3-4 cards visible, scroll for more
   - Margin: 16px between cards

3. **Recurring This Month Section**
   - Card: White background, elevation 1
   - Title: "Recurring This Month"
   - Display: "₨5,000" in large green text
   - Breakdown: Small items (Bills, Subscriptions, Salary if income)

4. **Recent Transactions List**
   - Row height: 64px
   - Each row: Icon (with colored circle background) | Description | Date | Amount
   - Colors: Red for expense, green for income
   - Source badge: "SMS" / "Manual" / "Import"
   - Swipe left to reveal delete/archive

5. **Floating Action Button (FAB)**
   - Position: Bottom right corner (16px safe area)
   - Color: Primary Blue (#2563EB)
   - Icon: Plus or split symbol
   - Elevation: High shadow

**Note**: Keep visual consistency with existing dashboard screenshot (reference: docs/assets/screenshots/dashboard.png)

---

## 📱 SCREEN 2: SMS Auto-Logging

**Purpose**: Configure and monitor automatic SMS-based transaction logging

**Header**:
- Teal background "SMS Auto-Logging"
- Back button (left), Settings icon (right)

**Layout** (Top to Bottom):

1. **Permission Status Card**
   - Title: "SMS Access"
   - Toggle: Green (ON) or gray (OFF)
   - Description text: "Allow Outlay to read SMS for automatic expense logging"
   - Warning text: "Only SMS from banks are processed. Nothing is shared."
   - If OFF: Blue "Enable" button

2. **Active Banks Section**
   - Title: "Active Banks"
   - Grid or list of bank items:
     - Each item: Bank logo (HBL, UBL, MCB, Meezan, Faysal, JazzCash, EasyPaisa)
     - Status icon: Green checkmark (SMS detected) or gray circle (waiting)
     - Margin: 8px between items

3. **Statistics Card**
   - "Captured This Week": Bold number + "transactions"
   - "Total Saved": "₨8,500 (manual entry time saved)"
   - Progress bar (light blue background, dark blue fill)

4. **Recent SMS Transactions List**
   - Row height: 64px
   - Each: Bank icon | Amount | Category | "Added Xh ago"
   - Colors: Red for expense, green for income
   - Swipe left: Edit/Delete options
   - Swipe right: Undo/Restore

5. **Help Section** (if no transactions)
   - Card: Light gray background
   - Icon: Question mark
   - Text: "Why no transactions?"
   - Link: "View setup guide"

---

## 📱 SCREEN 3: Bank Statement Import

**Purpose**: Upload and import bank statements in PDF or CSV format

**Header**:
- Teal background "Import Statement"
- Back button, Info icon (optional)

**Layout** (Top to Bottom):

1. **Upload Zone**
   - Large drag-drop area: 120px height
   - Icon: Cloud upload icon (centered, light gray)
   - Text: "Drag PDF or CSV here" 
   - Text: "or Tap to browse"
   - Background: Light gray border (dashed), light blue background
   - Corner radius: 8px

2. **Supported Banks**
   - Text: "Supported Banks:"
   - Icons in row: HBL, UBL, MCB, Meezan, Faysal (bank logos, 32px each)
   - Spacing: 12px between icons

3. **Choose File Button**
   - Style: Primary blue, 56px height, full width (with 16px padding)
   - Text: "📁 Choose File from Device"
   - Corner radius: 8px

4. **Recent Imports History**
   - List of previous imports:
     - Each row height: 72px
     - Layout: Icon (PDF/CSV) | Filename | Date | Status icon (✓/⚠/✗) | Count
     - Example: "HBL_Statement_July2026.pdf | Jul 15, 2026 | ✓ | 47 transactions"
     - Status colors: Green (✓), Yellow (⚠), Red (✗)
     - "Preview" button (right side, small, secondary style)
     - Swipe left: Delete option

5. **Import Preview Modal** (Full screen overlay)
   - Header: "Preview: HBL_Statement_July2026.pdf"
   - Close button (X, top right)
   - Table (scrollable):
     - Columns: Date | Description | Category | Amount | Status
     - Row colors: Green (auto-categorized), Yellow (needs review), Red (error)
     - Rows: 10-20 visible, scroll for more
   - Bottom buttons (sticky):
     - "Cancel" (secondary)
     - "Approve & Import" (primary, disabled if errors exist)

---

## 📱 SCREEN 4: Screenshot OCR (Mobile Money)

**Purpose**: Extract transaction data from screenshots of JazzCash/EasyPaisa apps

**Header**:
- Teal background "Import Screenshots"
- Back button, Info icon

**Layout** (Top to Bottom):

1. **Instructions Card**
   - Icon: Camera icon (large, teal)
   - Title: "Import Transaction History"
   - Description: "Screenshot your JazzCash/EasyPaisa transaction list and we'll extract the data"
   - Info: "95% accuracy with manual fix option"
   - Background: Light blue (#F3F4F6)

2. **Action Buttons** (Large, side by side)
   - Left (50% width): "📷 Take Photo" - Primary blue, 56px height
   - Right (50% width): "🖼️ Choose Photo" - Primary blue, 56px height
   - Gap: 12px between buttons
   - Corner radius: 8px

3. **Recent Imports Gallery**
   - Grid: 2 columns
   - Each cell:
     - Thumbnail image (120×160px)
     - Overlay: "12 transactions" (white text, centered)
     - Date: "Jul 22, 2026" (white text, bottom)
     - Tap to expand, swipe left to delete

4. **OCR Edit Modal** (Full screen)
   - Header: "Edit Extracted Data"
   - Subheader: "Verify and edit transaction details"
   - Table (scrollable):
     - Columns: Date | Amount | Type | Balance
     - Rows: Each cell editable (tap to edit)
     - Row height: 56px
     - Borders: Light gray
   - Delete button per row (trash icon, right side)
   - Bottom buttons (sticky):
     - "Cancel" (secondary)
     - "Save Changes" (primary)

---

## 📱 SCREEN 5: Multi-Account Management

**Purpose**: Create and manage multiple financial accounts

**Header**:
- Teal background "My Accounts"
- Back button, Add button (+)

**Layout** (Top to Bottom):

1. **Account List**
   - Each account as card (full width, 96px height):
     - Left: Account icon (Bank/Card/Wallet, 40×40px, colored background)
     - Center: Account name (bold) + Account type (secondary text)
     - Right: Balance (large, bold, right-aligned) + SMS status icon
     - Background: White, elevation 1
     - Corner radius: 12px
     - Margin: 12px bottom
   - Tap: View details
   - Long-press: Edit/Delete menu

2. **Add Account Button**
   - Style: Primary blue, 56px height, full width (with 16px padding)
   - Text: "+ Add Account"
   - Icon: Plus symbol
   - Corner radius: 8px

3. **Add Account Modal**
   - Title: "Create New Account"
   - Form fields:
     - "Account Name" (text input, placeholder: "e.g., HBL Checking")
     - "Account Type" (dropdown: Bank, Card, Wallet, Cash, Investment)
     - "Currency" (dropdown, default: PKR)
     - "Initial Balance" (number input, default: 0)
     - "Enable SMS Parsing" (toggle, if bank selected)
   - Buttons (bottom, full width):
     - "Cancel" (secondary)
     - "Create Account" (primary)

4. **Account Transfer Feature**
   - Button: "💸 Transfer Between Accounts" (secondary style, 56px)
   - Opens modal:
     - Title: "Transfer Money"
     - "From Account" (dropdown)
     - "To Account" (dropdown)
     - "Amount" (number input)
     - Category (auto-set to "Transfer", neutral color)
     - "Note" (optional text)
     - Note: Transaction categorized as neutral (not expense/income)
     - Buttons: "Cancel" | "Transfer" (primary)
   - On success: Toast notification "Transferred ₨X to Account Y"

---

## 📱 SCREEN 6: Family Accounts (Max Tier Only)

**Purpose**: Shared family budget management across multiple users

**Header**:
- Teal background "Family Budget"
- Back button, Settings icon (gear)

**Layout** (Top to Bottom):

1. **Family Account Card** (if configured)
   - Background: Gradient (Blue → Green)
   - Icon: People icon (top left)
   - Title: "Family Budget"
   - Member count: "4 members"
   - Shared balance: Large "₨45,000" in white
   - Member avatars: 4 small circles (overlapping, bottom right)
   - Tap: View family details

2. **Family Dashboard Section**
   - Title: "Shared Expenses"
   - Recent transactions list (with "SHARED" badge):
     - Row: Icon | Description | Date | Amount
     - Badge style: Light blue, small text
   - "View all" link (right)

3. **Individual Breakdown**
   - Chart type: Pie chart or donut
   - Title: "Who Spent What This Month"
   - Colors: Use account colors for each member
   - Legend: Member name + amount + percentage
   - Tap slice to filter transactions

4. **Members Section**
   - Title: "Family Members"
   - List of members:
     - Each row: Avatar | Name | Role | Status | Actions
     - Role icons: 👑 Admin | 👤 Member | 👁️ Viewer
     - Status: "Active" (green) | "Pending" (yellow)
     - Actions: Tap for details, long-press for edit/remove

5. **Invite Family Member Button**
   - Button: "+ Invite Family Member" (primary blue, 56px)
   - Opens modal:
     - Title: "Invite Family Member"
     - Email/Phone input (text)
     - Role dropdown: Admin / Member / Viewer
     - Info text: "They'll receive an invite via email/SMS"
     - Buttons: "Cancel" | "Send Invite" (primary)

6. **Transaction Approval** (for Admin)
   - Section: "Pending Approvals"
   - Card per high-value transaction (>₨5,000):
     - "Member Name paid ₨2,500 at Store"
     - Timestamp
     - Buttons: "Approve" (green) | "Reject" (red)

---

## 📱 SCREEN 7: Event Splits

**Purpose**: Create events and split expenses among participants

**Header**:
- Teal background "Expense Splits"
- Back button, "+ Create Event" button

**Layout** (Two tabs: Active | Settled):

### TAB 1: Active Events

1. **Event Cards List**
   - Each card (full width, 104px):
     - Icon (top left): Event type (Trip, Party, Household, Project)
     - Title (bold): Event name
     - Meta: "3 members | ₨8,500 total"
     - Badge: "Active" (blue)
     - Tap: View details
     - Long-press: Archive/Delete

2. **Event Detail Screen** (Click card to expand)
   - Header: Event name + type icon + date created
   
   - **Members Section**:
     - Title: "Members"
     - Each member row (60px):
       - Avatar | Name | Their share (bold) | Status indicator
       - Status: ✓ (paid, green) | ⏳ (owes, yellow) | pending
   
   - **Expenses Section**:
     - Title: "Expenses"
     - Each expense row (80px):
       - "Alice paid ₨2,500" (bold)
       - "Split equally among 4 people"
       - "₨625 per person"
       - Tap to edit, long-press for delete
     - "+ Add Expense" button (secondary, 48px)
   
   - **Settlement Section**:
     - Title: "Settlement"
     - Items:
       - "Bob owes Alice ₨2,125" (red if unpaid, green if settled)
       - "✓ Settled" (green checkmark, if paid)
       - Payment link: "Send via WhatsApp/SMS"
       - "Mark as Settled" button (if payment received)
     - "📄 Export Report" button (secondary)
   
   - **Add Expense Modal**:
     - Title: "Add Expense"
     - Fields:
       - "Amount" (number input)
       - "Description" (text)
       - "Paid by" (dropdown: Member names)
       - "Split Type" (radio buttons: Equal / Percentage / Custom)
       - Calculation display: "How much each person owes"
     - Buttons: "Cancel" | "Add Expense" (primary)

### TAB 2: Settled Events

- Archive of completed events (read-only view)
- Each card: Event name, date range, total amount, "✓ Settled"
- Actions: Restore, delete

---

## 📱 SCREEN 8: Recurring Transactions

**Purpose**: Automatically detect and manage recurring expenses and income

**Header**:
- Teal background "Recurring Transactions"
- Back button, Settings icon

**Layout** (Top to Bottom):

1. **Summary Card**
   - Title: "Recurring This Month"
   - Large amount: "₨15,000"
   - Breakdown (3-4 items):
     - Bills: "₨8,500"
     - Subscriptions: "₨2,000"
     - Salary: "+₨45,000" (green if income)
   - Chart: Bar chart (categories vs amounts)

2. **Recurring Transactions List**
   - Title: "Detected Patterns"
   - Each transaction row (80px):
     - Icon (colored background) | Description | Amount | Frequency
     - Example: "🔌 Electricity Bill | ₨2,500 / Monthly"
     - Confidence: "90%" (small, secondary text)
     - Next occurrence: "Next: Oct 15" (small, secondary)
     - Buttons (right): "Confirm" (green) | "Dismiss" (gray) | "Edit" (pencil)
   
   - Badge colors (confidence):
     - Green circle: >85% confidence
     - Yellow circle: 70-85% confidence
     - Gray circle: <70% (dismissed)

3. **Statistics Section**
   - Annual calculation for each:
     - "Electricity: ₨30,000/year"
     - "Netflix: ₨5,988/year"
   - Budget impact: Compare to category total

4. **Edit Pattern Modal**
   - Title: "Edit Recurring Pattern"
   - Fields:
     - "Description" (text)
     - "Amount" (number)
     - "Frequency" (dropdown: Daily, Weekly, Bi-weekly, Monthly, Quarterly)
     - "Category" (dropdown)
     - "Reminder" (X days before, optional)
   - Buttons: "Cancel" | "Save Changes" (primary)

---

## 📱 SCREEN 9: Tax Export

**Purpose**: Export categorized transactions for tax filing

**Header**:
- Teal background "Tax Export"
- Back button, Help icon

**Layout** (Top to Bottom):

1. **Export Options Card**
   - Title: "Export Options"
   
   - **Date Range Picker**:
     - From: "Jan 1, 2026" (date picker)
     - To: "Dec 31, 2026" (date picker)
     - Preset: "Fiscal Year" button
   
   - **Format Selector** (radio buttons):
     - ○ CSV (for spreadsheets)
     - ○ PDF (for accountants)
     - ○ Excel (with formulas)
   
   - **Category Breakdown** (checkboxes):
     - ☑ Income
     - ☑ Expenses
     - ☑ Transfers

2. **Export Preview Section**
   - Title: "Preview"
   - Table (scrollable):
     - Columns: Date | Description | Category | Amount
     - Rows: Show 10 of 247 transactions
     - Row height: 48px
     - Borders: Light gray
     - Categories color-coded: Green (income), Red (expense), Gray (transfer)
   - "Show more" link (bottom)

3. **Summary Card**
   - Total Income: "₨83,707"
   - Total Expenses: "₨407,127"
   - Net: "-₨323,420"
   - Format: Green/Red/Gray text

4. **Action Buttons** (Bottom, sticky)
   - "Cancel" (secondary, full width, 48px)
   - "Download" (primary, full width, 56px)
   - Optional: "Email to Accountant" (tertiary, with email input)

5. **PDF Preview** (if PDF format selected)
   - Header: "Annual Expense Report 2026"
   - Summary section:
     - Total Income | Total Expenses | Net P&L
   - Categorical breakdown table
   - Monthly summary chart
   - Footer: "FBR Compliance Note"

---

## 🎬 Interaction & Animation Specs

### Transitions
- Screen change: Slide from right (back: slide to right)
- Modal open: Fade + slide up from bottom (300ms)
- Card tap: Slight scale (1.02x) + highlight (100ms)
- List items: Fade in on load (200ms stagger)

### Gestures
- Swipe left on list items: Reveal action buttons (edit/delete)
- Swipe right on list items: Undo/restore
- Pull to refresh on dashboard: Spinner animation + SMS sync

### Haptic Feedback
- Tap feedback: Light haptic (iOS/Android)
- Payment settlement: Strong haptic (confirmation)
- Error: Alert pattern haptic
- Successful action: Notification haptic

### Loading States
- Skeleton loaders: Shimmer animation on cards
- OCR processing: Progress indicator (0-100%) with "Processing..."
- SMS sync: Spinner in status badge
- File upload: Progress bar (blue fill)

### Visual Feedback
- Button states: default | hover (slight shade) | active | disabled (opacity 0.5)
- Error messages: Red text, red border on inputs
- Success: Green toast notification with checkmark
- Warnings: Yellow/amber alerts

---

## 📐 Responsive & Accessibility

### Mobile (< 600px)
- Single column layout
- Full-width cards with 16px margin
- Bottom tab navigation
- Safe area: 16px insets for notch/cutout

### Tablet (600px - 1200px)
- Two-column layout (optional)
- Wider cards with 24px padding
- Touch targets: 48×48px minimum
- Sidebar navigation (optional)

### Dark Mode
- Background: #0F172A (very dark)
- Cards: #1F2937 (dark gray)
- Text: #E5E7EB (light gray)
- Primary: #60A5FA (lighter blue)
- Contrast: Maintain WCAG AA (4.5:1)

### Accessibility
- Font minimum: 14px body text
- Touch targets: 44×44px
- Color contrast: 4.5:1 for text
- Screen reader labels on icons
- Focus indicators on interactive elements
- Alt text for transaction/chart icons

---

## 🎨 Design System Components

Create reusable components library:

### Buttons
- **Primary**: Blue background, white text, 8px corner radius
- **Secondary**: Light blue background, blue text
- **Tertiary**: Gray background, dark text
- **Danger**: Red background, white text
- **States**: default | hover (10% darker) | active | disabled (50% opacity)

### Cards
- **Standard**: White background, 12px corner radius, elevation 1
- **Elevated**: Elevation 2 (0 4px 12px rgba(0,0,0,0.1))
- **Gradient**: For summary cards (Blue to Green)
- **Padding**: 16px default, 24px for spacious

### Forms
- **Text Input**: 4px border radius, light gray border, 44px height
- **Dropdown**: Chevron icon, light gray border, 44px height
- **Toggle**: 24px height, blue when active
- **Checkbox**: 18px size, blue checkmark when active

### Lists
- **Row Height**: 64px default, 80px for dense data
- **Dividers**: Light gray border, 1px
- **Actions**: Icons at right (edit/delete/share)
- **Selection**: Light blue background highlight

### Navigation
- **Header**: Teal background (#1B6B5E), white text, 56px height
- **Tab Bar**: 5 tabs, 56px height, active tab has light background
- **Back Button**: Left arrow icon, tappable (44×44px minimum)

### Icons
- Use Material Design Icons (32px or 24px)
- Color coding: Teal (primary), Blue (action), Green (positive), Red (danger), Gray (neutral)
- Circular backgrounds: 40px or 48px circles with 10% opacity color

### Badges & Labels
- **Status**: Green (active), Yellow (pending), Red (error), Gray (inactive)
- **Amount**: Monospace font, color-coded (green income, red expense)
- **Category**: Icon + label, small text

---

## 📋 Design File Organization (Figma/Adobe XD)

```
Outlay Pro - Design System
├── 📦 Components & Styles
│   ├── Colors
│   ├── Typography
│   ├── Buttons
│   ├── Cards
│   ├── Forms
│   ├── Navigation
│   └── Icons
├── 📱 Mobile Screens (375×812px)
│   ├── 1. Dashboard (Enhanced)
│   ├── 2. SMS Auto-Logging
│   ├── 3. Bank Statement Import
│   ├── 4. Screenshot OCR
│   ├── 5. Multi-Account Management
│   ├── 6. Family Accounts
│   ├── 7. Event Splits
│   ├── 8. Recurring Transactions
│   └── 9. Tax Export
├── 🎬 Interactions & Animations
├── 🌓 Dark Mode Variants
└── 📝 Specs & Notes
```

---

## ✅ Design Checklist

When creating mockups, ensure:

- ✅ All 9 screens designed with high fidelity
- ✅ Design system components created and applied consistently
- ✅ Dark mode variants for all screens
- ✅ Responsive layouts (mobile primary)
- ✅ Interactive elements clearly marked (buttons, inputs, modals)
- ✅ Icons sourced from Material Design Icons
- ✅ Color contrast WCAG AA compliant
- ✅ Touch targets minimum 44×44px
- ✅ Text hierarchy clear (headings, body, secondary)
- ✅ Empty states designed (no data scenarios)
- ✅ Loading states with skeletons
- ✅ Error states with messaging
- ✅ Modal/overlay specs documented
- ✅ Animation/transition specs included
- ✅ Accessibility notes for screen readers
- ✅ Multi-language text width considerations (RTL for Arabic)

---

## 🔗 Reference Materials

**Existing App Screenshots** (for visual consistency):
- Dashboard: `docs/assets/screenshots/dashboard.png`
- Transactions: `docs/assets/screenshots/transactions.png`
- Budgets: `docs/assets/screenshots/budgets.png`
- Reports: `docs/assets/screenshots/reports.png`

**Documentation**:
- Full specs: `OUTLAY_PRO_DESIGN_REFERENCE.md`
- Pricing tiers: `OUTLAY_PRO_PRICING_STRATEGY.md`
- Design package: `OUTLAY_PRO_DESIGN_PACKAGE.md`

---

## 📌 Notes for Designer

1. **Existing Design Baseline**: Reference the current app screenshots for UI patterns, colors, and interactions. Maintain visual consistency with existing screens.

2. **Multi-Language**: Ensure layouts work with RTL languages (Arabic). Text fields should flex for longer text (e.g., Hindi, Bengali).

3. **Dark Mode**: Create dark variants for all screens using the specified dark palette.

4. **Interactions**: Include hover states, loading states, error states, and success feedback in the design.

5. **Accessibility**: Mark all interactive elements with aria labels. Ensure color contrast meets WCAG AA standards.

6. **Flow Documentation**: Document user flows between screens (e.g., Dashboard → Multi-Account → Create Account modal).

---

**Status**: ✅ Ready for Google Stitch or Designer Mockup Creation

