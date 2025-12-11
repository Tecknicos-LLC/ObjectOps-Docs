function Decrypt-InstallerBlob {
    param(
        [string]$Blob,
        [string]$RegToken
    )

    # 1. Decode Base64
    $bytes = [Convert]::FromBase64String($Blob)

    # 2. Split IV + Cipher
    $IV = $bytes[0..15]
    $CipherBytes = $bytes[16..($bytes.Length-1)]

    # 3. AES Key = SHA256(regToken)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $KeyBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($RegToken))

    # 4. Setup AES
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Mode = "CBC"
    $aes.Padding = "PKCS7"
    $aes.Key = $KeyBytes
    $aes.IV  = $IV

    $decryptor = $aes.CreateDecryptor()

    # 5. Decrypt payload
    $plainBytes = $decryptor.TransformFinalBlock($CipherBytes, 0, $CipherBytes.Length)
    return [System.Text.Encoding]::UTF8.GetString($plainBytes)
}
