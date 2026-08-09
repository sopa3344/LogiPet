$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$appSource = Join-Path $projectRoot 'dist\LogiPet'
$pluginSource = Join-Path $projectRoot 'LogiPetPlugin\bin\Release'
$appTarget = Join-Path $env:LOCALAPPDATA 'LogiPet'
$pluginLink = Join-Path $env:LOCALAPPDATA 'Logi\LogiPluginService\Plugins\LogiPetPlugin.link'

if (-not (Test-Path -LiteralPath (Join-Path $appSource 'LogiPet.exe'))) {
    throw '먼저 dotnet publish로 dist\LogiPet 배포본을 만들어 주세요.'
}

New-Item -ItemType Directory -Force -Path $appTarget | Out-Null
Get-ChildItem -LiteralPath $appSource -Force | Copy-Item -Destination $appTarget -Recurse -Force

$pluginPath = (Resolve-Path -LiteralPath $pluginSource).Path + '\'
[System.IO.File]::WriteAllText(
    $pluginLink,
    $pluginPath,
    (New-Object System.Text.UTF8Encoding($false)))

Start-Process 'loupedeck:plugin/LogiPet/reload'
Start-Process -FilePath (Join-Path $appTarget 'LogiPet.exe')

Write-Host 'LogiPet 앱 배치와 개발 플러그인 연결이 완료됐습니다.' -ForegroundColor Green
