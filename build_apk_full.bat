@echo off
echo ========================================================
echo   Compilando Aniting Completo (Con backend Go) - Release
echo ========================================================

flutter build apk --release --split-per-abi -PincludeBackend=true %*

echo.
echo [OK] APKs completos con servidor Go compilados en build/app/outputs/flutter-apk/
echo   - ARM64:  app-arm64-v8a-release.apk
echo   - ARMv7:  app-armeabi-v7a-release.apk
echo   - x86_64: app-x86_64-release.apk
pause
