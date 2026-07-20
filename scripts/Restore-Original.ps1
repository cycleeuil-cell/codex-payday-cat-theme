[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Runtime = Join-Path $Root 'runtime'
$BackupDir = Join-Path $Root 'backup'
$StatePath = Join-Path $Root 'install-state.json'

$runningTheme = Get-Process -Name ChatGPT, Codex -ErrorAction SilentlyContinue | Where-Object {
    try {
        $_.Path -and $_.Path.StartsWith($Runtime, [System.StringComparison]::OrdinalIgnoreCase)
    } catch {
        $false
    }
}
if ($runningTheme) {
    throw 'The themed Codex is running. Fully exit it before restoring.'
}
if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) {
    throw "Missing install state: $StatePath"
}

$state = Get-Content -Raw -LiteralPath $StatePath | ConvertFrom-Json
$backup = [System.IO.Path]::GetFullPath([string]$state.originalAsarBackup)
$backupRoot = [System.IO.Path]::GetFullPath($BackupDir).TrimEnd('\') + '\'
if (-not $backup.StartsWith($backupRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "The backup path is outside the managed backup folder: $backup"
}
if (-not (Test-Path -LiteralPath $backup -PathType Leaf)) {
    throw "Missing original backup: $backup"
}

$target = Join-Path $Runtime 'resources\app.asar'
Copy-Item -Force -LiteralPath $backup -Destination $target
Write-Host 'The isolated runtime now uses the original Codex interface. The Microsoft Store installation was never modified.' -ForegroundColor Green

