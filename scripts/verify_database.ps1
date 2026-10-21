$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    docker compose config --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Invalid Docker Compose configuration.' }
    $result = docker compose exec -T postgres psql -U retail_admin -d retail_analytics -v ON_ERROR_STOP=1 -Atc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema IN ('raw','control') AND table_type='BASE TABLE';"
    if ($LASTEXITCODE -ne 0) { throw 'Database connection or SQL verification failed.' }
    $count = ($result | Out-String).Trim()
    if ($count -ne '11') { throw "Expected 11 operational/control tables; found: $count" }
    Write-Host 'PASS: PostgreSQL reachable; 11 operational/control tables exist.' -ForegroundColor Green
    Write-Host 'Note: no business data or dbt models have been loaded yet.'
} finally { Pop-Location }
