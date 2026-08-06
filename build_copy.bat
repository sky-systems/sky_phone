@echo off
setlocal EnableExtensions

set "ROOT=%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%build_copy.ps1" %*
if errorlevel 1 (
    echo.
    echo [ERROR] sky_phone copy failed.
    exit /b 1
)

echo.
echo [DONE] sky_phone copied to all configured targets.
exit /b 0
