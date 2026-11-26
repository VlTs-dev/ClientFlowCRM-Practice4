param([ValidateSet('staging','production')][string]$Target='staging')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$destination = Join-Path 'environments' $Target
foreach ($file in @('clientflowcrm.tar.gz','build-info.txt','deployment.txt')) {
    if (-not (Test-Path -LiteralPath (Join-Path $destination $file))) { throw "Missing deployment file: $file" }
}
$marker = Get-Content -LiteralPath (Join-Path $destination 'deployment.txt')
if ($marker -notcontains "environment=$Target") { throw 'Incorrect environment marker' }
foreach ($file in @('clientflowcrm.tar.gz','build-info.txt')) {
    $sourceHash = Get-ReleaseHash (Join-Path 'dist' $file)
    $deployedHash = Get-ReleaseHash (Join-Path $destination $file)
    if ($sourceHash -ne $deployedHash) { throw "Deployed file differs: $file" }
}
& "$env:SystemRoot\System32\tar.exe" -tzf (Join-Path $destination 'clientflowcrm.tar.gz') | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Invalid deployed archive' }
Write-Output "[SMOKE PASS] ${Target}: package exists, environment marker and release contents are correct"
