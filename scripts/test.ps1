$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
Write-Output '[TEST] Checking the training release package'
$expected = ((Get-Content -LiteralPath 'dist/SHA256SUMS' -Raw).Trim() -split '\s+')[0]
$actual = Get-ReleaseHash 'dist/clientflowcrm.tar.gz'
if ($actual -ne $expected) { throw 'Archive checksum mismatch' }
Write-Output '[PASS] Archive SHA256 checksum'
$contents = & "$env:SystemRoot\System32\tar.exe" -tzf dist/clientflowcrm.tar.gz
if ($LASTEXITCODE -ne 0) { throw 'Cannot read release archive' }
foreach ($entry in @('project.env', 'spec/modules.tsv', 'spec/acceptance.md')) {
    if ($contents -notcontains $entry) { throw "Missing file: $entry" }
}
$properties = & "$env:SystemRoot\System32\tar.exe" -xOzf dist/clientflowcrm.tar.gz project.env
if ($LASTEXITCODE -ne 0 -or $properties -notcontains 'PROJECT_NAME=ClientFlowCRM') { throw 'Incorrect project identity' }
$modules = & "$env:SystemRoot\System32\tar.exe" -xOzf dist/clientflowcrm.tar.gz spec/modules.tsv
if ($LASTEXITCODE -ne 0) { throw 'Cannot read module specifications' }
foreach ($module in @('clients','contacts','deals','tasks','reports')) {
    if (-not ($modules | Where-Object { ($_ -split "`t")[0] -eq $module })) { throw "Missing module: $module" }
    Write-Output "[PASS] Module specification included: $module"
}
Write-Output '[TEST] Archive integrity, project identity and all five module specifications passed'
