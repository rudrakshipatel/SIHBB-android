# Hastakala — Android App (Flutter)

### Smart India Hackathon 2026 · Problem Statement SIH26090

The **Android** companion to the [Hastakala web app](https://github.com/rudrakshipatel/SIHBB),
built with **Flutter**. It mirrors the web app's format and Hastakala brand
(green / cream / terracotta) with the same two-sided experience:

- **Landing** — role selection: *I'm a Buyer* / *I'm an Artisan*, hero, trust points,
  the six craft categories, and For-Buyers / For-Artisans cards.
- **Buyer** (bottom nav: Home · Explore · Account) — marketplace hero, Shop-by-Category,
  featured products, category-filtered browse, product detail with **Inquire / Request Quote**.
- **Seller** (bottom nav: Dashboard · Products · Add · Inquiries · Profile) — dashboard with
  greeting banner, **profile-strength ring**, stat cards with sparklines, recent inquiries,
  my products, top insights and the QR banner; plus a voice-first "Add Product" flow outline.

You can switch between the Buyer and Seller sides from either home (top-right button)
or the Account/Profile tab.

> The six product categories, artisans and sample products mirror the web app's seed data.
> This build runs on bundled demo data (no backend) so it works fully offline — the same
> "demo mode" philosophy as the web app. A shared Supabase backend can be wired in later.

## Run

```bash
flutter pub get
flutter run                 # on a connected device / emulator
```

## Build an installable APK

```bash
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

## Project layout

```
lib/
  main.dart          App entry + theme
  theme.dart         Hastakala palette + serif display style
  data.dart          Models + mock data (categories, products, artisans, dashboard)
  widgets.dart       Logo, product card, category tile, sparkline, profile ring
  screens/
    landing.dart     Role-selection landing
    buyer.dart       Buyer shell + marketplace home + product browse
    product_detail.dart
    seller.dart      Seller shell + dashboard + products/add/inquiries/profile
assets/              Logo, hero photos, and the six category images (shared with web)
```

The previous HTML/PWA iOS prototype that lived in this repo is archived under `_legacy_pwa/`.
