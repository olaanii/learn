@echo off
REM Repair Android Gradle in place (no new project, no moving code).
REM Double-click or run: frontend\repair_android_gradle.bat

cd /d "%~dp0"

if exist "%USERPROFILE%\.gradle\caches\8.14\kotlin-dsl" (
  echo Removing generated cache: %USERPROFILE%\.gradle\caches\8.14\kotlin-dsl
  rmdir /s /q "%USERPROFILE%\.gradle\caches\8.14\kotlin-dsl"
)
if exist "android\.gradle" rmdir /s /q "android\.gradle"
if exist "android\.kotlin" rmdir /s /q "android\.kotlin"
if exist "build" rmdir /s /q "build"

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
