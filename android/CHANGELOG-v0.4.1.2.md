# Souren 0.4.1.2 — candidate changes

- Restore the v0.4.1 expanding navigation layout; replace its glass surface with a solid color and retain the current CUI icons.
- Let the home word column consume the available height, expand it when search is focused, and keep the side shortcuts out of the focused state.
- Remove the search-focus blur overlay and the translucent sub-page title strip.
- Align the correction output to the right and make its copy action full width.
- Add a word-card root lookup and a searchable index of the 1,311 word/root pairs in the attributed Arabic Digital Humanities sample corpus (CC BY 4.0).
- Add an on-demand Ganjoor poetry reader with per-page local caching; the full corpus is not bundled in the APK.
- Refine Persian keyboard rows, half-space access, emoji shortcut, keycap shape, dark appearance, and press feedback.
- Normalize Arabic-Indic digits to Persian digits in both app and IME text correction.

The release remains a candidate until Flutter analysis, Dart tests, Kotlin IME tests, and a signed APK build all pass.
