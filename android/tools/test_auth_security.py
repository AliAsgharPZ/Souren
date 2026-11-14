import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
WORKER = (ROOT.parent / "worker.js").read_text()
STORE = (ROOT / "lib" / "data" / "store.dart").read_text()
MAIN = (ROOT / "lib" / "main.dart").read_text()
WEB = (ROOT.parent / "script.js").read_text()
HTML = (ROOT.parent / "index.html").read_text()
KOTLIN = (ROOT / "android" / "app" / "src" / "main" / "kotlin" / "ir" / "souren" / "souren" / "MainActivity.kt").read_text()

class AccountSecurityTests(unittest.TestCase):
    def test_password_login_is_rate_limited_and_uses_dummy_hash_for_unknown_users(self):
        self.assertIn("login:attempt:", WORKER)
        self.assertIn("attempts >= 8", WORKER)
        self.assertIn("expirationTtl: 900", WORKER)
        self.assertIn("MDEyMzQ1Njc4OWFiY2RlZg==", WORKER)

    def test_password_changes_revoke_existing_sessions(self):
        self.assertIn("authVersion: Number(rec.authVersion || 0)", WORKER)
        self.assertIn("Number(data.authVersion || 0) !== Number(rec.authVersion || 0)", WORKER)
        self.assertIn("rec.authVersion = Number(rec.authVersion || 0) + 1", WORKER)
        self.assertIn("case '/api/auth/change-password'", WORKER)

    def test_password_reset_and_change_require_eight_characters(self):
        self.assertIn("password.length < 8", WORKER)
        self.assertIn("newPassword.length < 8", WORKER)

    def test_otp_login_is_wired_to_the_app(self):
        self.assertIn("purpose: 'login'", MAIN)
        self.assertIn("mode == 'loginOtp'", MAIN)
        self.assertIn("ورود با کد", MAIN)

    def test_website_has_otp_login_and_authenticated_password_change(self):
        self.assertIn("async function doLoginOtp", WEB)
        self.assertIn("purpose: 'login'", WEB)
        self.assertIn("/api/auth/change-password", WEB)
        self.assertIn('id="loginOtpForm"', HTML)
        self.assertIn('id="changePasswordPanel"', HTML)
        self.assertIn("password.length < 8", WEB)

    def test_session_cookie_is_migrated_to_keystore_encryption(self):
        self.assertIn("readSecureString(_secureCookieKey)", STORE)
        self.assertIn("writeSecureString(_secureCookieKey", STORE)
        self.assertIn("deleteSecureString(_secureCookieKey)", STORE)
        self.assertIn('KeyStore.getInstance("AndroidKeyStore")', KOTLIN)
        self.assertIn('Cipher.getInstance("AES/GCM/NoPadding")', KOTLIN)

    def test_internal_auth_errors_do_not_expose_exception_details(self):
        self.assertNotIn("detail: String((e && e.message)", WORKER)
        self.assertIn("خطای داخلی سرویس حساب", WORKER)

if __name__ == "__main__":
    unittest.main()
