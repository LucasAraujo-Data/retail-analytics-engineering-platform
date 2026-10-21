$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    if (-not (Test-Path '.env')) { throw 'Missing .env. Copy .env.example to .env and set POSTGRES_PASSWORD.' }
    docker compose up -d --wait
    if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL startup failed.' }
    Write-Host 'PostgreSQL is running. Next: .\scripts\verify_database.ps1' -ForegroundColor Green
} finally { Pop-Location }
