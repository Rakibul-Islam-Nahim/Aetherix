# Aetherix — local dev scaffold
# Use on Windows when working inside the repo before pushing.
# Creates .env from .env.example, installs python venv, runs uvicorn briefly.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path .env)) {
    Copy-Item .env.example .env
    Write-Host ".env created from .env.example" -ForegroundColor Green
} else {
    Write-Host ".env already exists, leaving it alone" -ForegroundColor Yellow
}

# Backend venv
if (-not (Test-Path backend\.venv)) {
    Write-Host "Creating backend virtualenv..." -ForegroundColor Cyan
    Push-Location backend
    py -3 -m venv .venv
    & .\.venv\Scripts\python.exe -m pip install --upgrade pip
    & .\.venv\Scripts\pip.exe install -r requirements.txt
    Pop-Location
}

Write-Host ""
Write-Host "Run the backend with:" -ForegroundColor Cyan
Write-Host "  cd backend && .\.venv\Scripts\Activate.ps1 && uvicorn app.main:app --reload --port 8000"
Write-Host ""
Write-Host "Run Flutter (after fvm install stable && fvm global stable):" -ForegroundColor Cyan
Write-Host "  cd flutter\Aetherix_app && fvm flutter pub get && fvm flutter run"