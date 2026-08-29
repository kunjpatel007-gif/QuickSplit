# Campus QuickSplit — Full Code Audit Report

## 1. FILE INVENTORY (55 Dart files read)

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── constants/app_constants.dart
│   ├── constants/category_icons.dart
│   ├── platform/platform_info.dart
│   ├── theme/app_theme.dart
│   ├── theme/app_spacing.dart
│   └── utils/ (currency_formatter, date_formatter, input_validators)
├── data/
│   ├── database/ (database_helper, tables)
│   ├── models/ (expense, user, expense_payer, expense_split, audit_log, expense_template, models barrel)
│   └── repositories/ (expense, user, audit, settings, template, barrel)
├── domain/
│   ├── providers/ (expense, user, balance, template, theme, barrel)
│   └── services/ (audit, balance, debt_simplifier, hce_pay, nlp_parser, split_engine, widget_service, barrel)
└── presentation/
    ├── screens/ (18 subdirs — 15 with files, 3 empty)
    └── widgets/ (balance_card, empty_state, expense_tile, section_header, staggered_list_item, barrel)
```

---

## 2. SCREENS — Detailed Implementation

### `onboarding_screen.dart`
**Bugs/Issues:**
- 🐛 **CRITICAL — BuildContext used across async gap without `mounted` check (lines 107–119):** Inside the dialog's `onTap` callback, after `await userProvider.createAndSetUser(...)`, the code does `if (!mounted) return;` followed by `ScaffoldMessenger.of(context)`. But `context` here is the `dialogContext` from `itemBuilder`, not the screen's context.
- 🐛 **Platform guard for scanner is incomplete:** Windows fallback gracefully fails without UI feedback.
- ⚠️ **No validation** on the name field in `_createProfile` — only checks `isEmpty`. `InputValidators.validateName` exists but is NOT used here.

### `dashboard_screen.dart`
**Bugs/Issues:**
- 🐛 **`_loadData()` uses `context` across async gap (lines 43-46):** Not guarded by `if (!mounted)`. If the widget is disposed during load, this will throw.
- 🐛 **Preset chip execution (lines 269–350):** Uses `context.read<>()` multiple times across multiple awaits.
- 🐛 **Template amount type issue (line 288-300):** `e['amountPaid'] as num` — but `amountPaid` from JSON may be stored as a `double`, and `as num` works, but then `.toDouble()` is not called — it stays `num`.
- ✅ **Infinite scroll not triggered:** The `_scrollController` is attached but there's no `addListener` to detect reaching the bottom. `loadMoreExpenses()` exists in `ExpenseProvider` but is **never called** from the dashboard.

### `add_expense_screen.dart`
**Bugs/Issues:**
- 🐛 **`_splitMode` initialized TWICE** (line 28 `= SplitMode.uniform` and line 45 in `initState`).
- 🐛 **`_category` initialized TWICE** (line 27 and line 46 in initState).
- 🐛 **`tt` variable declared on line 323 but never used** in `build()` — dead variable.
- 🐛 **NLP tab Submit button available when `_isNlpParsed` is false:** Validation logic has a dual path.
- 🐛 **In `_submit()`, `SplitMode.specific` case (line 277):** `final double tax = ...` re-declares `tax` (shadowing the outer `tax` on line 241).

### `analytics_screen.dart`
**Bugs/Issues:**
- 🐛 **`_buildTopSpendersList` parameter type is `dynamic userProvider` (line 291):** Should be typed as `UserProvider`.
- 🐛 **Analytics shows ALL historical expenses (including deleted, via `getAllExpensesHistorical()`):** This means deleted expenses count toward totals and averages.
- ⚠️ **`DonutChartPainter.shouldRepaint` always returns `true`**
- ⚠️ **`BarChartPainter.shouldRepaint` always returns `true`**

### `settlement_screen.dart`
**Bugs/Issues:**
- 🐛 **Settlement expense uses `expenseId: 0` in audit log (line 334):** The settlement audit entry is logged with `expenseId: 0` instead of the actual inserted expense ID. The audit trail for settlements points to expense ID 0.
- 🐛 **`_launchWhatsApp` doesn't handle the case where `canLaunchUrl` returns false** — if WhatsApp isn't installed, it silently does nothing.
- 🐛 **`_showSettlementProofDialog()` — context across async gap:** The `auditService` is re-instantiated locally (`AuditService()` on line 332) instead of reading it from Provider — creates a new instance unnecessarily.

### `audit_log_screen.dart`
**Bugs/Issues:**
- ⚠️ **`_getActionColor` doesn't handle `PERMANENTLY_DELETED` or `SETTLEMENT`** action types — they fall into `default` (gray).

### `recycle_bin_screen.dart`
**Bugs/Issues:**
- 🐛 **"Empty Bin" loop (lines 68-71):** Iterates `_deletedExpenses` calling `await context.read<ExpenseProvider>().permanentlyDeleteExpense(...)` in a for-loop. O(n) unnecessary reloads.
- 🐛 **Restore button (line 103–109):** After `restoreExpense`, calls `recalculateBalances` and `_loadDeleted` with no `mounted` check between awaits.

### `manage_users_screen.dart`
**Bugs/Issues:**
- ⚠️ **Add user via `_UserDialog` doesn't set UPI/phone** — `provider.addUser(name)` is called (line 153), which only sets the name. UPI and phone inputs are collected but silently discarded for new users.

### `settings_screen.dart`
**Bugs/Issues:**
- 🐛 **Dialog `TextEditingController`s (lines 35, 69, 103) are never disposed** — each dialog builds a controller locally in `onTap` callbacks, passes it to the dialog's builder, and never calls `.dispose()`. Memory leak.

### `presets_screen.dart`
**Bugs/Issues:**
- 🐛 **`_useTemplate` builds payers/splits from stored JSON but `amountPaid` and `amountOwed` are cast with `e['amountPaid']` directly (line 51) without `.toDouble()`.**
- ⚠️ **Dismissible in presets doesn't have a confirmation dialog** — swipe to delete is permanent and immediate.

### `qr_sync_screen.dart`
**Bugs/Issues:**
- 🐛 **`_selectedExpenseIds` (line 25) is declared and never read or written.** Dead state variable.
- 🐛 **`_generatePayload()` uses `FutureBuilder` (line 348) on every build without caching.** Causes the QR to regenerate and flicker on any state change.
- 🐛 **`_importExpenses()` (line 121):** Multiple awaits happen inside the for-loop with no intermediate mounted checks.
- 🐛 **`_shareViaWhatsApp` sends `quicksplit://sync?payload=...` (line 94)** but the deep link handler in `app.dart` expects `quicksplit://sync?data=...` (line 77). **Key mismatch — shared links cannot be imported via deep link!**

