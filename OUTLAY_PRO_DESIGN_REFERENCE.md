# Outlay Pro - Design Reference & UI Specifications

**Version**: 1.0  
**Date**: 2026-09-26  
**Status**: Ready for Implementation  
**Branch**: `feature/outlay-pro-v2`

---

## 1. Design System Overview

### Color Palette
```
Primary Blue:      #2563EB (Actions, primary buttons, highlights)
Success Green:     #10B981 (Income, positive balance, confirmations)
Danger Red:        #EF4444 (Expenses, warnings, deletions)
Gray Neutral:      #6B7280 (Secondary text, borders)
Light Background:  #F9FAFB (Page background, cards)
Dark Text:         #1F2937 (Headlines, primary text)
White:             #FFFFFF (Cards, modals)
```

### Typography
- **Headings (H1)**: Poppins Bold, 24px, #1F2937
- **Subheadings (H2)**: Poppins Semibold, 18px, #1F2937
- **Body Text**: Inter Regular, 14px, #6B7280
- **Small Text**: Inter Regular, 12px, #9CA3AF
- **Numbers/Amounts**: Courier New (monospace), 16px, bold, #1F2937

### Spacing & Layout
- **Gutter**: 16px (mobile), 24px (tablet)
- **Component Spacing**: 8px (tight), 16px (normal), 24px (loose)
- **Safe Area**: 16px from edges (iOS/Android notch-safe)
- **Corner Radius**: 12px (cards), 8px (buttons), 4px (inputs)

### Shadow & Elevation
- **Elevation 1**: 0 2px 4px rgba(0,0,0,0.05)
- **Elevation 2**: 0 4px 12px rgba(0,0,0,0.1)
- **Elevation 3**: 0 8px 24px rgba(0,0,0,0.15)

---

## 2. Multi-Language Support

### Supported Languages
| Code | Language | Direction | Status |
|------|----------|-----------|--------|
| en | English | LTR | ✅ Primary |
| ur | اردو (Urdu) | RTL | ✅ Pakistan |
| hi | हिंदी (Hindi) | LTR | ✅ India |
| ar | العربية (Arabic) | RTL | ✅ MENA |
| bn | বাংলা (Bengali) | LTR | ✅ Bangladesh |
| id | Bahasa Indonesia | LTR | ✅ Indonesia |
| vi | Tiếng Việt | LTR | ✅ Vietnam |
| fil | Filipino | LTR | ✅ Philippines |

### Implementation Notes
- i18n JSON structure: `/locales/{lang}.json`
- RTL layout: Flexbox `flex-direction: row-reverse` for Arabic
- Font loading: Use system fonts + Noto Sans for Indic scripts
- Number formatting: `Intl.NumberFormat` by locale
- Date formatting: `Intl.DateTimeFormat` by locale

---

## 3. Screen Specifications

### Screen 1: Dashboard (Home)

**Purpose**: Overview of accounts, transactions, recurring expenses  
**Layout**: Single column, scrollable  
**Header**: Logo + Notification bell + Settings gear

**Components**:
1. **Total Balance Card** (Top, sticky)
   - Large number: Total ₨ (all accounts combined)
   - Small text: "Total Balance"
   - Background: Linear gradient Blue → Lighter Blue
   - Height: 140px

2. **Account Cards Row** (Scrollable horizontal)
   - Each card: 160px × 120px
   - Elements: Account icon, name, balance, sync time, mini chart
   - Background: White with shadow elevation 1
   - Actions: Tap to view details, long-press for menu

3. **Recurring Expenses Section**
   - Card: "Recurring This Month"
   - Display: ₨5,000 (total)
   - Breakdown: Bills, subscriptions, salary (if income)
   - Tap to view details

4. **Recent Transactions List**
   - Row height: 64px
   - Elements: Category icon + color badge, description, amount, source badge, date
   - Swipe left: Delete/archive
   - Tap: Edit/categorize

5. **Floating Action Button (FAB)**
   - Position: Bottom right, safe area
   - Color: Primary Blue
   - Icon: Split/plus
   - Actions: Split expense, add transaction

**Sample Data**:
```
Total Balance: ₨125,450
Accounts: HBL (₨75,000), JazzCash (₨30,450), Cash (₨20,000)
Recent: "Starbucks Coffee" -₨450 (Manual), "HBL Transfer" +₨5,000 (SMS)
Recurring: Electricity Bill ₨2,500, Netflix ₨499, Salary +₨45,000
```

---

### Screen 2: SMS Auto-Logging

**Purpose**: Configure and monitor SMS parsing  
**Layout**: Single column, scrollable  
**Header**: "SMS Auto-Logging" + Back button

