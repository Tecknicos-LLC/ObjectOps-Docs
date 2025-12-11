function Decrypt-InstallerBlob {
    param(
        [Parameter(Mandatory)][string]$Blob,
        [Parameter(Mandatory)][string]$RegToken
    )

    #
    # ------------------------------------------------------------
    # 1. Normalization: Convert Base64-URL → Standard Base64
    # ------------------------------------------------------------
    #

    # Replace URL-safe chars
    $Blob = $Blob.Replace('-', '+').Replace('_', '/')

    # Fix padding
    switch ($Blob.Length % 4) {
        2 { $Blob += '==' }
        3 { $Blob += '=' }
        1 { throw "Invalid Base64URL length." }
    }

    #
    # ------------------------------------------------------------
    # 2. Decode Base64 into raw bytes
    # ------------------------------------------------------------
    #
    try {
        $bytes = [Convert]::FromBase64String($Blob)
    }
    catch {
        throw "Failed to decode Base64 blob. Inner: $($_.Exception.Message)"
    }

    #
    # ------------------------------------------------------------
    # 3. Extract IV and Ciphertext
    # ------------------------------------------------------------
    #
    if ($bytes.Length -lt 17) {
        throw "Blob too short to contain IV + ciphertext."
    }

    $IV = $bytes[0..15]
    $CipherBytes = $bytes[16..($bytes.Length - 1)]

    #
    # ------------------------------------------------------------
    # 4. Derive AES-256 Key = SHA256(RegToken)
    # ------------------------------------------------------------
    #
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $KeyBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($RegToken))

    #
    # ------------------------------------------------------------
    # 5. AES-256-CBC Decrypt
    # ------------------------------------------------------------
    #
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Mode    = "CBC"
    $aes.Padding = "PKCS7"
    $aes.Key     = $KeyBytes
    $aes.IV      = $IV

    try {
        $decryptor = $aes.CreateDecryptor()
        $plainBytes = $decryptor.TransformFinalBlock($CipherBytes, 0, $CipherBytes.Length)
    }
    catch {
        throw "AES decrypt failed. Possibly wrong token or corrupted blob. Inner: $($_.Exception.Message)"
    }

    #
    # ------------------------------------------------------------
    # 6. Convert bytes → UTF8 string
    # ------------------------------------------------------------
    #
    return [System.Text.Encoding]::UTF8.GetString($plainBytes)
}
