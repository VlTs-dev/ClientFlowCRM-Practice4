$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
Write-Output '[BUILD] Preparing the ClientFlowCRM training release'
New-Item -ItemType Directory -Force -Path 'dist' | Out-Null
& "$env:SystemRoot\System32\tar.exe" -czf dist/clientflowcrm.tar.gz project.env spec
if ($LASTEXITCODE -ne 0) { throw 'Cannot create release archive' }
$digest = Get-ReleaseHash 'dist/clientflowcrm.tar.gz'
"$digest  dist/clientflowcrm.tar.gz" | Set-Content -LiteralPath 'dist/SHA256SUMS' -Encoding Ascii
$buildNumber = if ($env:BUILD_NUMBER) { $env:BUILD_NUMBER } else { 'local' }
$commit = if ($env:GIT_COMMIT) { $env:GIT_COMMIT } else { 'local' }
@("project=ClientFlowCRM", "build=$buildNumber", "commit=$commit", "created_utc=$([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))", 'mode=educational_simulation') | Set-Content -LiteralPath 'dist/build-info.txt' -Encoding Ascii
if ($env:CRM_DEMO_TOKEN) { Write-Output '[BUILD] Demo credential was supplied by Jenkins Credentials (value hidden)' }
Write-Output '[BUILD] Release archive and checksum created'
