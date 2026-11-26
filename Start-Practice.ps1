param(
    [string]$RuntimeDirectory = (Join-Path $PSScriptRoot '.runtime'),
    [string]$JenkinsHome = (Join-Path $PSScriptRoot '.jenkins-home'),
    [string]$RepositoryUrl = 'https://github.com/VlTs-dev/ClientFlowCRM-Practice4.git',
    [int]$Port = 8088,
    [int]$GitPort = 9419
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scripts\common.ps1')
$RuntimeDirectory = [IO.Path]::GetFullPath($RuntimeDirectory)
$JenkinsHome = [IO.Path]::GetFullPath($JenkinsHome)
New-Item -ItemType Directory -Force -Path $RuntimeDirectory, $JenkinsHome | Out-Null
$baseUrl = "http://127.0.0.1:$Port/"
try {
    $response = Invoke-WebRequest -Uri ($baseUrl + 'login') -UseBasicParsing -TimeoutSec 3
    if ($response.Headers['X-Jenkins']) {
        Write-Host "Jenkins is already running: $baseUrl"
        return
    }
} catch {}

function Get-CheckedFile([string]$Url, [string]$Destination, [string]$Sha256) {
    if ((Test-Path -LiteralPath $Destination) -and
        ((Get-ReleaseHash $Destination) -eq $Sha256)) { return }
    Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
    if ((Get-ReleaseHash $Destination) -ne $Sha256) {
        throw "SHA256 mismatch: $Destination"
    }
}

$javaExe = Get-ChildItem -LiteralPath (Join-Path $RuntimeDirectory 'java') -Filter java.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if (-not $javaExe) {
    $javaZip = Join-Path $RuntimeDirectory 'java21.zip'
    Get-CheckedFile 'https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.13.1%2B2/OpenJDK21U-jre_x64_windows_hotspot_21.0.13.1_2.zip' $javaZip 'e15ee1e54a5a3b38027a09cedfa87bc3348d7dd3ce50866dd3d9671d7fffc6c1'
    Expand-Archive -LiteralPath $javaZip -DestinationPath (Join-Path $RuntimeDirectory 'java') -Force
    $javaExe = Get-ChildItem -LiteralPath (Join-Path $RuntimeDirectory 'java') -Filter java.exe -Recurse | Select-Object -First 1 -ExpandProperty FullName
}
$war = Join-Path $RuntimeDirectory 'jenkins.war'
Get-CheckedFile 'https://get.jenkins.io/war-stable/2.580.3/jenkins.war' $war '39f69dbd41d78b050183684f81e2eb581bf032ed1c529e5d8fa8884b5fd062e2'
$pluginManager = Join-Path $RuntimeDirectory 'plugin-manager.jar'
Get-CheckedFile 'https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.16.0/jenkins-plugin-manager-2.16.0.jar' $pluginManager 'b3e9704f8259ec3d0479703039e2ad5a0a15abb97808ad70d5a59ba2fdd73197'
$env:CACHE_DIR = Join-Path $RuntimeDirectory 'plugin-cache'
if (-not (Test-Path -LiteralPath (Join-Path $JenkinsHome 'plugins\workflow-job.jpi'))) {
    & $javaExe -jar $pluginManager --war $war --plugin-file (Join-Path $PSScriptRoot 'jenkins\plugins.txt') --plugin-download-directory (Join-Path $JenkinsHome 'plugins')
    if ($LASTEXITCODE -ne 0) { throw 'Jenkins plugin installation failed' }
}

$gitExe = (Get-Command git -ErrorAction Stop).Source
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot '.git'))) {
    & $gitExe -C $PSScriptRoot init -b main
    & $gitExe -C $PSScriptRoot add .
    & $gitExe -C $PSScriptRoot -c 'user.name=ClientFlowCRM Student' -c 'user.email=student@example.invalid' commit -m 'Add ClientFlowCRM educational CI/CD pipeline'
    if ($LASTEXITCODE -ne 0) { throw 'Cannot prepare local Git repository' }
}

if (-not $RepositoryUrl) {
    $gitBase = Join-Path $RuntimeDirectory 'git-server'
    New-Item -ItemType Directory -Force -Path $gitBase | Out-Null
    $bareRepo = Join-Path $gitBase 'ClientFlowCRM.git'
    if (-not (Test-Path -LiteralPath $bareRepo)) {
        New-Item -ItemType Directory -Force -Path $bareRepo | Out-Null
    }
    Copy-Item -Path (Join-Path $PSScriptRoot '.git\*') -Destination $bareRepo -Recurse -Force
    & $gitExe --git-dir=$bareRepo config core.bare true
    & $gitExe --git-dir=$bareRepo update-server-info
    if ($LASTEXITCODE -ne 0) { throw 'Cannot prepare local Git server' }
    $serverScript = Join-Path $PSScriptRoot 'jenkins\Serve-Git.ps1'
    $serverArgs = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $serverScript + '"'), '-Root', ('"' + $gitBase + '"'), '-Port', $GitPort)
    $gitProcess = Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $serverArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $RuntimeDirectory 'git-server.out.log') -RedirectStandardError (Join-Path $RuntimeDirectory 'git-server.err.log')
    $gitProcess.Id | Set-Content -LiteralPath (Join-Path $RuntimeDirectory 'git-server.pid')
    $RepositoryUrl = "http://127.0.0.1:$GitPort/ClientFlowCRM.git"
}

$initDirectory = Join-Path $JenkinsHome 'init.groovy.d'
New-Item -ItemType Directory -Force -Path $initDirectory | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'jenkins\init.groovy') -Destination (Join-Path $initDirectory 'clientflowcrm.groovy') -Force
$accessFile = Join-Path $JenkinsHome 'local-access.json'
$env:CRM_ADMIN_PASSWORD = ''
if (-not (Test-Path -LiteralPath $accessFile)) {
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    $randomBytes = New-Object byte[] 24
    $rng.GetBytes($randomBytes)
    $rng.Dispose()
    $password = [Convert]::ToBase64String($randomBytes)
    @{url=$baseUrl; username='student'; password=$password; repository=$RepositoryUrl} | ConvertTo-Json | Set-Content -LiteralPath $accessFile -Encoding UTF8
    $env:CRM_ADMIN_PASSWORD = $password
}
$env:CRM_JENKINS_URL = $baseUrl
$env:CRM_REPOSITORY_URL = $RepositoryUrl
$env:CRM_GIT_EXE = $gitExe
$env:JENKINS_HOME = $JenkinsHome
$webroot = Join-Path $RuntimeDirectory 'webroot'
$javaArgs = @('-Xmx768m', '-Djava.awt.headless=true', '-Djenkins.install.runSetupWizard=false', '-Dorg.jenkinsci.plugins.gitclient.Git.useCLI=false', ('-Duser.home="' + (Join-Path $RuntimeDirectory 'java-home') + '"'), '-jar', ('"' + $war + '"'), '--httpListenAddress=127.0.0.1', "--httpPort=$Port", ('--webroot="' + $webroot + '"'))
$jenkinsProcess = Start-Process -FilePath $javaExe -ArgumentList $javaArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $RuntimeDirectory 'jenkins.out.log') -RedirectStandardError (Join-Path $RuntimeDirectory 'jenkins.err.log')
$jenkinsProcess.Id | Set-Content -LiteralPath (Join-Path $RuntimeDirectory 'jenkins.pid')
$env:CRM_ADMIN_PASSWORD = ''
Write-Host "Jenkins is starting: $baseUrl"
Write-Host "Local login details: $accessFile"
Write-Host 'Do not upload the runtime or Jenkins home directory to GitHub.'
