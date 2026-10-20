@echo off
echo ========================================================
echo       Starting Play Friends Flutter Mobile App
echo ========================================================

cd /d "%~dp0"

echo 1. Checking connected Android devices...
"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" devices

echo 2. Running pub get...
call flutter pub get

echo 3. Launching Flutter application...
call flutter run

pause
