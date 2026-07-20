[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Runtime = Join-Path $Root 'runtime'
$StatePath = Join-Path $Root 'install-state.json'
$UpdateScript = Join-Path $Root 'Update-PaydayCat.ps1'
$Profile = Join-Path $env:APPDATA 'Codex\web\Codex'

function Show-Notice {
    param([string]$Text, [string]$Title = 'Codex Payday Cat')

    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show(
        $Text,
        $Title,
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Information
    ) | Out-Null
}

try {
    $runningCodex = Get-Process -Name ChatGPT, Codex -ErrorAction SilentlyContinue
    $foreignCodex = $runningCodex | Where-Object {
        try {
            $_.Path -and -not $_.Path.StartsWith($Runtime, [System.StringComparison]::OrdinalIgnoreCase)
        } catch {
            $false
        }
    }
    if ($foreignCodex) {
        Show-Notice 'The original Codex is still running. Fully exit Codex from the system tray, then open Codex Payday Cat again. Your chats and account are not changed.'
        exit 2
    }

    $installed = Get-AppxPackage -Name 'OpenAI.Codex' -ErrorAction Stop |
        Sort-Object Version -Descending |
        Select-Object -First 1
    $needsUpdate = -not (Test-Path -LiteralPath $StatePath -PathType Leaf)
    if (-not $needsUpdate) {
        try {
            $state = Get-Content -Raw -LiteralPath $StatePath | ConvertFrom-Json
            $needsUpdate = -not $installed -or ([string]$installed.Version -ne [string]$state.sourceVersion)
        } catch {
            $needsUpdate = $true
        }
    }

    if ($needsUpdate) {
        if (-not (Test-Path -LiteralPath $UpdateScript -PathType Leaf)) {
            throw "The updater is missing: $UpdateScript"
        }
        & $UpdateScript
    }

    $Exe = @(
        (Join-Path $Runtime 'ChatGPT.exe'),
        (Join-Path $Runtime 'Codex.exe')
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (-not $Exe) {
        throw 'The isolated Codex runtime is missing. Run Install-PaydayCat.ps1 again.'
    }

    $env:CODEX_ELECTRON_USER_DATA_PATH = $Profile
    Start-Process -FilePath $Exe -ArgumentList @(
        "--user-data-dir=$Profile",
        '--no-first-run'
    ) -WorkingDirectory $Runtime
} catch {
    Show-Notice $_.Exception.Message
    exit 1
}

