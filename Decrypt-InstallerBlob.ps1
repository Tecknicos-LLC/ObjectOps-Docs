function Decrypt-InstallerBlob {
    param(
        [string]$Blob,
        [string]$RegToken
    )

    # Decode Base64 → bytes
    $bytes = [Convert]::FromBase64String($Blob)

    # Extract IV + ciphertext
    $IV = $bytes[0..15]
    $CipherBytes = $bytes[16..($bytes.Length-1)]

    # Key = SHA256(token)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $KeyBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($RegToken))

    # AES decryptor
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Mode = "CBC"
    $aes.Padding = "PKCS7"
    $aes.Key = $KeyBytes
    $aes.IV  = $IV

    $decryptor = $aes.CreateDecryptor()

    # AES → plaintext bytes (still gzipped)
    $plainBytes = $decryptor.TransformFinalBlock($CipherBytes, 0, $CipherBytes.Length)

    # Now decompress the gzip payload
    $ms = New-Object System.IO.MemoryStream(,$plainBytes)
    $gzip = New-Object System.IO.Compression.GzipStream($ms, [IO.Compression.CompressionMode]::Decompress)

    $outMs = New-Object System.IO.MemoryStream
    $buffer = New-Object byte[] 4096

    while (($read = $gzip.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $outMs.Write($buffer, 0, $read)
    }

    $gzip.Dispose()
    $ms.Dispose()

    return [System.Text.Encoding]::UTF8.GetString($outMs.ToArray())
}
