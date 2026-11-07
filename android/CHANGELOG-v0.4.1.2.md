# Souren 0.4.1.2 — candidate changes

- Restore the exact v0.4.1 navigation geometry and interaction; replace only its glass surface with a solid color and keep the current CUI icon family.
- Let the home word column consume the available height, expand it when search is focused, and collapse side shortcuts in that state.
- Remove the search-focus blur and translucent sub-page title strip; make scroll-edge fades subtle and scroll-aware.
- Align correction output to the right and make its copy action full width.
- Add word-card root information and a searchable index of 1,311 attributed Arabic word/root pairs (CC BY 4.0).
- Add a lazy Ganjoor poetry reader with local caching of opened pages; the full corpus is not bundled in the APK.
- Refine the Persian keyboard layout, half-space access, emoji shortcut, keycap shape, dark appearance, and press/preview feedback.
- Normalize Arabic-Indic digits to Persian digits in both app and IME correction.

QA status: pending. This is a release candidate. It must pass Flutter analysis, Dart tests, Kotlin IME tests, and signed APK verification before publication.
