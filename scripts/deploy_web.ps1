# Deploy Hello tiktok web apps for iPhone Safari testing (run from project root).
# Uses .cmd launchers so PowerShell script policy does not block npm/firebase.

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

Write-Host "Building customer/driver app..." -ForegroundColor Cyan
flutter build web --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Building admin app..." -ForegroundColor Cyan
flutter build web --release -t lib/main_admin.dart -o build/web_admin
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Deploying to Firebase Hosting..." -ForegroundColor Cyan
firebase.cmd deploy --only hosting
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Done. Open on iPhone Safari:" -ForegroundColor Green
Write-Host "  Customer/Driver: https://hello-tiktok-57dc5.web.app"
Write-Host "  Admin:           https://hello-tiktok-57dc5-admin.web.app"
Write-Host ""
Write-Host "If admin URL fails, create hosting site 'hello-tiktok-57dc5-admin' in Firebase Console first."
