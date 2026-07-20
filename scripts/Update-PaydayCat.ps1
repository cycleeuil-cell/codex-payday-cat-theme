[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Runtime = Join-Path $Root 'runtime'
$BackupDir = Join-Path $Root 'backup'
$ThemeDir = Join-Path $Root 'theme'
$CacheDir = Join-Path $Root 'cache'
$Staging = Join-Path $Root 'staging'
$NewAsar = Join-Path $Root 'app.asar.payday-new'
$StatePath = Join-Path $Root 'install-state.json'

function Assert-ManagedPath {
    param([Parameter(Mandatory)][string]$Path)

    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    $pathFull = [System.IO.Path]::GetFullPath($Path)
    if (-not $pathFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to operate outside the Payday Cat install root: $pathFull"
    }
}

function Remove-ManagedTree {
    param([Parameter(Mandatory)][string]$Path)

    Assert-ManagedPath $Path
    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $full = [System.IO.Path]::GetFullPath($Path)
    $extended = if ($full.StartsWith('\\')) {
        '\\?\UNC\' + $full.Substring(2)
    } else {
        '\\?\' + $full
    }
    [System.IO.Directory]::Delete($extended, $true)
}

function Invoke-Asar {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $npx = Get-Command npx.cmd -ErrorAction SilentlyContinue
    if ($npx) {
        & $npx.Source --yes '@electron/asar' @Arguments
    } else {
        $pnpm = Get-Command pnpm.cmd -ErrorAction SilentlyContinue
        if (-not $pnpm) {
            throw 'Node.js tooling was not found. Install Node.js (which provides npx.cmd), then run this updater again.'
        }
        & $pnpm.Source dlx '@electron/asar' @Arguments
    }

    if ($LASTEXITCODE -ne 0) {
        throw "The ASAR tool failed with exit code $LASTEXITCODE."
    }
}

foreach ($managedPath in @($Runtime, $BackupDir, $CacheDir, $Staging, $NewAsar, $StatePath)) {
    Assert-ManagedPath $managedPath
}

$runningTheme = Get-Process -Name ChatGPT, Codex -ErrorAction SilentlyContinue | Where-Object {
    try {
        $_.Path -and $_.Path.StartsWith($Runtime, [System.StringComparison]::OrdinalIgnoreCase)
    } catch {
        $false
    }
}
if ($runningTheme) {
    throw 'The themed Codex is running. Fully exit it before updating.'
}

$package = Get-AppxPackage -Name 'OpenAI.Codex' -ErrorAction Stop |
    Sort-Object Version -Descending |
    Select-Object -First 1
if (-not $package) {
    throw 'The Microsoft Store OpenAI Codex package was not found. This installer currently supports only the Windows Store desktop app.'
}

$sourceCandidates = @(
    (Join-Path $package.InstallLocation 'app'),
    $package.InstallLocation
)
$SourceApp = $sourceCandidates | Where-Object {
    Test-Path -LiteralPath (Join-Path $_ 'resources\app.asar') -PathType Leaf
} | Select-Object -First 1
if (-not $SourceApp) {
    throw 'The installed Codex package layout is not supported: resources\app.asar was not found.'
}

$Version = [string]$package.Version
$SourceAsar = Join-Path $SourceApp 'resources\app.asar'
$BackupAsar = Join-Path $BackupDir "app.asar.$Version.original"
$ThemeCss = Join-Path $ThemeDir 'payday-theme.css'
$ThemeHeroImage = Join-Path $ThemeDir 'payday-hero.png'
$ThemePetImage = Join-Path $ThemeDir 'payday-pet.png'
$ThemePetScript = Join-Path $ThemeDir 'payday-pet.js'

foreach ($required in @($SourceAsar, $ThemeCss, $ThemeHeroImage, $ThemePetImage, $ThemePetScript)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Missing required file: $required"
    }
}

New-Item -ItemType Directory -Force -Path $Runtime, $BackupDir, $CacheDir | Out-Null
if (-not (Test-Path -LiteralPath $BackupAsar -PathType Leaf)) {
    Copy-Item -LiteralPath $SourceAsar -Destination $BackupAsar
}

