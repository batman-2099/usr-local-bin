#!/usr/bin/env python3

import sys
import requests
import email

# === Postal API settings ===
POSTAL_API_KEY = "mexscoPMW6iqaO7rkvqhPqAk"
POSTAL_API_URL = "https://postal.resolveit.net/api/v1/send/message"

# === Read raw message from Postfix ===
raw_message = sys.stdin.read()

# === Parse message ===
msg = email.message_from_string(raw_message)

from_addr = msg['From']
to_addr = msg['To']
subject = msg['Subject']

# Extract plain text body
body = ""
if msg.is_multipart():
    for part in msg.walk():
        if part.get_content_type() == 'text/plain':
            body = part.get_payload(decode=True).decode()
            break
else:
    body = msg.get_payload(decode=True).decode()

# === JSON payload ===
payload = {
    "to": "patrick@thebatcomputer.com",
    "from": from_addr,
    "subject": subject,
    "plain_body": body
}

# === Required HTTP headers ===
headers = {
    "X-Server-API-Key": POSTAL_API_KEY,
    "Content-Type": "application/json"
}

# ✅ POST to Postal API!
response = requests.post(
    POSTAL_API_URL,
    headers=headers,
    json=payload
)

# Log result for Postfix logs
print(f"Postal API response: {response.status_code} {response.text}")