**Sections**:

1. **SMS Permission Card**
   - Status: ON/OFF toggle (green when active)
   - Description: "Allow Outlay to read SMS for automatic expense logging"
   - Warning: "Only SMS from banks are processed. Nothing is shared."
   - Action: "Enable" button if OFF

2. **Active Banks List**
   - Grid or list of supported banks
   - Each item: Bank logo + name + status icon
   - Green checkmark: SMS detected and parsing
   - Gray circle: Waiting for SMS
   - Supported: HBL, UBL, MCB, Meezan, Faysal, JazzCash, EasyPaisa

3. **Statistics Card**
   - "Captured This Week": "12 transactions"
   - "Total Saved": "₨8,500 (manual entry time)"
   - Progress bar: SMS parsing effectiveness

4. **Recent SMS Transactions List**
   - Row height: 64px
   - Elements: Bank logo, amount, category (auto-detected), "Added 2h ago"
   - Color: Green (income), Red (expense)
   - Swipe left: Edit category or delete
   - Tap: View details or edit amount

5. **Help Card** (if no SMS detected)
   - "Why no transactions?"
   - Link to setup guide
   - Troubleshooting steps

---

### Screen 3: Bank Statement Import

**Purpose**: Upload PDF/CSV statements  
**Layout**: Single column, scrollable  
**Header**: "Import Statement" + Back button

**Sections**:

1. **Upload Area**
   - Large drag-drop zone (120px height)
   - Icon: Cloud upload
   - Text: "Drag PDF or CSV here" or "Tap to browse"
   - Supported banks shown as icons (HBL, UBL, MCB, Meezan, Faysal)

2. **File Browser Button**
   - Color: Primary Blue
   - Text: "Choose File"
   - Action: Open file picker

3. **Recent Imports History**
   - List of previously imported statements
   - Each item: Filename, date, ✓/⚠/✗ status, transaction count
   - "Preview" button: View imported rows in table
   - "Delete" button: Remove import

4. **Import Preview Modal** (Full screen)
   - Table: Date | Description | Category | Amount | Status
   - Row colors: Green (auto-categorized), Yellow (needs review), Red (error)
   - Action buttons: "Approve & Import" (disabled if errors), "Cancel"
   - Editable fields: Click to change category or amount

---

### Screen 4: Screenshot OCR (Mobile Money)

**Purpose**: Import JazzCash/EasyPaisa historical data  
**Layout**: Single column, scrollable  
**Header**: "Import Screenshots" + Back button

**Sections**:

1. **Instructions Card**
   - Icon: Camera
   - Text: "Screenshot your JazzCash/EasyPaisa transaction list and we'll extract the data"
   - Info: "95% accuracy with manual fix option"

2. **Action Buttons** (Large, side by side)
   - Camera button (50% width): "📷 Take Photo"
   - Gallery button (50% width): "🖼️ Choose Photo"
   - Height: 56px each

3. **Recent Imports Gallery**
   - Grid layout (2 columns)
   - Each cell: Thumbnail image, transaction count, date
   - Tap: Expand and edit rows
   - Swipe left: Delete

4. **OCR Edit Modal** (Full screen)
   - Shows extracted rows in editable table
   - Columns: Date | Amount | Type | Balance
   - Each cell: Tap to edit, auto-save
   - Delete button per row
   - "Save" button: Commit all changes

---

### Screen 5: Multi-Account Management

**Purpose**: Manage checking, savings, credit cards, wallets  
**Layout**: Single column, scrollable  
**Header**: "My Accounts" + Back button

**Sections**:

1. **Account List**
   - Each account: Card layout
   - Elements: Icon (Bank/Card/Wallet), name, balance (large), account type, SMS status
   - Card background: White with shadow elevation 1
   - Actions: Tap for details, long-press for edit/delete menu

2. **Add Account Button**
   - Large button: "+ Add Account"
   - Color: Primary Blue
   - Action: Opens modal

3. **Add Account Modal**
   - Form fields:
     - Account name (text input)
     - Account type (dropdown: Bank, Card, Wallet, Cash, Investment)
     - Currency (dropdown, default: PKR)
     - Initial balance (number input)
     - Enable SMS parsing (toggle, if bank)
   - Action buttons: "Create", "Cancel"

4. **Account Transfer Feature**
   - Button: "Transfer Between Accounts"
   - Opens modal:
     - From account (dropdown)
     - To account (dropdown)
     - Amount (number input)
     - Category: "Transfer" (auto-selected, neutral color)
     - Note (optional text)
     - "Transfer" button: Executes immediately, shows confirmation

---

