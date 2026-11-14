# Secure admin authentication setup

The admin panel no longer reads or writes `admins.json`. The Worker accepts three salted PBKDF2-SHA256 credential records only from the `ADMIN_CREDENTIALS` Worker secret. Passwords must be at least 16 characters. Each admin receives an HttpOnly, Secure, eight-hour session cookie after server-side verification.

## Rotate all three admin passwords

1. Authenticate to Cloudflare locally with Wrangler (`npx wrangler login`) if you have not already.
2. From the repository root, run:

   ```sh
   python3 android/tools/generate_admin_credentials.py | npx wrangler secret put ADMIN_CREDENTIALS
   ```

3. Enter and confirm a new password for each of the three existing admin usernames when prompted. Password input is hidden. The generator emits only per-account salt and PBKDF2 hash; it does not save passwords or the secret to disk.
4. Confirm Wrangler reports that the Worker secret was uploaded.
5. Deploy the Worker with the existing **Deploy Souren Worker** workflow. The deployment uses `--keep-vars`, preserving Worker secrets.
6. Verify that the admin login succeeds for each new credential, that the previous credentials fail, and that an unauthenticated `/api/upload` request returns HTTP 401.

Do not put the generated JSON, any password, or a Cloudflare API token in Git, issues, pull requests, or chat. The three old passwords have to be treated as compromised because they were committed to the public repository; removing the current file does not erase old Git history, so rotating them is mandatory.
