@echo off
setlocal EnableExtensions

set "ROOT=%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%build_frontend.ps1" %*
if errorlevel 1 (
    echo.
    echo [ERROR] sky_phone frontend build failed.
    exit /b 1
)

echo.
echo [DONE] sky_phone frontend built and copied to all configured targets.
exit /b 0
