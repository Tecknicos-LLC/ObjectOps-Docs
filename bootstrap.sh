#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# OBJECT-X AGENT BOOTSTRAP (Linux + macOS)
# ============================================================

AGENT_ID="$1"
TENANT_ID="$2"
TOKEN="$3"
BLOB_FILE="$4"      # <-- NOW A FILEPATH
GATEWAY_WS="$5"

# ------------------------------------------------------------
# Detect OS paths
# ------------------------------------------------------------
if [[ "$OSTYPE" == "darwin"* ]]; then
    ROOT_DIR="/usr/local/var/objectx"
else
    ROOT_DIR="/var/lib/objectx"
fi

LOG_FILE="$ROOT_DIR/bootstrap.log"
DECRYPT_URL="https://raw.githubusercontent.com/Tecknicos-LLC/ObjectOps-Docs/main/decrypt_installer.py"
DECRYPT_SCRIPT="$ROOT_DIR/decrypt_installer.py"
INSTALLER_PATH="$ROOT_DIR/service-config.sh"     # <-- SHELL SCRIPT OUTPUT

mkdir -p "$ROOT_DIR"

echo "=== ObjectX Bootstrap Installer ===" | tee "$LOG_FILE"
echo "Timestamp: $(date)" | tee -a "$LOG_FILE"

log() { echo "$1" | tee -a "$LOG_FILE"; }

# ------------------------------------------------------------
# 1. Download decryptor
# ------------------------------------------------------------
log "[1/5] Downloading decrypt_installer.py ..."
curl -fsSL "$DECRYPT_URL" -o "$DECRYPT_SCRIPT"
chmod +x "$DECRYPT_SCRIPT"

# ------------------------------------------------------------
# 2. Ensure Python exists
# ------------------------------------------------------------
command -v python3 >/dev/null 2>&1 || { 
    log "ERROR: python3 missing"; exit 1; 
}

# ------------------------------------------------------------
# 3. RUN DECRYPTOR → shell installer output
# ------------------------------------------------------------
log "[2/5] Running decryptor..."

DECRYPT_OUTPUT=$(python3 "$DECRYPT_SCRIPT" "$BLOB_FILE" "$TOKEN" 2>>"$LOG_FILE") \
    || { log "ERROR: decryptor failed"; exit 1; }

if [[ -z "$DECRYPT_OUTPUT" ]]; then
    log "ERROR: decryptor returned empty output"; exit 1;
fi

# ------------------------------------------------------------
# 4. Write installer script
# ------------------------------------------------------------
log "[3/5] Writing decrypted installer to $INSTALLER_PATH"

printf "%s" "$DECRYPT_OUTPUT" > "$INSTALLER_PATH"
chmod +x "$INSTALLER_PATH"

# ------------------------------------------------------------
# 5. RUN SERVICE INSTALLER
# ------------------------------------------------------------
log "[4/5] Executing service-config.sh ..."

bash "$INSTALLER_PATH" \
    "$AGENT_ID" \
    "$TENANT_ID" \
    "$GATEWAY_WS" \
    "$TOKEN" \
    2>&1 | tee -a "$LOG_FILE"

log "[5/5] ObjectX Agent installation completed successfully."
exit 0
