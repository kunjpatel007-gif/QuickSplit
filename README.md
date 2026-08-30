# QuickSplit

QuickSplit is a blazing-fast, offline-first expense splitting application designed for college campuses and groups. It eliminates the friction of shared expenses with smart debt simplification, peer-to-peer offline syncing, and one-tap UPI settlements.

Built with Flutter, QuickSplit features a modern brutalist dark-mode interface that prioritizes speed, privacy, and ease of use.

## Features

* **Offline-First Architecture**: Your data lives on your device. No cloud accounts, no sign-ups, no latency.
* **Peer-to-Peer Nearby Sync**: Share and merge entire group ledgers with friends in seconds using Google Nearby Connections (Bluetooth/Wi-Fi Direct)—completely offline.
* **Smart Debt Simplification**: The built-in settlement engine automatically calculates the minimum number of transactions needed to settle all group debts.
* **Instant UPI Payments**: Settle debts instantly via direct UPI intents or by scanning a friend's GPay QR code directly within the app.
* **ML-Powered Receipt Scanning**: Point your camera at a receipt and let Google ML Kit automatically extract items, prices, and totals.
* **Detailed Analytics**: Track personal and group spending over time with interactive pie charts, 7-day trend bars, and top spender leaderboards.
* **Tamper-Evident Audit Log**: Every expense, edit, and settlement is permanently recorded in an unalterable history log so everyone stays accountable.
* **Nudge**: Send polite (or urgent) WhatsApp reminders to friends who owe you money with a single tap.

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

## Getting Started

### Prerequisites
* Flutter SDK (3.24+)
* Android SDK 35+

### Installation
1. Clone the repository:
   `ash
   git clone https://github.com/kunjpatel007-gif/QuickSplit.git
   `
2. Fetch dependencies:
   `ash
   flutter pub get
   `
3. Run the app:
   `ash
   flutter run
   `

### Building for Release
QuickSplit includes an automated GitHub Actions pipeline that builds highly optimized, ABI-split APKs on every push to the main branch. 

To build a release APK locally:
`ash
flutter build apk --split-per-abi --release
`

## Privacy
QuickSplit respects your privacy. All databases (SQLite) are stored locally on your device. The app only transmits data when you explicitly initiate a Nearby Sync or a UPI Intent.

