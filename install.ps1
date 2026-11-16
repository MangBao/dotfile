<#
.SYNOPSIS
  Set up a Windows machine for Claude Code: apps, Python via uv, graphify,
  Claude Code config, plugins and PowerShell profile. Safe to re-run.
.PARAMETER SkipApps     Skip winget installs.
.PARAMETER SkipPlugins  Skip Claude Code marketplace/plugin installs.
.PARAMETER SkipProfile  Do not touch the PowerShell profile.
#>
param([switch]$SkipApps, [switch]$SkipPlugins, [switch]$SkipProfile)
$ErrorActionPreference = 'Stop'

$Repo      = $PSScriptRoot
$SrcClaude = Join-Path $Repo 'claude'
$SrcPs     = Join-Path $Repo 'powershell'
$ClaudeDir = Join-Path $HOME '.claude'
$GitBin    = 'C:\Program Files\Git\bin'
$Utf8      = New-Object System.Text.UTF8Encoding($false)
$Stamp     = Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupDir = Join-Path $ClaudeDir "backup-$Stamp"
$Manual    = New-Object System.Collections.Generic.List[string]

function Step([string]$Msg) { Write-Host "`n== $Msg" -ForegroundColor Cyan }
function Has([string]$Cmd) { [bool](Get-Command $Cmd -ErrorAction SilentlyContinue) }
function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}
function Convert-FromTokens([string]$Text) {
    return $Text.Replace('{{HOME_JSON}}', $HOME.Replace('\', '\\')).Replace('{{HOME_FWD}}', $HOME.Replace('\', '/')).Replace('{{HOME}}', $HOME)
}
function Backup-File([string]$Path) {
    if (Test-Path $Path) {
        New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
        Copy-Item $Path (Join-Path $BackupDir (Split-Path $Path -Leaf)) -Force
    }
}
function Install-Config([string]$Src, [string]$Dst) {
    New-Item -ItemType Directory -Force -Path (Split-Path $Dst -Parent) | Out-Null
    $text = Convert-FromTokens ([IO.File]::ReadAllText($Src))
    if ((Test-Path $Dst) -and ([IO.File]::ReadAllText($Dst) -eq $text)) {
        Write-Host "  unchanged $Dst"; return
    }
    Backup-File $Dst
    # Windows PowerShell 5.1 needs a BOM to read non-ASCII .ps1 files correctly
    $enc = if ($Dst -like '*.ps1') { New-Object System.Text.UTF8Encoding($true) } else { $Utf8 }
    [IO.File]::WriteAllText($Dst, $text, $enc)
    Write-Host "  wrote $Dst"
}
function Install-WingetPackage([string]$Id, [string[]]$Extra = @()) {
    winget list --id $Id -e --accept-source-agreements *> $null
    if ($LASTEXITCODE -eq 0) { Write-Host "  $Id already installed"; return }
    Write-Host "  installing $Id"
    winget install --id $Id -e --silent --accept-package-agreements --accept-source-agreements @Extra
    if ($LASTEXITCODE -ne 0) { $Manual.Add("winget install failed for $Id (exit $LASTEXITCODE)") }
}

# ---------------------------------------------------------------- apps
if (-not $SkipApps) {
    Step 'Apps (winget)'
    if (-not (Has 'winget')) { throw 'winget not found. Install "App Installer" from the Microsoft Store first.' }

    # Git must be a machine-wide install so that Git\bin\bash.exe and sh.exe exist
    if (Test-Path "$GitBin\bash.exe") { Write-Host '  Git Bash already present' }
    else { Install-WingetPackage 'Git.Git' @('--scope', 'machine') }

    Install-WingetPackage 'astral-sh.uv'
    Install-WingetPackage 'OpenJS.NodeJS.LTS'
    Install-WingetPackage 'JanDeDobbeleer.OhMyPosh'
    Update-SessionPath
}

# ---------------------------------------------------------------- PATH
Step 'PATH'
if (-not (Test-Path "$GitBin\bash.exe")) {
    $Manual.Add("Git Bash not found at $GitBin\bash.exe. Reinstall Git (machine scope, Git Bash component).")
} else {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (($userPath -split ';') -notcontains $GitBin) {
        [Environment]::SetEnvironmentVariable('Path', ($userPath.TrimEnd(';') + ';' + $GitBin), 'User')
        Write-Host "  added $GitBin to user PATH"
    } else { Write-Host "  $GitBin already on user PATH" }
}
Update-SessionPath

# ---------------------------------------------------------------- Python + graphify
Step 'Python 3.12 + graphify (uv)'
if (-not (Has 'uv')) {
    $Manual.Add('uv not found; open a new terminal and re-run install.ps1')
} else {
    uv python install 3.12
    uv python update-shell
    Update-SessionPath
    $tools = (uv tool list 2>$null) -join "`n"
    if ($tools -match '(?m)^graphifyy ') { Write-Host '  graphifyy already installed' }
    else { uv tool install --python 3.12 'graphifyy[mcp,pdf,sql]' }
}

# ---------------------------------------------------------------- Claude Code
Step 'Claude Code'
if (Has 'claude') { Write-Host '  claude already installed' }
else {
    Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
    Update-SessionPath
    $localBin = Join-Path $HOME '.local\bin'
    if ((Test-Path $localBin) -and (($env:Path -split ';') -notcontains $localBin)) { $env:Path += ";$localBin" }
}

Step 'Claude Code config'
$settingsSrc = Join-Path $SrcClaude 'settings.json'
$settingsDst = Join-Path $ClaudeDir 'settings.json'
if (Test-Path $settingsSrc) {
    Install-Config $settingsSrc $settingsDst
} elseif (-not (Test-Path $settingsDst)) {
    Install-Config (Join-Path $SrcClaude 'settings.base.json') $settingsDst
} else {
    Write-Host '  no exported settings.json in repo; existing settings left untouched'
}
Install-Config (Join-Path $SrcClaude 'CLAUDE.md') (Join-Path $ClaudeDir 'CLAUDE.md')
$hooksSrc = Join-Path $SrcClaude 'hooks'
if (Test-Path $hooksSrc) {
    Get-ChildItem $hooksSrc -File | ForEach-Object {
        Install-Config $_.FullName (Join-Path $ClaudeDir "hooks\$($_.Name)")
    }
}

# ---------------------------------------------------------------- plugins
if (-not $SkipPlugins) {
    Step 'Claude Code plugins'
    if (-not (Has 'claude')) {
        $Manual.Add('claude CLI not on PATH; open a new terminal and re-run with -SkipApps')
    } else {
        $marketsFile = Join-Path $SrcClaude 'plugins\known_marketplaces.json'
        if (Test-Path $marketsFile) {
            $markets = (Convert-FromTokens ([IO.File]::ReadAllText($marketsFile))) | ConvertFrom-Json
            foreach ($p in $markets.PSObject.Properties) {
                $src = $p.Value.source
                $target = $null
                if ($src.source -eq 'github') { $target = $src.repo }
                elseif ($src.source -in @('git', 'url')) { $target = $src.url }
                if (-not $target) { Write-Host "  skip marketplace $($p.Name) (source: $($src.source))"; continue }
                Write-Host "  marketplace $($p.Name) <- $target"
                claude plugin marketplace add $target 2>&1 | Out-Host
                if ($LASTEXITCODE -ne 0) { $Manual.Add("/plugin marketplace add $target") }
            }
        }
        if (Test-Path $settingsDst) {
            $cfg = [IO.File]::ReadAllText($settingsDst) | ConvertFrom-Json
            if ($cfg.enabledPlugins) {
                foreach ($p in $cfg.enabledPlugins.PSObject.Properties) {
                    if ($p.Value -ne $true) { continue }
                    Write-Host "  plugin $($p.Name)"
                    claude plugin install $p.Name 2>&1 | Out-Host
                    if ($LASTEXITCODE -ne 0) { $Manual.Add("/plugin install $($p.Name)") }
                }
            }
        }
    }
}

# ---------------------------------------------------------------- PowerShell profile
if (-not $SkipProfile) {
    Step 'PowerShell profile'
    $profileSrc = Join-Path $SrcPs 'profile.ps1'
    if (Test-Path $profileSrc) {
        $themeRef = Join-Path $SrcPs 'theme-path.txt'
        if (Test-Path $themeRef) {
            $themeDst = Convert-FromTokens ([IO.File]::ReadAllText($themeRef)).Trim()
            $themeSrc = Join-Path $SrcPs (Split-Path $themeDst -Leaf)
            if (Test-Path $themeSrc) {
                New-Item -ItemType Directory -Force -Path (Split-Path $themeDst -Parent) | Out-Null
                Copy-Item $themeSrc $themeDst -Force
                Write-Host "  theme -> $themeDst"
            }
        }
        Install-Config $profileSrc $PROFILE
    } else { Write-Host '  no exported profile in repo; skipped' }
}

# ---------------------------------------------------------------- summary
Step 'Done'
if (Test-Path $BackupDir) { Write-Host "Previous files backed up to $BackupDir" }
Write-Host 'Next: close and reopen the terminal, run "claude" and log in, then /doctor.'
if ($Manual.Count -gt 0) {
    Write-Host "`nNeeds manual follow-up:" -ForegroundColor Yellow
    $Manual | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}
