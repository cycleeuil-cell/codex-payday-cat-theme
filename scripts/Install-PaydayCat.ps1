[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'CodexPaydayCat')
)

$ErrorActionPreference = 'Stop'
$SourceRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$SourceTheme = Join-Path $SourceRoot 'theme'
$SourceScripts = Join-Path $SourceRoot 'scripts'
$TargetTheme = Join-Path $InstallRoot 'theme'
$TargetScripts = @(
    'Install-PaydayCat.ps1',
    'Update-PaydayCat.ps1',
    'Launch-PaydayCat.ps1',
    'Restore-Original.ps1'
)

if (-not $env:LOCALAPPDATA) {
    throw 'LOCALAPPDATA is not available for this Windows user.'
}

foreach ($required in @(
    (Join-Path $SourceTheme 'payday-theme.css'),
    (Join-Path $SourceTheme 'payday-hero.png'),
    (Join-Path $SourceTheme 'payday-pet.png'),
    (Join-Path $SourceTheme 'payday-pet.js')
)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Missing repository asset: $required"
    }
}

foreach ($scriptName in $TargetScripts) {
    $required = Join-Path $SourceScripts $scriptName
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Missing repository script: $required"
    }
}

New-Item -ItemType Directory -Force -Path $InstallRoot, $TargetTheme | Out-Null

foreach ($assetName in @('payday-theme.css', 'payday-hero.png', 'payday-pet.png', 'payday-pet.js')) {
    Copy-Item -Force -LiteralPath (Join-Path $SourceTheme $assetName) -Destination (Join-Path $TargetTheme $assetName)
}

foreach ($scriptName in $TargetScripts) {
    Copy-Item -Force -LiteralPath (Join-Path $SourceScripts $scriptName) -Destination (Join-Path $InstallRoot $scriptName)
}

& (Join-Path $InstallRoot 'Update-PaydayCat.ps1')

$Launcher = Join-Path $InstallRoot 'Launch-PaydayCat.ps1'
$PowerShell = (Get-Command powershell.exe -ErrorAction Stop).Source
$Runtime = Join-Path $InstallRoot 'runtime'
$Icon = @(
    (Join-Path $Runtime 'ChatGPT.exe'),
    (Join-Path $Runtime 'Codex.exe')
) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1

$Shell = New-Object -ComObject WScript.Shell
$StartMenu = Join-Path ([Environment]::GetFolderPath('Programs')) 'Codex Payday Cat'
$Desktop = [Environment]::GetFolderPath('Desktop')
New-Item -ItemType Directory -Force -Path $StartMenu | Out-Null

foreach ($shortcutPath in @(
    (Join-Path $Desktop 'Codex Payday Cat.lnk'),
    (Join-Path $StartMenu 'Codex Payday Cat.lnk')
)) {
    $shortcut = $Shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $PowerShell
    $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Launcher`""
    $shortcut.WorkingDirectory = $InstallRoot
    if ($Icon) {
        $shortcut.IconLocation = "$Icon,0"
    }
    $shortcut.Description = 'Codex Payday Cat dynamic status theme'
    $shortcut.Save()
}

Write-Host ''
Write-Host 'Codex Payday Cat was installed successfully.' -ForegroundColor Green
Write-Host "Install location: $InstallRoot"
Write-Host 'Fully exit the currently running Codex, then open the new Codex Payday Cat shortcut.' -ForegroundColor Yellow

