param(
    [Parameter(Mandatory)] [string]$AgentId,
    [Parameter(Mandatory)] [string]$TenantId,
    [Parameter(Mandatory)] [string]$Token,
    [Parameter(Mandatory)] [string]$Blob,
    [Parameter(Mandatory)] [string]$GatewayWsUrl
)

# ------------------------------------------------------------
# SETUP ENVIRONMENT
# ------------------------------------------------------------
$ErrorActionPreference = "Stop"
$RootDir = "C:\ProgramData\ObjectX"
$DecryptUrl = "https://raw.githubusercontent.com/Tecknicos-LLC/ObjectOps-Docs/main/Decrypt-InstallerBlob.ps1"
$BootstrapLog = "$RootDir\bootstrap.log"

if (-not (Test-Path $RootDir)) {
    New-Item -Path $RootDir -ItemType Directory | Out-Null
}

"=== ObjectX Bootstrap Installer ===" | Out-File -FilePath $BootstrapLog -Encoding UTF8
"Timestamp: $(Get-Date)" | Out-File -Append $BootstrapLog

try {
    # ------------------------------------------------------------
    # 1. DOWNLOAD DECRYPT FUNCTION
    # ------------------------------------------------------------
    "Downloading decrypt function..." | Out-File -Append $BootstrapLog

    $decryptScript = Invoke-WebRequest -Uri $DecryptUrl -UseBasicParsing
    if (-not $decryptScript.Content) {
        throw "Failed to download decrypt function from GitHub."
    }

    Invoke-Expression $decryptScript.Content

    if (-not (Get-Command Decrypt-InstallerBlob -ErrorAction SilentlyContinue)) {
        throw "Decrypt-InstallerBlob function is missing after download."
    }

    # ------------------------------------------------------------
    # 2. DECRYPT INSTALLER BLOB
    # ------------------------------------------------------------
    "Decrypting installer blob..." | Out-File -Append $BootstrapLog
    $installerRaw = Decrypt-InstallerBlob -Blob $Blob -RegToken $Token

    if (-not $installerRaw) {
        throw "Decryption returned empty payload."
    }

    # ------------------------------------------------------------
    # 3. WRITE INSTALLER TO FILE
    # ------------------------------------------------------------
    $InstallerPath = "$RootDir\service-config.ps1"
    "Writing decrypted installer to $InstallerPath" | Out-File -Append $BootstrapLog

    $installerRaw | Out-File -FilePath $InstallerPath -Encoding UTF8

    if (-not (Test-Path $InstallerPath)) {
        throw "Failed to write service-config.ps1 to disk."
    }

    # ------------------------------------------------------------
    # 4. EXECUTE INSTALLER WITH PARAMS
    # ------------------------------------------------------------
    "Executing service-config.ps1 with agent parameters..." | Out-File -Append $BootstrapLog

    $cmd = "powershell -ExecutionPolicy Bypass -File `"$InstallerPath`" -AgentId `"$AgentId`" -TenantId `"$TenantId`" -RegistrationToken `"$Token`" -GatewayWsUrl `"$GatewayWsUrl`""
    "Running: $cmd" | Out-File -Append $BootstrapLog

    $output = Invoke-Expression $cmd
    $output | Out-File -Append $BootstrapLog

    "Installer executed successfully." | Out-File -Append $BootstrapLog
    Write-Host "ObjectX Agent installed successfully."

}
catch {
    $msg = "ERROR: $($_.Exception.Message)"
    $msg | Out-File -Append $BootstrapLog
    Write-Host $msg -ForegroundColor Red
    exit 1
}
