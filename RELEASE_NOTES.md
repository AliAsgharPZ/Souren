# Souren v0.4.7.2

- Replaced the Souren launcher artwork with the exact supplied 1024×1024 design, rasterized directly to a square PNG with no added padding, zoom, repositioning, or adaptive-icon foreground crop.
- Removed adaptive and vector launcher overrides so Android resolves the supplied full-canvas PNG as the Souren app icon.
- Kept Ario's own supplied icon and educational flow. Ario remains a launcher alias inside the Souren APK, not a separately installed Android application; independent installation requires a separate application module/package and APK.
- Retained the 552-entry canonical dictionary, Ganjoor offline pack, Abar font, weekly randomized update schedule, shared email-OTP account identity, and device-local learning/favorites data.

Android package: `ir.souren.souren`  
Version name: `0.4.7.2`  
Version code: `25`


## v0.4.7.4
- Replaced Resend delivery with Gmail API using server-side OAuth refresh-token exchange.
- Completed email OTP login, registration and account email linking in the Android app and Ario.
- Kept website login, registration and profile email linking on the Worker OTP endpoints.
- Added the privacy policy page required for Google OAuth app publishing.
- Preserved the existing Workers KV binding and Worker API paths.
