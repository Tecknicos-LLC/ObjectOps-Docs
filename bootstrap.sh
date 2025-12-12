#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# OBJECT-X AGENT BOOTSTRAP (Linux + macOS)
# ============================================================

AGENT_ID="$1"
TENANT_ID="$2"
TOKEN="$3"
BLOB="$4"
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

INSTALLER_PATH="$ROOT_DIR/service-config.sh"   # <-- FIXED (it's a .sh script)

mkdir -p "$ROOT_DIR"

echo "=== ObjectX Bootstrap Installer ===" | tee "$LOG_FILE"
echo "Timestamp: $(date)" | tee -a "$LOG_FILE"

log() {
    echo "$1" | tee -a "$LOG_FILE"
}

# ------------------------------------------------------------
# 1. DOWNLOAD PYTHON DECRYPTOR
# ------------------------------------------------------------
log "[1/5] Downloading decrypt_installer.py ..."
if ! curl -fsSL "$DECRYPT_URL" -o "$DECRYPT_SCRIPT"; then
    log "ERROR: Failed to download decrypt_installer.py"
    exit 1
fi

chmod +x "$DECRYPT_SCRIPT"

# ------------------------------------------------------------
# 2. ENSURE PYTHON3 EXISTS
# ------------------------------------------------------------
if ! command -v python3 >/dev/null 2>&1; then
    log "ERROR: python3 not found. Install python3 and retry."
    exit 1
fi

# ------------------------------------------------------------
# 3. RUN DECRYPTOR → PRODUCE INSTALLER (Bash script)
# ------------------------------------------------------------
log "[2/5] Running decryptor..."

DECRYPT_OUTPUT=$(python3 "$DECRYPT_SCRIPT" "$BLOB" "$TOKEN" 2>>"$LOG_FILE") || {
    log "ERROR: decryptor failed"
    exit 1
}

if [[ -z "$DECRYPT_OUTPUT" ]]; then
    log "ERROR: decryptor returned empty output"
    exit 1
fi

# ------------------------------------------------------------
# 4. WRITE INSTALLER BASH SCRIPT
# ------------------------------------------------------------
log "[3/5] Writing decrypted installer to $INSTALLER_PATH"

printf "%s" "$DECRYPT_OUTPUT" > "$INSTALLER_PATH"
chmod +x "$INSTALLER_PATH"

if [[ ! -s "$INSTALLER_PATH" ]]; then
    log "ERROR: Failed to write service-config.sh"
    exit 1
fi

# ------------------------------------------------------------
# 5. EXECUTE INSTALLER BASH SCRIPT
# ------------------------------------------------------------
log "[4/5] Executing service-config.sh ..."

bash "$INSTALLER_PATH" \
    --agent-id "$AGENT_ID" \
    --tenant-id "$TENANT_ID" \
    --registration-token "$TOKEN" \
    --gateway-ws "$GATEWAY_WS" \
    2>&1 | tee -a "$LOG_FILE"

log "[5/5] ObjectX Agent installation completed successfully."

exit 0
