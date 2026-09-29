# PowerShell script to build Seanime backend for Windows
$ErrorActionPreference = "Stop"

Write-Host "Compiling Seanime Go server for Windows..." -ForegroundColor Cyan

$env:GOEXPERIMENT = "nojsonv2"
$backendDir = $PSScriptRoot

Push-Location $backendDir
try {
    go build -tags "http2legacy" -ldflags="-s -w" -o seanime.exe .
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Build failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
    Write-Host "Build succeeded: $backendDir\seanime.exe" -ForegroundColor Green

    # Sync to build output folders if they exist
    $debugRunner = Resolve-Path "$backendDir\..\build\windows\x64\runner\Debug" -ErrorAction SilentlyContinue
    if ($debugRunner) {
        Copy-Item -Path "$backendDir\seanime.exe" -Destination "$debugRunner\seanime.exe" -Force
        Write-Host "Copied to $debugRunner\seanime.exe" -ForegroundColor DarkCyan
    }

    $releaseRunner = Resolve-Path "$backendDir\..\build\windows\x64\runner\Release" -ErrorAction SilentlyContinue
    if ($releaseRunner) {
        Copy-Item -Path "$backendDir\seanime.exe" -Destination "$releaseRunner\seanime.exe" -Force
        Write-Host "Copied to $releaseRunner\seanime.exe" -ForegroundColor DarkCyan
    }
}
finally {
    Pop-Location
}