### Screen 6: Family Accounts (Max Tier Only)

**Purpose**: Shared family budget management  
**Layout**: Single column, scrollable  
**Header**: "Family Budget" or "Add Family" + Settings

**Sections**:

1. **Family Account Card** (if configured)
   - Card background: Gradient Blue → Green
   - Elements: "Family Budget", member count, shared balance
   - Member avatars (circular, overlapping): Show first 4, +N more if needed
   - Tap: View family details

2. **Family Dashboard**
   - Shared transactions list (with "SHARED" badge)
   - Individual breakdown (pie chart): Who spent what
   - Total spent this month by member

3. **Member List**
   - Each member: Avatar, name, role, balance/status
   - Member roles: 👑 Admin (can edit/delete), 👤 Member (can add), 👁️ Viewer (read-only)
   - Actions: Tap for details, long-press for remove/change role

4. **Invite Family Member**
   - Button: "+ Invite Family"
   - Modal:
     - Email or phone number
     - Role selector (Admin/Member/Viewer)
     - Status: "Pending" → "Accepted" once they join
     - "Send Invite" button

5. **Transaction Approval** (if Admin)
   - Flag for transactions above threshold (e.g., >₨5,000)
   - Shows: Member name, amount, description, timestamp
   - Actions: "Approve", "Reject"

---

### Screen 7: Event Splits

**Purpose**: Create events and split expenses among people  
**Layout**: Tab-based (Active / Settled)  
**Header**: "Expense Splits" + "Create Event" button

**Tab 1: Active Events**

1. **Event Card List**
   - Each card: Event name & icon, member count, total amount
   - Status badge: "Active" (blue)
   - Tap: View event details
   - Long-press: Archive/delete

2. **Event Detail View**
   - Header: Event name, type icon, date created
   - **Members Section**:
     - Avatars in row, each showing: name, their share, status (✓ paid, ⏳ owes, pending)
   
   - **Expenses List**:
     - Each expense: "Alice paid ₨2,500" (or "Bob paid ₨1,000")
     - Breakdown: "Split equally among 4 people"
     - Amount per person: ₨625
     - Actions: Edit, delete
   
   - **Settlement Section**:
     - "Bob owes Alice ₨2,125" (highlighted in red if unpaid)
     - "✓ Settled" (green checkmark if paid)
     - Payment link: "Send payment via WhatsApp/SMS"
     - "Mark as Settled" button once payment received
   
   - **Add Expense Button**:
     - Opens modal: Amount, description, paid by (dropdown), split type (Equal/Percentage/Custom)
     - Shows calculation: "How much each person owes"
     - "Add Expense" button

3. **Export Button**
   - Exports settlement report as CSV/PDF
   - Shows: Who paid whom, amounts, dates

**Tab 2: Settled Events**
   - Archive of completed/settled events
   - Read-only view
   - Actions: Restore, permanently delete

---

### Screen 8: Recurring Transactions

**Purpose**: Identify and manage recurring expenses/income  
**Layout**: Single column, scrollable  
**Header**: "Recurring Transactions" + Back button

**Sections**:

1. **Summary Card**
   - "Recurring This Month": ₨15,000 (total)
   - Breakdown: Bills ₨8,500, Subscriptions ₨2,000, Salary +₨45,000
   - Chart: Bar chart showing recurring vs. total spending

2. **Recurring Transactions List**
   - Each item:
     - Icon + description (e.g., "Electricity Bill")
     - Amount + frequency ("₨2,500 / Monthly")
     - Confidence % ("90%")
     - Next occurrence date ("Next: Oct 15")
     - Actions: "Confirm", "Dismiss", "Edit"
   
   - Color badges:
     - Green: High confidence (>85%)
     - Yellow: Medium confidence (70-85%)
     - Gray: Low confidence (<70%, dismissed)

3. **Statistics Section**
   - Annual calculation: "₨30,000/year for Electricity"
   - Budget impact: Compare to category total

4. **Edit Modal**
   - Edit frequency: Daily / Weekly / Bi-weekly / Monthly / Quarterly
   - Edit amount (if prediction is wrong)
   - Set reminder (X days before)
   - "Save" button

---

### Screen 9: Tax Export

**Purpose**: Export data for tax filing  
**Layout**: Single column, scrollable  
**Header**: "Tax Export" + Back button

**Sections**:

1. **Export Options Card**
   - Date range picker: "Jan 1 - Dec 31" (default: fiscal year)
   - Format selector: CSV / PDF / Excel (radio buttons)
   - Category breakdown: Income / Expenses / Transfers (checkboxes)

