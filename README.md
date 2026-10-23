# Souren

Souren is an Arabic-to-Persian dictionary with a Samsung-style Persian keyboard for Android: automatic spelling and half-space correction, replacement of Arabic words with Persian equivalents, and on-device learning.

## Download

Get the latest Android APK from the [Releases](https://github.com/AliAsgharPZ/Souren/releases) page. The current release is [v0.3.1](https://github.com/AliAsgharPZ/Souren/releases/tag/v0.3.1). After installing, enable the Souren keyboard in the Android input settings and select it as the current keyboard.

The universal APK (arm64-v8a, armeabi-v7a, x86_64) is signed with the project's release key, so new versions install over older ones.

## Website

Live site: https://souren.aliasgharpanahizare.workers.dev — the same 552-entry dictionary in the browser, with search, categories, likes, and accounts that stay in sync with the app.

## Repository layout

- `android/` — the Flutter Android app (keyboard + dictionary). The app version lives in `android/pubspec.yaml`.
- `index.html`, `script.js`, `style.css` — the static website (vanilla JS/CSS, no build step).
- `dictionary.json`, `categories.json` — the website's dictionary data.
- `worker.js` — the Cloudflare Worker behind the site APIs (dictionary, auth, likes).
- `.github/workflows/ci.yml` — CI: dataset check, `flutter analyze`, tests, and a signed release APK build on pushes to `main` and on `v*` tags.

## Versioning

The site and the app share one version, following the `0.x.x` pattern (currently 0.3.1). Releases are cut from `main` through CI and published on the Releases page with the APK attached.
