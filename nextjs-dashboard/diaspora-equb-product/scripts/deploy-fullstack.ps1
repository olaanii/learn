# Full-stack deploy script (PowerShell)
# Run from repo root: .\scripts\deploy-fullstack.ps1
# Prereqs: Node/npm, Vercel CLI (npm i -g vercel), vercel login, and backend deployed so you have API_BASE_URL.

param(
    [switch]$SkipContracts,
    [switch]$FrontendOnly,
    [string]$ApiBaseUrl = $env:API_BASE_URL
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path "$Root\contracts")) { $Root = $PSScriptRoot }
$ContractsDir = Join-Path $Root "contracts"
$FrontendDir = Join-Path $Root "frontend"

Write-Host "=== Full-stack deploy (e-Equb) ===" -ForegroundColor Cyan
Write-Host "Root: $Root`n"

# 1. Deploy contracts (optional)
if (-not $FrontendOnly -and -not $SkipContracts) {
    Write-Host "--- 1. Deploying contracts (Creditcoin testnet) ---" -ForegroundColor Yellow
    Push-Location $ContractsDir
    try {
        npx hardhat run scripts/deploy.ts --network creditcoinTestnet
        if ($LASTEXITCODE -ne 0) { throw "Contract deploy failed" }
    } finally { Pop-Location }
    Write-Host "Contracts done. Update .env with addresses from contracts\deployments\creditcoinTestnet.json if needed.`n"
} elseif ($SkipContracts) {
    Write-Host "Skipping contract deploy ( -SkipContracts ).`n"
}

# 2. Backend reminder
Write-Host "--- 2. Backend ---" -ForegroundColor Yellow
Write-Host "Deploy the Nest backend (Railway / Render / Fly.io) and set CORS_ORIGINS to your frontend URL."
Write-Host "Then set API_BASE_URL to that backend URL + /api (e.g. https://your-app.railway.app/api).`n"

# 3. Frontend (Vercel)
Write-Host "--- 3. Deploying frontend (Vercel) ---" -ForegroundColor Yellow
# Use npx so no global install needed
$VercelCmd = "npx"
$VercelArgs = "vercel"

Push-Location $FrontendDir
try {
    # Allow passing API_BASE_URL for this run only (Vercel will use project env if not set here)
    if ($ApiBaseUrl) {
        $env:API_BASE_URL = $ApiBaseUrl
    }
    & $VercelCmd $VercelArgs --prod --yes --archive=tgz
    if ($LASTEXITCODE -ne 0) { throw "Vercel deploy failed" }
    Write-Host "`nFrontend deployed. Set API_BASE_URL (and other env) in Vercel project Settings if not already." -ForegroundColor Green
} finally { Pop-Location }

Write-Host "`n=== Done ===" -ForegroundColor Cyan
