# QuickSplit

QuickSplit is a blazing-fast, offline-first expense splitting application designed for college campuses and groups. It eliminates the friction of shared expenses with smart debt simplification, peer-to-peer offline syncing, and one-tap UPI settlements.

Built with Flutter, QuickSplit features a modern brutalist dark-mode interface that prioritizes speed, privacy, and ease of use.

## Table of Contents
* [Screenshots](#screenshots)
* [Technical Features](#technical-features)
  * [Offline-First Architecture](#offline-first-architecture)
  * [Peer-to-Peer Nearby Sync](#peer-to-peer-nearby-sync)
  * [Smart Debt Simplification](#smart-debt-simplification)
  * [NFC Tap-to-Sync (HCE)](#nfc-tap-to-sync-hce)
  * [ML-Powered Receipt Scanning](#ml-powered-receipt-scanning)
  * [Instant UPI Payments](#instant-upi-payments)
  * [Detailed Analytics](#detailed-analytics)
  * [Tamper-Evident Audit Log](#tamper-evident-audit-log)
  * [WhatsApp Nudge](#whatsapp-nudge)
* [Getting Started](#getting-started)
* [Privacy](#privacy)
* [License](#license)

---

## Screenshots

<!-- Add your screenshots below replacing the placeholder image links -->
<div align="center">
  <img src="https://via.placeholder.com/250x500.png?text=Main+Dashboard" width="200" alt="Main Dashboard (Net Balance)"/>
  &nbsp;&nbsp;&nbsp;
  <img src="https://via.placeholder.com/250x500.png?text=Add+Expense" width="200" alt="Add Expense & Receipt Scanner"/>
  &nbsp;&nbsp;&nbsp;
  <img src="https://via.placeholder.com/250x500.png?text=Settlements" width="200" alt="Settlements Tab (UPI Payments)"/>
</div>
<br>
<div align="center">
  <img src="https://via.placeholder.com/250x500.png?text=Nearby+Sync" width="200" alt="Nearby Sync (Peer-to-Peer)"/>
  &nbsp;&nbsp;&nbsp;
  <img src="https://via.placeholder.com/250x500.png?text=Analytics" width="200" alt="Analytics & Debt Graph"/>
  &nbsp;&nbsp;&nbsp;
  <img src="https://via.placeholder.com/250x500.png?text=Audit+Log" width="200" alt="Audit Log"/>
</div>

---

## Technical Features

### Offline-First Architecture
QuickSplit is built on a highly optimized, local SQLite database (`sqflite`). Because there is no reliance on cloud backend services (like Firebase or AWS), the app operates with zero latency. State management is handled entirely locally via `Provider`, ensuring instantaneous UI updates when modifying ledgers.

### Peer-to-Peer Nearby Sync
To keep groups synchronized without the internet, QuickSplit integrates the **Google Nearby Connections API**. The app discovers nearby peers using a combination of Bluetooth, BLE, and Wi-Fi Direct. When a sync is initiated, the SQLite ledger is serialized to JSON, heavily compressed using `GZip` (to bypass the API's 32KB payload constraints), and transmitted securely. The receiving device automatically merges and deduplicates the incoming ledger against its own.

### Smart Debt Simplification
QuickSplit implements a custom graph-theory algorithm to simplify group debts. Instead of tracking a complex web of "who owes who" (e.g., A owes B, B owes C), the engine calculates the net liquidity of every user. It then matches the maximum debtors with the maximum creditors, mathematically minimizing the total number of transactions required for the entire group to reach a net-zero balance.

### NFC Tap-to-Sync (HCE)
The app utilizes Android's **Host Card Emulation (HCE)** capabilities via `nfc_manager`. By emulating an NFC smart card, users can simply physically tap their phones together to instantly beam their QuickSplit User ID and profile data, bypassing the need for manual QR code scanning or network discovery.

### ML-Powered Receipt Scanning
QuickSplit embeds on-device OCR using **Google ML Kit Vision**. When a user snaps a picture of a receipt, the Vision engine extracts unstructured text blocks. The app then passes this raw text into a custom Natural Language Processing (NLP) regex engine that heuristically identifies items, prices, and totals, automatically generating a pre-filled expense split.

### Instant UPI Payments
The settlement engine integrates directly with India's Unified Payments Interface (UPI). By constructing specialized deep links (`upi://pay`), the app can instantly launch any installed UPI app (Google Pay, PhonePe, Paytm, etc.) pre-filled with the exact settlement amount and payee details. It also includes an embedded QR code scanner for fallback manual payments.

### Detailed Analytics
The analytics engine reads directly from the local ledger to calculate 7-day rolling averages, category distributions, and top spenders. The UI is built using custom `CustomPainter` classes to render high-performance, animated Brutalist-styled Donut and Bar charts natively on the GPU, without relying on heavy third-party charting libraries.

### Tamper-Evident Audit Log
To maintain group trust, QuickSplit features an append-only Audit Repository. Every database modification—whether it's an expense creation, deletion, or a UPI settlement—is permanently recorded in a tamper-evident log table. This ensures complete transparency across the group's financial history.

### WhatsApp Nudge
The app uses deep-linking intents to generate pre-filled WhatsApp messages. If a user is owed money, tapping the "Nudge" button opens a direct chat with the debtor, complete with an automated, polite reminder containing the exact debt amount.

---

## Getting Started

### Prerequisites
* Flutter SDK (3.24+)
* Android SDK 35+

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/kunjpatel007-gif/QuickSplit.git
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

### Building for Release
QuickSplit includes an automated GitHub Actions pipeline that builds highly optimized, ABI-split APKs on every push to the `main` branch. 

To build a release APK locally:
```bash
flutter build apk --split-per-abi --release
```

## Privacy
QuickSplit respects your privacy. All databases (SQLite) are stored locally on your device. The app only transmits data when you explicitly initiate a Nearby Sync or a UPI Intent. There are no cloud servers, no trackers, and no remote databases.

## License
[MIT License](LICENSE)
