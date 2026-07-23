# BillBuddy 🧾

A cross-platform personal bookkeeping app built with Flutter.
Track expenses and income across multiple currencies and ledgers,
with Excel import/export and beautiful charts.

## Features

- 📒 **Multi-ledger** — Create separate books for personal, travel, business, etc.
- 💰 **Multi-currency** — Record transactions in any currency with exchange rate conversion
- 📊 **Statistics** — Pie charts for category breakdown, bar charts for monthly trends
- 📁 **Excel import/export** — Backup or batch-add transactions via `.xlsx` files
- 🗂 **Categories** — Built-in expense & income categories with icons
- 🎨 **Material Design 3** — Clean, modern UI with dark mode support
- 📱 **Mobile-friendly** — Bottom sheets, swipe-to-delete, large touch targets

## Platforms

| Platform | Status |
|----------|--------|
| macOS | ✅ |
| Windows | ✅ (CI builds) |
| Linux | ✅ (CI builds) |
| iOS | ✅ |
| Android | ✅ |

## Quick Start

```bash
# Clone
git clone https://github.com/dadaozhichen/billbuddy.git
cd billbuddy

# Run
flutter pub get
flutter run -d macos   # or -d windows, -d linux, -d ios, -d android
```

## Build from Source

```bash
# macOS
flutter build macos --release

# Windows (requires Windows host)
flutter build windows --release

# Linux (requires Linux host)
flutter build linux --release

# iOS (requires macOS + Xcode)
flutter build ios --release

# Android
flutter build appbundle --release
```

## Download Installers

Pre-built installers for all platforms are available on the
[Releases](https://github.com/dadaozhichen/billbuddy/releases) page,
or built on-demand via
[GitHub Actions](https://github.com/dadaozhichen/billbuddy/actions).

| Platform | Installer Format |
|----------|-----------------|
| 🪟 Windows | `billbuddy-setup-*.exe` |
| 🍎 macOS | `billbuddy-macos-*.dmg` |
| 🐧 Linux | `billbuddy-*.deb` |

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.44+ / Dart 3.12+ |
| State Management | Riverpod |
| Database | SQLite (sqflite) |
| Charts | fl_chart |
| Excel | excel (pure Dart) |

## License

```
Copyright © 2026 zhuhkblog.cn. All rights reserved.
```
