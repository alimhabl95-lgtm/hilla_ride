$legalDir = Join-Path $PSScriptRoot "..\build\web\legal"
New-Item -ItemType Directory -Force -Path $legalDir | Out-Null
Copy-Item (Join-Path $PSScriptRoot "..\web\legal\*") $legalDir -Force
Copy-Item (Join-Path $PSScriptRoot "..\web\privacy.html") (Join-Path $PSScriptRoot "..\build\web\privacy.html") -Force
Copy-Item (Join-Path $PSScriptRoot "..\web\terms.html") (Join-Path $PSScriptRoot "..\build\web\terms.html") -Force
Copy-Item (Join-Path $PSScriptRoot "..\web\flutter_service_worker.js") (Join-Path $PSScriptRoot "..\build\web\flutter_service_worker.js") -Force
