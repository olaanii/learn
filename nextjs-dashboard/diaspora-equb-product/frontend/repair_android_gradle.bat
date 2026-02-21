@echo off
REM Repair Android Gradle in place (no new project, no moving code).
REM Double-click or run: frontend\repair_android_gradle.bat

cd /d "%~dp0"

echo Repairing Android Gradle in place...
echo This updates android/ to the current Flutter template and keeps your code.
echo.

flutter create . --project-name diaspora_equb_frontend

if errorlevel 1 (
  echo Repair failed.
  exit /b 1
)

echo.
echo Done. You can now run: flutter build apk --release --split-per-abi
pause
