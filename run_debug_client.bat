@echo off
echo ========================================================
echo   Ejecutando Aniting Client (Sin backend embebido) - Debug
echo ========================================================
flutter run --dart-define=NO_BACKEND=true -PincludeBackend=false %*
