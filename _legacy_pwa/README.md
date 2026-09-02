# Kala-Setu — iOS App Prototype

A standalone, **tappable, installable** iOS prototype of the Kala-Setu artisan app.
Pure front-end (no backend, no build step) — it exists to be **tested on an iPhone**
and to drive the SIH demo / 6-slide deck. Separate from the deployable webapp in
[`../web`](../web).

## What it is
A clickable walkthrough of the full artisan journey, in the Kala-Setu design system:

`Language → Home → Voice cataloging (BHASHINI) → AI processing → AI Vision Studio + GI
→ Catalog review → Fair-Value pricing → Market match → Publish to ONDC → Published → QR profile`

Tap the primary buttons to move forward, the `‹` chevron to go back, the mic to toggle
"listening", and the language cards / bottom tabs to interact. It's a visual prototype
— the numbers are representative, not live.

## Files
- `index.html` — the whole prototype (open this)
- `manifest.webmanifest`, `icon-*.png`, `apple-touch-icon.png` — make it installable
- `concept-board.html` — all screens laid out side-by-side (design reference / for slides)
- `concept-board.artifact.html` — the same board, published as a shareable artifact
- `reference-stitch-screen1.png` — screen 1 as rendered natively by Stitch/Gemini

## Test it on iOS

**A. iOS Simulator (Mac + Xcode)**
```bash
cd ios && python3 -m http.server 4321
# then, in the Simulator's Safari:  open  http://localhost:4321
```
In Simulator Safari: **Share → Add to Home Screen** to install it as a full-screen app,
then launch it from the home screen (runs standalone, no browser chrome).

**B. On your own iPhone (same Wi-Fi)**
```bash
cd ios && python3 -m http.server 4321
# find your Mac's LAN IP:  ipconfig getifaddr en0
# on the iPhone, open Safari →  http://<that-ip>:4321
```
Then **Share → Add to Home Screen**.

**C. Quick look (any browser)**
Just open `ios/index.html`, then use the browser's device toolbar (e.g. iPhone 15) to
see it at phone size.

## Deploy it (optional)
Because it's static, it drops onto any static host (Vercel, Netlify, GitHub Pages) —
point the host at the `ios/` folder. This is independent of the main webapp deploy.
