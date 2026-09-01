# DualBudget

A production-ready iOS personal budget tracking app built with SwiftUI and SwiftData that supports TWO currencies with independent ledgers.

## Features

### Core Functionality
- **Dual Currency Support**: Track finances in two currencies (default: LKR and AUD) independently without conversion
- **Balance Carry-Over**: Balances roll over month-to-month correctly
- **Transaction Management**: Add, edit, delete income/expense transactions
- **Budget Tracking**: Set monthly budgets per currency with progress visualization
- **Category Management**: Full CRUD for categories with icons and colors

### App Features
- **Dashboard**: Current in-hand balances, monthly summaries, category breakdown
- **Transactions Tab**: Filter by type, currency, search by note/category
- **Budgets Tab**: Set and track monthly budgets with exceeded warnings
- **Settings Tab**: Currency configuration, appearance, haptics, app lock

### Security
- **App Lock**: Face ID/Touch ID authentication using LocalAuthentication
- **Automatic Lock**: Locks when entering background

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Project Structure

```
DualBudget/
├── DualBudget.xcodeproj
└── DualBudget/
    ├── DualBudgetApp.swift          # App entry point
    ├── ContentView.swift            # Main TabView navigation
    ├── Info.plist                   # App configuration
    │
    ├── Models/                      # SwiftData models
    │   ├── Enums.swift             # TransactionType, CurrencyType, etc.
    │   ├── Transaction.swift       # Transaction entity
    │   ├── Category.swift          # Category entity with defaults
    │   ├── BudgetMonth.swift       # Monthly budget entity
    │   └── Settings.swift          # AppSettings entity
    │
    ├── Helpers/                     # Utility helpers
    │   ├── MonthHelper.swift       # Date/month utilities
    │   ├── MoneyFormatter.swift    # Currency formatting
    │   ├── HapticsHelper.swift     # Haptic feedback
    │   ├── ColorHelper.swift       # Hex color conversion
    │   └── BalanceCalculator.swift # Balance calculations
    │
    ├── Services/
    │   ├── DataSeeder.swift        # Idempotent default data seeding
    │   └── AuthenticationManager.swift # Face ID/Touch ID auth
    │
    └── Views/
        ├── LockView.swift          # App lock screen
        ├── Dashboard/
        │   └── DashboardView.swift
        ├── Transactions/
        │   ├── TransactionsView.swift
        │   └── AddEditTransactionView.swift
        ├── Budgets/
        │   └── BudgetsView.swift
        └── Settings/
            ├── SettingsView.swift
            └── CategoryManagerView.swift
```

## Data Seeding

Default data is seeded on first launch (idempotent - no duplicates on subsequent launches):

### Default Settings
- Primary Currency: LKR
- Secondary Currency: AUD
- Appearance: System
- Haptics: Enabled
- App Lock: Disabled

### Default Categories
- Food (fork.knife, red)
- Transport (car.fill, teal)
- Bills (doc.text.fill, blue)
- Entertainment (gamecontroller.fill, green)
- Health (heart.fill, pink)
- Shopping (bag.fill, purple)
- Salary (banknote.fill, mint)
- Other (ellipsis.circle.fill, gray)

**Seed Logic Location**: `DualBudget/Services/DataSeeder.swift`

## Authentication Logic

**Location**: `DualBudget/Services/AuthenticationManager.swift`

- Uses LocalAuthentication framework
- Supports Face ID and Touch ID
- Automatically locks when app enters background (if enabled)
- Gracefully handles devices without biometrics

## Key Balance Calculations

```
openingBalance(currency, month) = sum of all transactions before month start
  (income adds, expense subtracts)

monthNet(currency, month) = monthIncome - monthExpense

closingBalance(currency, month) = openingBalance + monthNet

currentInHand(currency) = sum of all transactions up to now
```

**Calculator Location**: `DualBudget/Helpers/BalanceCalculator.swift`

## Running the App

1. Open `DualBudget.xcodeproj` in Xcode 15+
2. Select an iOS 17+ simulator or device
3. Press ⌘R to build and run

## Testing on Device

For Face ID/Touch ID to work:
1. Enable a simulator with Face ID (Features > Face ID > Enrolled)
2. Or run on a physical device with biometrics enabled

## Dark Mode

The app fully supports dark mode. Users can configure:
- System (follows device setting)
- Light mode
- Dark mode

## Notes

- No third-party dependencies - pure SwiftUI + SwiftData
- No exchange rates or currency conversion - each currency is tracked independently
- All transactions are persisted locally using SwiftData
- Categories can be deleted (transactions become uncategorized)
