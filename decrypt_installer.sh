#!/usr/bin/env bash

blob="$1"
regtoken="$2"

if [ -z "$blob" ] || [ -z "$regtoken" ]; then
  echo "Usage: decrypt_installer.sh <encryptedBlob> <registrationToken>"
  exit 1
fi

# ------------------------------------------------------------
# 1. Convert Base64URL → Base64
# ------------------------------------------------------------
b64="$blob"
b64="${b64//-/+}"
b64="${b64//_/\/}"

# Pad length to multiple of 4
pad=$(( ${#b64} % 4 ))
if [ $pad -eq 2 ]; then b64="${b64}=="
elif [ $pad -eq 3 ]; then b64="${b64}="
fi

# ------------------------------------------------------------
# 2. Decode Base64 → raw bytes
# ------------------------------------------------------------
raw_bytes=$(echo -n "$b64" | base64 -d | xxd -p -c 999999)

# Convert hex → binary
raw_bin=$(echo "$raw_bytes" | xxd -r -p)

# ------------------------------------------------------------
# 3. Extract IV + Ciphertext
# ------------------------------------------------------------
# IV = first 16 bytes
iv_hex=$(echo "$raw_bytes" | cut -c 1-32)
cipher_hex=$(echo "$raw_bytes" | cut -c 33-)

iv_bin=$(echo "$iv_hex" | xxd -r -p)
cipher_bin=$(echo "$cipher_hex" | xxd -r -p)

# ------------------------------------------------------------
# 4. Derive AES-256 key from regToken via SHA256
# ------------------------------------------------------------
key_hex=$(echo -n "$regtoken" | sha256sum | awk '{print $1}')
key_bin=$(echo "$key_hex" | xxd -r -p)

# ------------------------------------------------------------
# 5. AES-256-CBC decrypt (no padding errors)
# ------------------------------------------------------------
plain_bin=$(openssl enc -aes-256-cbc -d -nopad -K "$key_hex" -iv "$iv_hex" <<< "$cipher_bin" 2>/dev/null)

if [ -z "$plain_bin" ]; then
  echo "AES decrypt failed"
  exit 1
fi

# ------------------------------------------------------------
# 6. Remove PKCS7 padding
# ------------------------------------------------------------
pad_val=$(printf "%d" "'$(printf "%s" "$plain_bin" | tail -c 1)'")
plain_unpadded=$(printf "%s" "$plain_bin" | head -c -"$pad_val")

# ------------------------------------------------------------
# 7. GZIP decompress
# ------------------------------------------------------------
printf "%s" "$plain_unpadded" | gunzip
