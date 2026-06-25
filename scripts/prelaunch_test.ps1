# Build and deploy Hello Tuk-Tuk for pre-launch testing.
# Run from project root: .\scripts\prelaunch_test.ps1

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

Write-Host "Building customer/driver web..." -ForegroundColor Cyan
flutter build web --release --no-wasm-dry-run
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Building manager dashboard web..." -ForegroundColor Cyan
flutter build web --release -t lib/main_admin.dart -o build/web_admin --no-wasm-dry-run
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Building Android APK..." -ForegroundColor Cyan
flutter build apk --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Deploying Firebase Hosting..." -ForegroundColor Cyan
firebase deploy --only hosting
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "=== Pre-launch test URLs ===" -ForegroundColor Green
Write-Host "Customer/Driver (iPhone Safari): https://hello-tiktok-57dc5.web.app"
Write-Host "Manager (Chrome):                https://hello-tiktok-57dc5-admin.web.app"
Write-Host ""
Write-Host "Android APK:" -ForegroundColor Green
Write-Host "  build\app\outputs\flutter-apk\app-release.apk"
Write-Host ""
Write-Host "Tip: Use two phones — one customer account, one driver account." -ForegroundColor Yellow
