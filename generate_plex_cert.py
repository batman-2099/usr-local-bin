#!/usr/bin/env python3
import subprocess
import os
from datetime import datetime, timedelta
import shutil

# === CONFIGURATION ===
DOMAIN = "plex.thebatcomputer.com"
CF_CREDENTIALS = "/root/.secrets/cloudflare.ini"
OUTPUT_DIR = f"/etc/letsencrypt/live/{DOMAIN}"
P12_SRC = f"{OUTPUT_DIR}/plex_cert.p12"
P12_DEST = "/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/media.p12"
P12_PASSWORD = "Kindred12"
PLEX_SERVICE = "plexmediaserver.service"
DAYS_THRESHOLD = 30  # Days before expiration to trigger renewal

def run_cmd(cmd):
    """Run a shell command and return stdout, raising on failure."""
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit(f"[!] Command failed: {' '.join(cmd)}\n{result.stderr}")
    return result.stdout.strip()

def ensure_root():
    if os.geteuid() != 0:
        raise SystemExit("This script must be run as root.")

def cert_needs_renewal():
    """Check if existing cert is near expiry (less than threshold days)."""
    fullchain = os.path.join(OUTPUT_DIR, "fullchain.pem")
    if not os.path.exists(fullchain):
        print("[+] No existing certificate found — renewal required.")
        return True

    try:
        enddate_str = run_cmd(["openssl", "x509", "-enddate", "-noout", "-in", fullchain])
        enddate_str = enddate_str.replace("notAfter=", "").strip()
        expiry = datetime.strptime(enddate_str, "%b %d %H:%M:%S %Y %Z")
    except Exception as e:
        print(f"[!] Could not parse certificate expiry: {e}")
        return True

    days_left = (expiry - datetime.utcnow()).days
    print(f"[i] Certificate expires in {days_left} days ({expiry}).")

    if days_left > DAYS_THRESHOLD:
        print(f"[+] Certificate is still valid for more than {DAYS_THRESHOLD} days. No renewal needed.")
        return False

    print("[+] Certificate nearing expiration — renewal required.")
    return True

def obtain_certificate():
    print("[+] Obtaining or renewing Let's Encrypt certificate via Cloudflare DNS...")
    cmd = [
        "certbot", "certonly",
        "--dns-cloudflare",
        f"--dns-cloudflare-credentials={CF_CREDENTIALS}",
        "-d", DOMAIN,
        "--non-interactive", "--agree-tos", "-m", f"admin@{DOMAIN}",
        "--keep-until-expiring"
    ]
    run_cmd(cmd)

def export_p12():
    print("[+] Exporting certificate to PKCS#12 format for Plex...")
    fullchain = os.path.join(OUTPUT_DIR, "fullchain.pem")
    privkey = os.path.join(OUTPUT_DIR, "privkey.pem")

    if not os.path.exists(fullchain) or not os.path.exists(privkey):
        raise SystemExit("Certificate files not found. Did certbot succeed?")

    run_cmd([
        "openssl", "pkcs12", "-export",
        "-out", P12_SRC,
        "-inkey", privkey,
        "-in", fullchain,
        "-password", f"pass:{P12_PASSWORD}"
    ])

def deploy_to_plex():
    print("[+] Deploying certificate to Plex directory...")

    plex_dir = os.path.dirname(P12_DEST)
    if not os.path.exists(plex_dir):
        raise SystemExit(f"[!] Plex directory not found: {plex_dir}")

    shutil.copy2(P12_SRC, P12_DEST)

    # Optional: automatically set ownership to the Plex user
    try:
        import pwd
        plex_user = pwd.getpwnam("plex")
        os.chown(P12_DEST, plex_user.pw_uid, plex_user.pw_gid)
    except Exception as e:
        print(f"[!] Could not set file ownership: {e}")

    print(f"[+] Certificate deployed to: {P12_DEST}")

def restart_plex():
    print("[+] Restarting Plex Media Server...")
    run_cmd(["systemctl", "restart", PLEX_SERVICE])
    print("[+] Plex Media Server restarted successfully.")

def print_summary():
    print("\n✅ Certificate successfully generated and deployed!")
    print(f"  -> Domain: {DOMAIN}")
    print(f"  -> P12 Path: {P12_DEST}")
    print(f"  -> Password: {P12_PASSWORD}")
    print(f"  -> Checked/Renewed: {datetime.now().isoformat()}\n")

if __name__ == "__main__":
    ensure_root()

    if not cert_needs_renewal():
        print("[✔] Exiting — no renewal needed.")
        raise SystemExit(0)

    obtain_certificate()
    export_p12()
    deploy_to_plex()
    restart_plex()
    print_summary()

