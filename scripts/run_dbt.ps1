param([ValidateSet('build','debug','docs')][string]$Mode='build')
$ErrorActionPreference='Stop'
$root = Split-Path -Parent $PSScriptRoot
$repo = $root
$envFile=Join-Path $repo '.env'
if (-not (Test-Path $envFile)) { throw 'Missing .env in repository root.' }
Get-Content $envFile | ForEach-Object {
  $line=$_.Trim()
  if ($line -and -not $line.StartsWith('#') -and $line.Contains('=')) {
    $parts=$line.Split('=',2)
    [Environment]::SetEnvironmentVariable($parts[0].Trim(),$parts[1].Trim(),'Process')
  }
}
$env:DBT_HOST='127.0.0.1'
$project=Join-Path $root 'dbt'
if ($Mode -eq 'debug') { dbt debug --project-dir $project --profiles-dir $project }
elseif ($Mode -eq 'docs') { dbt docs generate --project-dir $project --profiles-dir $project }
else { dbt build --project-dir $project --profiles-dir $project }
if ($LASTEXITCODE -ne 0) { throw "dbt $Mode failed." }
