param([string]$RuntimeDirectory=(Join-Path $PSScriptRoot '.runtime'))
$ErrorActionPreference = 'Stop'
$runtimePath = [IO.Path]::GetFullPath($RuntimeDirectory)
foreach ($processLabel in @('jenkins','git-server')) {
    $pidFile = Join-Path $runtimePath ($processLabel + '.pid')
    if (-not (Test-Path -LiteralPath $pidFile)) { continue }
    $savedPid = [int](Get-Content -LiteralPath $pidFile)
    $processInfo = Get-CimInstance Win32_Process -Filter "ProcessId=$savedPid" -ErrorAction SilentlyContinue
    if (-not $processInfo) { continue }
    $expectedMarker = if ($processLabel -eq 'jenkins') { 'jenkins.war' } else { 'Serve-Git.ps1' }
    if ($processInfo.CommandLine -like "*$expectedMarker*" -and $processInfo.CommandLine -like "*$runtimePath*") {
        Stop-Process -Id $savedPid
        Write-Host "Stopped $processLabel"
    } else {
        Write-Warning "Process $savedPid does not match this practice; retained"
    }
}
