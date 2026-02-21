@echo off
REM Build Diaspora Equb Android APK(s) under 30 MB
REM Double-click or run: frontend\build_android_under_30mb.bat
REM Uses a project-local Gradle home to avoid "Address already in use: bind".

cd /d "%~dp0"

REM Use project-local Gradle home so this build does not share ports/locks with
REM Android Studio or other Gradle daemons (fixes BindException).
if not exist "android\.gradle-user-home" mkdir "android\.gradle-user-home"
set GRADLE_USER_HOME=%CD%\android\.gradle-user-home
set GRADLE_OPTS=-Dorg.gradle.daemon=false

REM Stop any Gradle daemons that might be holding the port (fixes "Address already in use: bind").
echo Stopping Gradle daemons...
pushd android
call gradlew.bat --stop 2>nul
popd
echo.

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
