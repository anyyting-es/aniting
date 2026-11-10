# PowerShell script to build Aniting backend for Windows
$ErrorActionPreference = "Stop"

Write-Host "Compiling Aniting Go server for Windows..." -ForegroundColor Cyan

$env:GOEXPERIMENT = "nojsonv2"
$backendDir = $PSScriptRoot

Push-Location $backendDir
try {
    go build -tags "http2legacy" -ldflags="-s -w" -o aniting.exe .
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Build failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
    Write-Host "Build succeeded: $backendDir\aniting.exe" -ForegroundColor Green

    # Sync to build output folders if they exist
    $debugRunner = Resolve-Path "$backendDir\..\build\windows\x64\runner\Debug" -ErrorAction SilentlyContinue
    if ($debugRunner) {
        Copy-Item -Path "$backendDir\aniting.exe" -Destination "$debugRunner\aniting.exe" -Force
        Write-Host "Copied to $debugRunner\aniting.exe" -ForegroundColor DarkCyan
    }

    $releaseRunner = Resolve-Path "$backendDir\..\build\windows\x64\runner\Release" -ErrorAction SilentlyContinue
    if ($releaseRunner) {
        Copy-Item -Path "$backendDir\aniting.exe" -Destination "$releaseRunner\aniting.exe" -Force
        Write-Host "Copied to $releaseRunner\aniting.exe" -ForegroundColor DarkCyan
    }
}
finally {
    Pop-Location
}
