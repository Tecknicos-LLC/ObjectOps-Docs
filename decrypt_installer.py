#!/usr/bin/env python3
import sys, subprocess, importlib, os, platform, base64, gzip, hashlib

# ============================================================
# AUTO-INSTALL SECTION (pip → venv fallback)
# ============================================================

VENV_DIR = os.path.join(os.path.dirname(__file__), ".decryptenv")
VENV_PY = os.path.join(VENV_DIR, "bin", "python3") if platform.system() != "Windows" else os.path.join(VENV_DIR, "Scripts", "python.exe")

def run(cmd):
    """Run a shell command safely."""
    try:
        subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return True
    except Exception:
        return False


def ensure_crypto():
    """Ensure Crypto.Cipher exists, otherwise install via pip or venv fallback."""
    try:
        importlib.import_module("Crypto.Cipher")
        return True
    except ImportError:
        print("[decrypt] pycryptodome missing — attempting system install...", file=sys.stderr)

    # ---------------------------------------
    # 1. Attempt system-level pip installs
    # ---------------------------------------
    pip_attempts = [
        [sys.executable, "-m", "pip", "install", "--user", "pycryptodome"],
        [sys.executable, "-m", "pip3", "install", "--user", "pycryptodome"],
        ["pip3", "install", "--user", "pycryptodome"],
        ["pip", "install", "--user", "pycryptodome"],
    ]

    for cmd in pip_attempts:
        if run(cmd):
            importlib.invalidate_caches()
            try:
                importlib.import_module("Crypto.Cipher")
                print("[decrypt] Successfully installed pycryptodome.", file=sys.stderr)
                return True
            except ImportError:
                pass

    print("[decrypt] pip install failed — attempting VENV fallback…", file=sys.stderr)

    # ---------------------------------------
    # 2. Create venv fallback
    # ---------------------------------------
    if not os.path.isdir(VENV_DIR):
        print(f"[decrypt] Creating venv at: {VENV_DIR}", file=sys.stderr)
        run([sys.executable, "-m", "venv", VENV_DIR])

    # Install pycryptodome inside venv
    print("[decrypt] Installing pycryptodome inside venv…", file=sys.stderr)
    run([VENV_PY, "-m", "pip", "install", "--quiet", "pycryptodome"])

    # Test import inside venv
    test_cmd = [VENV_PY, "-c", "import Crypto.Cipher"]
    if run(test_cmd):
        print("[decrypt] Venv install OK — re-launching script using venv interpreter.", file=sys.stderr)

        # Relaunch script with venv python
        os.execv(VENV_PY, [VENV_PY] + sys.argv)

    print("[decrypt] ERROR: Could not install pycryptodome", file=sys.stderr)
    print("        Try manually: pip install pycryptodome", file=sys.stderr)
    sys.exit(1)


ensure_crypto()
from Crypto.Cipher import AES

# ============================================================
# DECRYPTION LOGIC
# ============================================================

def log(msg):
    print(f"[decrypt] {msg}", file=sys.stderr)


def read_blob(input_arg):
    if input_arg == "-":
        return sys.stdin.read().strip()
    try:
        with open(input_arg, "r", encoding="utf-8", errors="ignore") as f:
            return f.read().strip()
    except Exception as e:
        log(f"ERROR reading blob: {e}")
        sys.exit(1)


def normalize_base64url(blob):
    blob = blob.replace("-", "+").replace("_", "/")
    pad = len(blob) % 4
    if pad == 2:
        blob += "=="
    elif pad == 3:
        blob += "="
    return blob


def derive_key(reg_token):
    sha = hashlib.sha256()
    sha.update(reg_token.encode("utf-8"))
    return sha.digest()


def decrypt_aes(iv, cipher, key):
    aes = AES.new(key, AES.MODE_CBC, iv)
    decrypted = aes.decrypt(cipher)
    pad_len = decrypted[-1]
    if pad_len < 1 or pad_len > 16:
        raise ValueError("Invalid PKCS7 padding")
    return decrypted[:-pad_len]


def gunzip_data(data):
    return gzip.decompress(data)


def main():
    if len(sys.argv) < 3:
        print("Usage:")
        print("  python3 decrypt_installer.py <blobFile|-> <regToken>")
        sys.exit(1)

    blob_source = sys.argv[1]
    reg_token = sys.argv[2]

    blob_raw = read_blob(blob_source)
    normalized = normalize_base64url(blob_raw)

    raw = base64.b64decode(normalized)

    iv = raw[:16]
    cipher = raw[16:]

    key = derive_key(reg_token)

    decrypted = decrypt_aes(iv, cipher, key)
    output = gunzip_data(decrypted)

    print(output.decode("utf-8", errors="replace"))


if __name__ == "__main__":
    main()