Write-Host "Copying Codex $Version into the isolated Payday Cat runtime..." -ForegroundColor Cyan
& robocopy.exe $SourceApp $Runtime /MIR /COPY:DAT /R:1 /W:1 /NFL /NDL /NJH /NJS /NP
$robocopyCode = $LASTEXITCODE
if ($robocopyCode -gt 7) {
    throw "Robocopy failed with exit code $robocopyCode."
}

if (Test-Path -LiteralPath $Staging) {
    Remove-ManagedTree $Staging
}
if (Test-Path -LiteralPath $NewAsar) {
    Remove-Item -Force -LiteralPath $NewAsar
}

try {
    $env:NPM_CONFIG_CACHE = $CacheDir
    Write-Host 'Extracting Codex interface resources...' -ForegroundColor Cyan
    Invoke-Asar @('extract', $SourceAsar, $Staging)

    $IndexHtml = Join-Path $Staging 'webview\index.html'
    $AssetDir = Join-Path $Staging 'webview\assets'
    if (-not (Test-Path -LiteralPath $IndexHtml -PathType Leaf)) {
        throw 'The Codex WebView entry point changed. No patch was installed.'
    }
    if (-not (Test-Path -LiteralPath $AssetDir -PathType Container)) {
        throw 'The Codex WebView assets directory changed. No patch was installed.'
    }

    $html = [System.IO.File]::ReadAllText($IndexHtml)
    $marker = '    <script type="module"'
    $styleTag = '    <link rel="stylesheet" href="./assets/payday-theme.css">'
    $petTag = '    <script defer src="./assets/payday-pet.js"></script>'

    foreach ($injection in @(
        @{ Match = 'payday-theme.css'; Tag = $styleTag },
        @{ Match = 'payday-pet.js'; Tag = $petTag }
    )) {
        if (-not $html.Contains($injection.Match)) {
            $position = $html.IndexOf($marker, [System.StringComparison]::Ordinal)
            if ($position -lt 0) {
                throw 'The Codex WebView script marker changed. No patch was installed.'
            }
            $html = $html.Insert($position, "$($injection.Tag)`r`n")
        }
    }
    [System.IO.File]::WriteAllText($IndexHtml, $html, [System.Text.UTF8Encoding]::new($false))

    Copy-Item -Force -LiteralPath $ThemeCss -Destination (Join-Path $AssetDir 'payday-theme.css')
    Copy-Item -Force -LiteralPath $ThemeHeroImage -Destination (Join-Path $AssetDir 'payday-hero.png')
    Copy-Item -Force -LiteralPath $ThemePetImage -Destination (Join-Path $AssetDir 'payday-pet.png')
    Copy-Item -Force -LiteralPath $ThemePetScript -Destination (Join-Path $AssetDir 'payday-pet.js')

    Write-Host 'Packing the themed interface...' -ForegroundColor Cyan
    Invoke-Asar @('pack', $Staging, $NewAsar)
    if (-not (Test-Path -LiteralPath $NewAsar -PathType Leaf)) {
        throw 'The themed app.asar was not produced.'
    }

    $RuntimeAsar = Join-Path $Runtime 'resources\app.asar'
    Move-Item -Force -LiteralPath $NewAsar -Destination $RuntimeAsar

    $state = [ordered]@{
        theme = 'Payday Cat - Open for Business'
        sourceVersion = $Version
        sourcePackage = [string]$package.PackageFullName
        originalAsarBackup = $BackupAsar
        sourceAsarSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $SourceAsar).Hash
        themedAsarSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $RuntimeAsar).Hash
        themeCssSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $ThemeCss).Hash
        heroImageSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $ThemeHeroImage).Hash
        petImageSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $ThemePetImage).Hash
        petScriptSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $ThemePetScript).Hash
        installedAt = (Get-Date).ToString('o')
    }
    $state | ConvertTo-Json | Set-Content -LiteralPath $StatePath -Encoding UTF8
    Write-Host "Codex Payday Cat is ready for Codex $Version." -ForegroundColor Green
} finally {
    if (Test-Path -LiteralPath $Staging) {
        Remove-ManagedTree $Staging
    }
    if (Test-Path -LiteralPath $NewAsar) {
        Assert-ManagedPath $NewAsar
        Remove-Item -Force -LiteralPath $NewAsar
    }
}

