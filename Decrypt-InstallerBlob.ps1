function Decrypt-InstallerBlob {
    param(
        [Parameter(Mandatory)][string]$Blob,
        [Parameter(Mandatory)][string]$RegToken
    )

    # ------------------------------------------------------------
    # 1. Base64URL → Base64 normalize
    # ------------------------------------------------------------
    $Blob = $Blob.Replace('-', '+').Replace('_', '/')
    switch ($Blob.Length % 4) {
        2 { $Blob += '==' }
        3 { $Blob += '=' }
    }

    # ------------------------------------------------------------
    # 2. Decode Base64 string → raw bytes
    # ------------------------------------------------------------
    $bytes = [Convert]::FromBase64String($Blob)

    # ------------------------------------------------------------
    # 3. Extract IV + Ciphertext
    # ------------------------------------------------------------
    $IV = $bytes[0..15]
    $CipherBytes = $bytes[16..($bytes.Length - 1)]

    # ------------------------------------------------------------
    # 4. Derive AES-256 CBC Key from reg token
    # ------------------------------------------------------------
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $KeyBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($RegToken))

    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Mode    = "CBC"
    $aes.Padding = "PKCS7"
    $aes.Key     = $KeyBytes
    $aes.IV      = $IV

    # ------------------------------------------------------------
    # 5. AES decrypt
    # ------------------------------------------------------------
    $decryptor = $aes.CreateDecryptor()
    $plainBytes = $decryptor.TransformFinalBlock($CipherBytes, 0, $CipherBytes.Length)

    # ------------------------------------------------------------
    # 6. GZIP decompress
    # ------------------------------------------------------------
   # ------------------------------------------------------------
# 6. GZIP decompress (safe version)
# ------------------------------------------------------------
try {
    $byteArray = [byte[]]$plainBytes   # <--- FORCE array to be treated as a single byte[]

    $inputMs = New-Object System.IO.MemoryStream
    $inputMs.Write($byteArray, 0, $byteArray.Length)
    $inputMs.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null

    $gzip = New-Object System.IO.Compression.GzipStream(
        $inputMs,
        [IO.Compression.CompressionMode]::Decompress
    )

    $outputMs = New-Object System.IO.MemoryStream
    $gzip.CopyTo($outputMs)

    $gzip.Dispose()
    $inputMs.Dispose()

    $plainBytes = $outputMs.ToArray()
}
catch {
    throw "GZIP decompression failed: $($_.Exception.Message)"
}


    # ------------------------------------------------------------
    # 7. Convert UTF8 bytes → string
    # ------------------------------------------------------------
    return [System.Text.Encoding]::UTF8.GetString($plainBytes)
}
