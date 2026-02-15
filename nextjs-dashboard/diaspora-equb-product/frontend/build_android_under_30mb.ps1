# Build Diaspora Equb Android APK(s) under 30 MB
# Run from repo root: .\frontend\build_android_under_30mb.ps1
# Or from frontend: .\build_android_under_30mb.ps1

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

Write-Host "Building Android APK(s) optimized for size (< 30 MB per ABI)..." -ForegroundColor Cyan
Write-Host ""

# --split-per-abi: one APK per architecture (each stays under ~30 MB)
# --obfuscate: strip symbols and shrink Dart code
# --split-debug-info: save symbols for crash reports (optional, saves to build/symbols)
flutter build apk --release `
  --split-per-abi `
  --obfuscate `
  --split-debug-info=build/symbols

if ($LASTEXITCODE -ne 0) {
  Write-Host "Build failed." -ForegroundColor Red
  exit $LASTEXITCODE
}

$outDir = "build\app\outputs\flutter-apk"
if (Test-Path $outDir) {
  Write-Host ""
  Write-Host "APK(s) written to: $scriptDir\$outDir" -ForegroundColor Green
  Get-ChildItem $outDir -Filter "*.apk" | ForEach-Object {
    $sizeMB = [math]::Round($_.Length / 1MB, 2)
    Write-Host "  $($_.Name)  $sizeMB MB"
  }
} else {
  Write-Host "Output folder not found: $outDir" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Done. Install the APK that matches your device (arm64-v8a for most phones)." -ForegroundColor Cyan
