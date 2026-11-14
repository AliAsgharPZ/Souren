#!/usr/bin/env python3
"""Generate the JSON value for the Cloudflare Worker ADMIN_CREDENTIALS secret.

Run from the repository root:
  python3 android/tools/generate_admin_credentials.py | npx wrangler secret put ADMIN_CREDENTIALS

The script prompts on stderr and writes only salted PBKDF2 hashes to stdout.
It never writes passwords or the generated secret to disk.
"""
import base64
import getpass
import hashlib
import json
import os
import sys

ADMIN_USERNAMES = ("AliAsgharPZ", "Wooxit", "JJ")
PBKDF2_ITERATIONS = 60000

def make_record(username: str) -> dict[str, str]:
    while True:
        password = getpass.getpass(f"New password for {username} (minimum 16 characters): ")
        if len(password) < 16:
            print("Password must contain at least 16 characters.", file=sys.stderr)
            continue
        confirmation = getpass.getpass(f"Confirm password for {username}: ")
        if password != confirmation:
            print("Passwords do not match.", file=sys.stderr)
            continue
        salt = os.urandom(16)
        digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, PBKDF2_ITERATIONS, dklen=32)
        return {"username": username, "salt": base64.b64encode(salt).decode("ascii"), "hash": base64.b64encode(digest).decode("ascii")}

def main() -> None:
    records = [make_record(username) for username in ADMIN_USERNAMES]
    json.dump(records, sys.stdout, ensure_ascii=False, separators=(",", ":"))
    sys.stdout.write("\n")

if __name__ == "__main__":
    main()
