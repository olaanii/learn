@echo off
REM Build Diaspora Equb Android APK(s) under 30 MB
REM Double-click or run: frontend\build_android_under_30mb.bat

cd /d "%~dp0"

echo Building Android APK(s) optimized for size (under 30 MB per ABI)...
echo.

flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols

if errorlevel 1 (
  echo Build failed.
  exit /b 1
)

echo.
echo APK(s) written to: build\app\outputs\flutter-apk
dir /b build\app\outputs\flutter-apk\*.apk 2>nul
echo.
echo Done. Install the APK that matches your device (arm64-v8a for most phones).
pause
