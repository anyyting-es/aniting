@echo off
setlocal
echo ========================================================
echo   Compilando servidor Seanime para Windows (Go Backend)
echo ========================================================

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0backend\build_windows.ps1"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [OK] Servidor compilado y configurado exitosamente.
) else (
    echo.
    echo [ERROR] Ocurrio un error al compilar el servidor.
)
endlocal
