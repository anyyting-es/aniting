@echo off
echo ========================================================
echo   Compilando Aniting Client (Sin backend Go) - Release
echo ========================================================

flutter build apk --release --split-per-abi --dart-define=NO_BACKEND=true -PincludeBackend=false %*

echo.
echo [OK] APKs compilados exitosamente en build/app/outputs/flutter-apk/
echo   - ARM64:  app-arm64-v8a-release.apk (~33 MB)
echo   - ARMv7:  app-armeabi-v7a-release.apk (~30 MB)
echo   - x86_64: app-x86_64-release.apk (~35 MB)
pause