### `nearby_sync_screen.dart`
**Bugs/Issues:**
- 🐛 **`_localDisplayName` constant (line 27)** is defined but never used.
- ⚠️ **No UI to send ALL expenses** to a peer, only one expense at a time. *(Fix implemented)*

### `hce_tap_pay_screen.dart`
**Bugs/Issues:**
- 🐛 **`_handlePeerDetected()` (lines 128–171):** Uses `context` (via `context.read<>()`) on a background thread potentially after dispose.
- 🐛 **HCE only resolves peer by name (line 154)** — not by UUID/syncId. If two users share the same name, wrong user could be matched.

### `receipt_scanner_screen.dart`
**Bugs/Issues:**
- 🐛 **Tax items (chips) are NOT draggable to users** — only items in `_extractedItems` use `Draggable`.
- 🐛 **`_createExpense()` (line 167):** If `_assignedItems` is empty but items have been extracted, the button is still enabled and does nothing.
- 🐛 **Row reconstruction algorithm (lines 83–96):** Naive Y-midpoint overlap check can produce incorrect row groupings for complex receipt layouts.

### `debt_graph_screen.dart`
*(Note: Screen was fully rewritten after this audit, fixing all identified issues).*

---

## 6. KNOWN ISSUES — Consolidated

### 🔴 CRITICAL BUGS

| # | Location | Issue |
|---|----------|-------|
| 1 | `expense_provider.dart` L139–143 | **Wrong delete method called:** `updateExpense()` deletes old payers/splits using `permanentlyDeleteExpense(p.id!)` — this deletes the **Expense record** (via the Expenses table), not the payer/split records. Should call a payer-delete/split-delete method. There is no `deleteExpensePayer` or `deleteExpenseSplit` method in `ExpenseRepository`. This means updating an expense **permanently deletes unrelated records** or throws if the ID doesn't exist in Expenses. **HIGH SEVERITY DATA CORRUPTION BUG.** |
| 2 | `qr_sync_screen.dart` L94 vs `app.dart` L77 | Deep-link share uses `?payload=` key but app.dart handler reads `?data=` key. Shared QR links imported via WhatsApp deep link **will never work**. |
| 3 | `settlement_screen.dart` L334 | Settlement audit log entry uses `expenseId: 0` instead of the actual inserted ID. Audit trail for settlements is broken. |
| 4 | `settings_screen.dart` L35/69/103 | Three `TextEditingController`s created in `onTap` callbacks are **never disposed**. Each dialog open leaks a controller. |

### 🟠 HIGH SEVERITY

| # | Location | Issue |
|---|----------|-------|
| 5 | `balance_provider.dart` L32 | `double myBalance = _balances[1] ?? 0.0` — hardcodes user ID 1 for the home widget update. If first user has a different ID, widget always shows 0. |
| 6 | `dashboard_screen.dart` | `loadMoreExpenses()` is implemented in provider but **never triggered** from the scroll controller. Pagination is silently broken. |
| 7 | `qr_sync_screen.dart` L348 | `FutureBuilder<String>` recreates the future on every rebuild, causing QR to regenerate and flicker. |
| 8 | `debt_graph_screen.dart` `shouldRepaint` | Edge painter doesn't repaint when nodes are dragged (node map reference unchanged). Edges don't visually track dragged nodes. (FIXED) |
| 9 | `hce_tap_pay_screen.dart` L154 | Peer resolved only by name, not UUID — name collision causes wrong user match. |
| 10 | `nearby_sync_screen.dart` | `expenseToShare` is always null from dashboard (no expense is passed). "Send Expense" button is always disabled when opened from dashboard. Dead feature. (FIXED) |

