param([ValidateSet('staging','production')][string]$Target)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
if (-not $Target) { throw 'Specify -Target staging or production' }
$expected = ((Get-Content -LiteralPath 'dist/SHA256SUMS' -Raw).Trim() -split '\s+')[0]
if ((Get-ReleaseHash 'dist/clientflowcrm.tar.gz') -ne $expected) { throw 'Archive checksum mismatch' }
$destination = Join-Path 'environments' $Target
New-Item -ItemType Directory -Force -Path $destination | Out-Null
Copy-Item -LiteralPath 'dist/clientflowcrm.tar.gz','dist/build-info.txt' -Destination $destination -Force
$buildNumber = if ($env:BUILD_NUMBER) { $env:BUILD_NUMBER } else { 'local' }
@('project=ClientFlowCRM', "environment=$Target", "build=$buildNumber", "deployed_utc=$([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))", 'mode=educational_simulation') | Set-Content -LiteralPath (Join-Path $destination 'deployment.txt') -Encoding Ascii
Write-Output "[DEPLOY] Training release copied to $destination"
