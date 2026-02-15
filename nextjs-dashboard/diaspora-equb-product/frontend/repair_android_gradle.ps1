# Repair Android Gradle in place (no new project, no moving code).
# Run from repo root: .\frontend\repair_android_gradle.ps1
# Or from frontend: .\repair_android_gradle.ps1
# See: https://docs.flutter.dev/deployment/android

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

Write-Host "Repairing Android Gradle in place (flutter create .)..." -ForegroundColor Cyan
Write-Host "This updates android/ to the current Flutter template and keeps your Dart code and pubspec." -ForegroundColor Gray
Write-Host ""

flutter create . --project-name diaspora_equb_frontend

if ($LASTEXITCODE -ne 0) {
  Write-Host "Repair failed." -ForegroundColor Red
  exit $LASTEXITCODE
}

Write-Host ""
Write-Host "Done. You can now run: flutter build apk --release --split-per-abi" -ForegroundColor Green
