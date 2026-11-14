# Souren

Souren is an Android Persian writing and language app that combines an Arabic-to-Persian dictionary, a Persian keyboard, spelling assistance, and Persian literary references.

**Latest release:** [v0.4.7.6](https://github.com/AliAsgharPZ/Souren/releases/tag/v0.4.7.6)  
**Website:** https://souren.pages.dev

## What Souren does

- **Persian keyboard:** a Samsung-inspired Persian layout with Persian digits, secondary characters, a dedicated half-space key, and a suggestion/tool row.
- **Writing correction:** automatic half-space and ezafe-hamza correction, plus normalization of Arabic letters and Arabic-Indic digits to Persian forms.
- **Arabic-to-Persian dictionary:** search Arabic words, Persian equivalents, and meanings; inspect entries and their Persian structural base-form analysis. This is not presented as historical or comparative etymology.
- **Poetry library:** browse poets and books and search Ganjoor poems by title, poet, or words within the poem. A downloadable, chunked Zstandard pack enables on-device reading without extracting the full corpus; online access remains the fallback.
- **Pandevazhe:** a separate collection of Persian proverbs with their meanings.
- **Categories:** explore dictionary entries through subject-based categories.
- **Favorites and likes:** remain local to the Android device; website favorites and likes are stored with the website account.
- **Sharing and export cards:** share or save word and proverb details as formatted text or images.
- **User profile:** one shared account identity across the website, Souren, and Ario, with email OTP sign-in and verified email; the app also shows device-local score and badges.
- **Learning:** keyboard corrections and Ario lesson progress remain local to the device; they are not uploaded to the account.
- **Database management:** refresh the dictionary online, continue using the bundled/offline copy, and import or export JSON/CSV data.
- **Appearance:** cream/light and dark themes, adjustable text size, and RTL/LTR layout direction. The app uses Abar FaNum as its bundled interface font.

## Ario educational app

Ario currently ships inside the Souren APK as an Android library module with a separate launcher alias. Tapping its icon opens the same Souren package and Flutter shell in Ario mode; it is not yet an independently installable APK. Its winding, Duolingo-style learning path uses difficulty scores from 1 to 100 independently of stage numbering. Stages are generated from available content in five-entry lessons, so the stage count grows with the curriculum and is not capped at 100. Learning progress remains local to the device. Learning progress remains local to the device. Ario shares the signed-in account identity with Souren and the website.

## Website

The website includes a searchable dictionary, category filters, word details, account access, favorites/likes, and links to the Android release. The website uses Arad as a fallback because browser-delivered fonts cannot be made non-extractable: any font required for rendering in a browser can be inspected or downloaded by the visitor. The Android app itself uses Abar.

## Repository layout

- `android/` — Flutter application and Android project.
- `android/android/ario/` — Ario Android library module.
- `index.html`, `style.css`, `script.js` — static website (vanilla HTML/CSS/JS).
- `dictionary.json`, `categories.json` — website dictionary data and category data.
- `worker.js` — Cloudflare Worker API for dictionary, shared accounts, email OTP, and account synchronization.
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

## Shared account and email delivery

The website and Android app use the same Cloudflare Worker account identity. New website registrations verify an email with a one-time code; both the website and Android app can sign in with an email OTP. Existing password accounts can add and verify an email from the website profile. Android favorites, likes, keyboard learning and Ario lesson progress remain device-local and are not uploaded.

The Worker sends OTP email through Resend. Configure the Worker secret `RESEND_API_KEY` and the `EMAIL_FROM` variable with a sender address verified in Resend. Until those values are configured and the updated Worker is deployed, the OTP endpoints return `email_service_not_configured`.
