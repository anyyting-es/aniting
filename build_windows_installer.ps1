# PowerShell script to build the Aniting Windows Installer
$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "       Aniting Windows Installer Build    " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$root = $PSScriptRoot

# 1. Check/Build backend seanime.exe
Write-Host "`n[1/4] Checking backend seanime.exe..." -ForegroundColor Yellow
if (-not (Test-Path "$root\backend\seanime.exe")) {
    Write-Host "Compiling Go backend..." -ForegroundColor DarkCyan
    & "$root\backend\build_windows.ps1"
} else {
    Write-Host "Backend already compiled: $root\backend\seanime.exe" -ForegroundColor Green
}

# 2. Build Flutter Windows Release
Write-Host "`n[2/4] Building Flutter Windows Release..." -ForegroundColor Yellow
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter build failed with code $LASTEXITCODE"
    exit $LASTEXITCODE
}

# 3. Copy backend executable to Release output directory
Write-Host "`n[3/4] Bundling backend into Release package..." -ForegroundColor Yellow
$releaseDir = "$root\build\windows\x64\runner\Release"
if (-not (Test-Path "$releaseDir\seanime.exe")) {
    Copy-Item -Path "$root\backend\seanime.exe" -Destination "$releaseDir\seanime.exe" -Force
    Write-Host "Copied seanime.exe to $releaseDir" -ForegroundColor Green
}

# 4. Compile Installer with Inno Setup
Write-Host "`n[4/4] Creating Windows Installer (.exe)..." -ForegroundColor Yellow

# Locate ISCC.exe
$isccPaths = @(
    "C:\Users\$env:USERNAME\AppData\Local\Programs\Inno Setup 6\ISCC.exe",
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe"
)

$iscc = $null
foreach ($path in $isccPaths) {
    if (Test-Path $path) {
        $iscc = $path
        break
    }
}

if (-not $iscc) {
    Write-Error "Inno Setup compiler (ISCC.exe) not found. Please install Inno Setup 6 or run: winget install JRSoftware.InnoSetup"
    exit 1
}

New-Item -ItemType Directory -Force -Path "$root\build\installer" | Out-Null
& "$iscc" "$root\windows\installer\aniting_setup.iss"

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n==========================================" -ForegroundColor Green
    Write-Host "Installer created successfully!" -ForegroundColor Green
    Write-Host "Output: $root\build\installer\Aniting_Setup_1.0.6_x64.exe" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
} else {
    Write-Error "Inno Setup compilation failed with code $LASTEXITCODE"
    exit $LASTEXITCODE
}
