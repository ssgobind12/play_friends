@echo off
echo ========================================================
echo       Starting Play Friends Flutter Mobile App
echo ========================================================

cd /d "%~dp0"

:: Auto-clean stale Gradle locks if any exist
if exist "%USERPROFILE%\.gradle\caches\journal-1\journal-1.lock" (
    echo [Info] Cleaning stale Gradle lock...
    del /f /q "%USERPROFILE%\.gradle\caches\journal-1\journal-1.lock" >nul 2>&1
)

echo 1. Checking connected Android devices...
"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" devices

echo 2. Running pub get...
call flutter pub get

echo 3. Launching Flutter application...
call flutter run

pause