### 🟡 MEDIUM SEVERITY

| # | Location | Issue |
|---|----------|-------|
| 11 | `recycle_bin_screen.dart` L68 | Empty-bin loop calls `permanentlyDeleteExpense` (which calls `loadExpenses()`) N times — O(n) unnecessary loads. |
| 12 | `manage_users_screen.dart` `_save` | UPI/phone fields in "Add User" dialog are collected but silently discarded. Only name is saved for new users. |
| 13 | `presets_screen.dart` L51 | `e['amountPaid']` not cast to double — potential runtime type error on parse. |
| 14 | `dashboard_screen.dart` L288–300 | Template `amountPaid` cast uses `as num` without `.toDouble()`. Same runtime risk. |
| 15 | `audit_log_screen.dart` | `PERMANENTLY_DELETED` and `SETTLEMENT` action types not handled in `_getActionColor`/`_getActionIcon` — show generic gray/history. |
| 16 | `onboarding_screen.dart` | Name field doesn't use `InputValidators.validateName` — empty/whitespace names allowed. |
| 17 | `analytics_screen.dart` L291 | `_buildTopSpendersList` parameter typed as `dynamic` instead of `UserProvider` — loses type safety. |

### 🟢 LOW / STYLE

| # | Location | Issue |
|---|----------|-------|
| 18 | `add_expense_screen.dart` L27-28,45-46 | `_splitMode` and `_category` initialized twice (field initializer + initState). Dead first initialization. |
| 19 | `qr_sync_screen.dart` L25 | `_selectedExpenseIds` state variable is declared and never used. Dead code. |
| 20 | `nearby_sync_screen.dart` L27 | `_localDisplayName` constant is never used. Dead constant. (FIXED) |
| 21 | `app.dart` L103 | Dialog amount shows `\$$amount` (dollar sign) instead of `₹$amount`. Wrong currency symbol. |
| 22 | `settings_screen.dart` L14 | Uses `{Key? key}` + `super(key: key)` — old style. Rest of app uses `super.key`. |
| 23 | `debt_graph_screen.dart` L44 | `_buildGraph()` called from `didChangeDependencies` instead of `initState` — rebuilds graph on any inherited widget change. (FIXED) |
| 24 | `settlement_screen.dart` L332 | `AuditService()` instantiated locally instead of reading from Provider — wasteful. |

---

## 7. MISSING FUNCTIONALITY

| Feature | Evidence | Status |
|---------|----------|--------|
| `scan_receipt/` directory | Empty | **No screen files — presumably meant for a different receipt flow** |
| `sync/` directory | Empty | **No files** |
| `templates/` directory | Empty | **No files** |
| Edit existing expense | `updateExpense` exists in provider but **no screen navigates to an edit flow** — `ExpenseTile.onTap` is null in dashboard. There is no edit expense screen. | Missing |
| Expense detail view | No screen exists to view payers/splits for a single expense | Missing |
| Delete user | `UserRepository.deleteUser` exists but **no UI exposes it** | Missing |
| Scroll-to-load-more | `loadMoreExpenses()` and `hasMore`/`currentOffset` exist in provider but the dashboard scroll controller has no listener | Missing |
| `TemplateRepository.updateTemplate` | Method exists but no screen calls it — can't edit a preset | Missing |
| Home screen widget (Android) | `WidgetService.updateBalanceWidget` exists and is called, but the native `BalanceWidgetProvider` Android code is unknown — Flutter side is implemented | Unclear |
| `validateGroupSize` in `InputValidators` | Method exists but **is never called anywhere** in the codebase | Dead code |
| `BalanceService.getUserBalance()` | Method re-calculates balances from scratch — only `calculateNetBalances` is used | Dead method |

---

## 8. DUPLICATED LOGIC

| Duplication | Files |
|-------------|-------|
| `resolveUser()` local function | Defined **twice** — once in `qr_sync_screen.dart` (line 214) and again in `nearby_sync_screen.dart` (line 317). Identical logic to find/create user by syncId then by name. Should be a shared utility. |
| Deduplication check (title+amount+date) | Duplicated in `qr_sync_screen.dart` (lines 196–211) and `nearby_sync_screen.dart` (lines 299–315). Identical block. |
| User profile sync payload structure | Built in `qr_sync_screen.dart` (line 55), `nearby_sync_screen.dart` (line 209), and `app.dart` (line 130). Same JSON structure, three places. |
| UPI launch | `_launchUpi` implemented in both `settlement_screen.dart` (line 359) and `hce_tap_pay_screen.dart` (line 232). Identical logic. Should be a shared utility. |
| Preset "use template" logic | Duplicated between `dashboard_screen.dart` (lines 269–350) and `presets_screen.dart` (lines 35–81). Both build expense+payers+splits from JSON and call `addExpense`. |
