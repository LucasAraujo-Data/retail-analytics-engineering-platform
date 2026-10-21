param(
    [ValidateSet('rebuild','incremental','validate')][string]$Mode = 'rebuild',
    [int]$Orders = 15000,
    [int]$Seed = 42
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
python -m pip install -r requirements.txt
if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed.' }
python scripts/load_retail_data.py --mode $Mode --orders $Orders --seed $Seed
if ($LASTEXITCODE -ne 0) { throw 'Data pipeline failed.' }
