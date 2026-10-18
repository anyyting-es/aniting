# Download the published flutter-plezy patched Windows engine (DirectComposition
# + resize-wedge fix) and install it into the active Flutter SDK's artifact cache.
#
# Enables FLUTTER_WINDOWS_DCOMP (set in windows/runner/main.cpp) and presents the Flutter
# UI on a topmost DirectComposition visual, so the mpv video window composites
# *beneath* the UI in a single HWND (controls overlay correctly, window capture works,
# no transparency hacks).
#
# Usage:
#   flutter precache --windows
#   .\windows\tool\install-patched-engine.ps1
#   # Or if on Flutter 3.47.x with a different minor engine revision:
#   .\windows\tool\install-patched-engine.ps1 -SkipStampCheck
param(
    [string]$Url = 'https://github.com/edde746/flutter-plezy/releases/download/windows-v3.47.1%2B1/flutter-plezy-windows-3.47.1.zip',
    [string]$Sha256 = '5f3148f48c4974f32d51c9a883ebfaf332b076451cad8849d21a7251d6ff3321',
    [string]$ExpectedEngine = '5d531788691ec3404cac0cee66ead4007b177363',
    [switch]$SkipStampCheck,
    [switch]$Restore
)

$ErrorActionPreference = 'Stop'

$flutterCmd = Get-Command flutter.bat -ErrorAction SilentlyContinue
if (-not $flutterCmd) { $flutterCmd = Get-Command flutter }
$sdkRoot = Split-Path -Parent (Split-Path -Parent $flutterCmd.Source)

$engineDir = Join-Path $sdkRoot 'bin\cache\artifacts\engine'
if (-not (Test-Path $engineDir)) {
    Write-Error "engine cache not found: $engineDir - run 'flutter precache --windows' first"
}

$backupDir = "$engineDir.stock-backup"

if ($Restore) {
    if (-not (Test-Path $backupDir)) {
        Write-Error "No backup found at $backupDir - run 'flutter precache --windows --force' to restore stock engine"
    }
    Write-Output "Restoring stock engine from $backupDir ..."
    Copy-Item -Path (Join-Path $backupDir '*') -Destination $engineDir -Recurse -Force
    Write-Output "Stock engine successfully restored."
    return
}

$stampPath = Join-Path $sdkRoot 'bin\cache\engine.stamp'
if (-not (Test-Path $stampPath)) {
    Write-Error "engine.stamp not found at $stampPath - run 'flutter precache --windows' first"
}
$stamp = (Get-Content $stampPath -Raw).Trim()
if ($stamp -ne $ExpectedEngine -and -not $SkipStampCheck) {
    Write-Warning "SDK engine.stamp is $stamp but the patched engine targets $ExpectedEngine."
    Write-Warning "If you are on Flutter 3.47.x and want to proceed, run: .\windows\tool\install-patched-engine.ps1 -SkipStampCheck"
    Write-Error "engine.stamp mismatch ($stamp vs $ExpectedEngine)"
}

# Backup stock directories if not already backed up
if (-not (Test-Path $backupDir)) {
    Write-Output "Backing up stock engine to $backupDir ..."
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    Copy-Item -Path (Join-Path $engineDir '*') -Destination $backupDir -Recurse -Force
    Write-Output "Backup complete."
}

$zip = Join-Path ([System.IO.Path]::GetTempPath()) 'flutter-plezy-windows.zip'

$ProgressPreference = 'SilentlyContinue'
Write-Output "Downloading patched engine from $Url ..."
Invoke-WebRequest -Uri $Url -OutFile $zip

$actual = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
if ($actual -ne $Sha256.ToLower()) {
    Remove-Item $zip -Force
    Write-Error "SHA256 mismatch: expected $Sha256 but got $actual"
}

Write-Output "Extracting patched engine into $engineDir ..."
Expand-Archive -Path $zip -DestinationPath $engineDir -Force
Remove-Item $zip -Force

Write-Output "Installed patched DComp engine (windows-x64, windows-x64-release)."
