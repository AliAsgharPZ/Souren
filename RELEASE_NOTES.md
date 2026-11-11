# Souren v0.4.7.1

- Rebuilt Ario as an educational companion using Souren's shared 552-entry dictionary and Ganjoor data, Abar font, and the exact Souren navigation shell.
- Added staged 12-word lessons, flashcards, multiple-choice practice, review, and learning progress.
- Added Ganjoor offline pack download/removal controls in Souren settings.
- Restored the original v0.4.6.9 switch geometry for Ario activation.
- Strengthened scroll fades while preserving the first and last list rows.
- Android profile, favorites, likes, and learning data remain local; no personal app data is uploaded.
- Synchronized the Android bundled dictionary with the canonical 552-entry website dataset, including the six missing words and their meanings.

- Applied the supplied Souren and Ario launcher icon artwork.
- Redesigned Ario's home screen as a winding, Duolingo-style lesson path with progress states and lesson icons.
- Added a persisted randomized weekly schedule for dictionary refresh requests to reduce Worker traffic.
- Added a lower-edge fade beneath the floating navigation bar and retained the home-list scroll fade.
- Added email OTP registration, email login and email linking endpoints to the Cloudflare Worker, plus website UI and Android shared account sessions. Email delivery uses Resend and requires Worker secrets/vars `RESEND_API_KEY` and `EMAIL_FROM`.

- Release APK refreshed with Android versionCode 24 under the existing v0.4.7.1 tag.
