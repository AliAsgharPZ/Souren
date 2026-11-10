# Souren

Souren is an Android Persian writing and language app that combines an Arabic-to-Persian dictionary, a Persian keyboard, spelling assistance, and Persian literary references.

**Latest release:** [v0.4.6.8](https://github.com/AliAsgharPZ/Souren/releases/tag/v0.4.6.8)  
**Website:** https://souren.pages.dev

## What Souren does

- **Persian keyboard:** a Samsung-inspired Persian layout with Persian digits, secondary characters, a dedicated half-space key, and a suggestion/tool row.
- **Writing correction:** automatic half-space and ezafe-hamza correction, plus normalization of Arabic letters and Arabic-Indic digits to Persian forms.
- **Arabic-to-Persian dictionary:** search Arabic words, Persian equivalents, and meanings; inspect entries and their Persian structural base-form analysis. This is not presented as historical or comparative etymology.
- **Poetry library:** browse poets and books and search Ganjoor poems by title, poet, or words within the poem. A downloadable, chunked Zstandard pack enables on-device reading without extracting the full corpus; online access remains the fallback.
- **Pandevazhe:** a separate collection of Persian proverbs with their meanings.
- **Categories:** explore dictionary entries through subject-based categories.
- **Favorites and likes:** save entries and like them; signed-in users can synchronize their profile data.
- **Sharing and export cards:** share or save word and proverb details as formatted text or images.
- **User profile:** sign in or register, view profile information, score, level, and earned badges.
- **Learning:** keyboard corrections and choices are learned locally on the device. An optional, disabled-by-default improvement setting can send limited anonymous correction context; it does not send full text or clipboard contents.
- **Database management:** refresh the dictionary online, continue using the bundled/offline copy, and import or export JSON/CSV data.
- **Appearance:** cream/light and dark themes, adjustable text size, and RTL/LTR layout direction. The app uses Abar FaNum as its bundled interface font.

## Ario module

Ario is kept in the same repository as a separate Android library module under `android/android/ario/`. Its launcher icon can be enabled or disabled from Souren settings; disabling it hides only the Ario icon and preserves its data. Ario has a separate Activity, preferences, database name and private storage directory, but it shares the installed Android package with Souren and cannot be uninstalled independently.

## Website

The website includes a searchable dictionary, category filters, word details, account access, favorites/likes, and links to the Android release. The website uses Arad as a fallback because browser-delivered fonts cannot be made non-extractable: any font required for rendering in a browser can be inspected or downloaded by the visitor. The Android app itself uses Abar.

## Repository layout

- `android/` — Flutter application and Android project.
- `android/android/ario/` — Ario Android library module.
- `index.html`, `style.css`, `script.js` — static website (vanilla HTML/CSS/JS).
- `dictionary.json`, `categories.json` — website dictionary data and category data.
- `worker.js` — Cloudflare Worker API for dictionary, account, and like synchronization.
- `.github/workflows/` — CI, dataset integrity, and signed Android release workflows.

## Build and test

From the `android/` directory:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

The production release workflow also validates the dictionary dataset, runs Kotlin IME unit tests, signs the APK with the configured production key, and verifies the package ID and version metadata before publishing.

## Keyboard setup

After installing Souren, open Android's keyboard/input-method settings, enable **کیبورد سورن**, and select it as the current keyboard.