2. **Export Preview**
   - Shows sample rows from export
   - Table preview: Date | Description | Category | Amount
   - Row count: "Showing 10 of 247 transactions"
   - Scroll to see more

3. **Action Buttons**
   - "Download": Saves file to device (CSV/XLSX/PDF)
   - "Email to Accountant": Optional email field
   - "Cancel": Close

4. **PDF Template Preview** (if PDF format selected)
   - Header: "Annual Expense Report 2026"
   - Summary: Total Income / Total Expenses / Net P&L
   - Categorical breakdown table
   - Monthly summary chart
   - Footer: "FBR Compliance Note"

---

## 4. Navigation Structure

### Bottom Tab Bar (5 tabs)
1. **Dashboard** (Home icon) → Dashboard screen
2. **Accounts** (Wallet icon) → Multi-Account Management
3. **Splits** (Share icon) → Event Splits
4. **Family** (People icon) → Family Accounts (Max tier only)
5. **Settings** (Gear icon) → Settings screen

### Settings Screen (Accessible from tab bar)
- Language selection (with flag icons)
- Currency (default: PKR)
- Notification preferences
- SMS permission status
- Account settings
- Help & Support

---

## 5. Interactions & Animations

### Transitions
- Screen changes: Slide from right (back: slide to right)
- Modal opens: Fade + slide up from bottom
- Card interactions: Slight scale (1.02x) on tap
- List items: Highlight on selection

### Haptic Feedback
- Tap feedback: Light haptic
- Payment settlement: Strong haptic
- Error: Alert pattern haptic

### Loading States
- Skeleton loaders: Shimmer animation on cards
- Pull-to-refresh: Spinner animation
- OCR processing: Progress indicator + "Processing..."

### Swipe Gestures
- Swipe left on transaction: Reveal delete/archive
- Swipe right on transaction: Undo/restore
- Swipe left on account: Reveal edit/delete

---

## 6. Accessibility

### Minimum Requirements
- Font size: 14px minimum (body text)
- Touch targets: 44×44px minimum
- Color contrast: WCAG AA compliant (4.5:1 for text)
- Alt text: All icons must have accessibility labels
- Screen reader support: All interactive elements labeled

### Dark Mode
- Same color palette, inverted backgrounds
- Blue → Lighter shade, Gray → Lighter shade
- Sufficient contrast maintained

---

## 7. Responsive Breakpoints

### Mobile (< 600px)
- Single column layout
- Full-width cards
- Bottom navigation tabs
- Font sizes: as specified

### Tablet (600px - 1200px)
- Two-column layout (optional)
- Wider cards with padding
- Side navigation panel (optional)
- Larger touch targets (48×48px)

### Desktop (> 1200px)
- Multi-column layout
- Side navigation drawer
- Compact mode (for dense data views)

---

## 8. Development Notes

### Key Files to Create
- `/src/i18n/en.json`, `/src/i18n/ur.json`, etc. (language strings)
- `/src/components/` (reusable components)
- `/src/screens/` (screen components)
- `/src/styles/theme.css` (color palette, typography)

### Testing Checklist
- [ ] All screens render on iPhone 12, iPhone 14 Pro Max
- [ ] All screens render on Samsung Galaxy S21, S23 Ultra
- [ ] Dark mode works on all screens
- [ ] RTL (Arabic) layout correct
- [ ] All language strings display correctly
- [ ] Haptic feedback working on iOS/Android
- [ ] SMS parsing accuracy tested with real SMS
- [ ] OCR accuracy tested with screenshots

### Performance Goals
- Screen load time: < 1s
- Transaction list scroll: 60 FPS
- SMS sync: < 100ms
- OCR processing: < 3s per screenshot

---

## 9. Next Steps

**Phase 1a (Weeks 1-2)**:
- [ ] SMS Auto-Logging screen + SMS READ permission
- [ ] Dashboard with account cards
- [ ] Navigation structure (bottom tabs)

**Phase 1b (Weeks 3-4)**:
- [ ] Bank Statement Import screen
- [ ] OCR screenshot import screen
- [ ] Multi-Account Management screen

**Phase 2 (Weeks 5+)**:
- [ ] Family Accounts screen
- [ ] Event Splits screen
- [ ] Recurring Transactions detection
- [ ] Tax Export functionality

---

## 10. Design Files & Assets

- Color palette: Use hex values as defined
- Icons: Use Material Design Icons (free)
- Fonts: Download Poppins, Inter, Noto Sans from Google Fonts
- Logo: Use existing Outlay logo
- Illustrations: Create simple, minimal illustrations for empty states

---

**Status**: ✅ Ready for Development  
**Next Action**: Start Phase 1a implementation on `feature/outlay-pro-v2` branch

