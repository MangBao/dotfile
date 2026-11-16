<#
.SYNOPSIS
  Snapshot the current machine's Claude Code + PowerShell config into this repo.
  Run on the machine that is already set up. Home paths are replaced by tokens
  so the files work for any username.
.PARAMETER Force
  Overwrite claude/CLAUDE.md in the repo with the live ~/.claude/CLAUDE.md,
  and export settings.json even if it looks like it contains secrets.
#>
param([switch]$Force)
$ErrorActionPreference = 'Stop'

$Repo      = $PSScriptRoot
$ClaudeDir = Join-Path $HOME '.claude'
$OutClaude = Join-Path $Repo 'claude'
$OutPs     = Join-Path $Repo 'powershell'
$Utf8      = New-Object System.Text.UTF8Encoding($false)
New-Item -ItemType Directory -Force -Path $OutClaude, (Join-Path $OutClaude 'hooks'), (Join-Path $OutClaude 'plugins'), $OutPs | Out-Null

function Convert-ToTokens([string]$Text) {
    $homeJson = $HOME.Replace('\', '\\')
    $homeFwd  = $HOME.Replace('\', '/')
    return $Text.Replace($homeJson, '{{HOME_JSON}}').Replace($homeFwd, '{{HOME_FWD}}').Replace($HOME, '{{HOME}}')
}
function Save-Tokenized([string]$Src, [string]$Dst) {
    $text = [IO.File]::ReadAllText($Src)
    [IO.File]::WriteAllText($Dst, (Convert-ToTokens $text), $Utf8)
    Write-Host "  exported $Src"
}

Write-Host '== Claude Code config'

# settings.json
$settings = Join-Path $ClaudeDir 'settings.json'
if (Test-Path $settings) {
    $raw = [IO.File]::ReadAllText($settings)
    if (($raw -match '(?i)"[A-Z0-9_]*(API_KEY|TOKEN|SECRET|PASSWORD)[A-Z0-9_]*"\s*:') -and -not $Force) {
        throw "settings.json looks like it contains a secret (API_KEY/TOKEN/SECRET/PASSWORD). Remove it, or re-run with -Force if you are sure it is safe."
    }
    if ($raw -match 'hook-guard') {
        Write-Warning 'settings.json still contains graphify hook-guard hooks (global). Consider running "graphify claude uninstall" first.'
    }
    if ($raw -notmatch 'Bash\(git push') {
        Write-Warning 'settings.json has no deny rule for git push/commit. Add them under permissions.deny.'
    }
    Save-Tokenized $settings (Join-Path $OutClaude 'settings.json')
} else {
    Write-Warning "No $settings found; install.ps1 will fall back to settings.base.json"
}

# CLAUDE.md (repo copy is the source of truth unless -Force)
$liveMd = Join-Path $ClaudeDir 'CLAUDE.md'
$repoMd = Join-Path $OutClaude 'CLAUDE.md'
if (Test-Path $liveMd) {
    if ((Test-Path $repoMd) -and -not $Force) {
        Write-Host '  skipped CLAUDE.md (repo copy kept; use -Force to overwrite)'
    } else {
        Save-Tokenized $liveMd $repoMd
    }
}

# hooks
$hooksDir = Join-Path $ClaudeDir 'hooks'
if (Test-Path $hooksDir) {
    Get-ChildItem $hooksDir -File | ForEach-Object {
        Save-Tokenized $_.FullName (Join-Path $OutClaude "hooks\$($_.Name)")
    }
}

# plugin marketplaces (list of sources only, not plugin caches)
$markets = Join-Path $ClaudeDir 'plugins\known_marketplaces.json'
if (Test-Path $markets) {
    Save-Tokenized $markets (Join-Path $OutClaude 'plugins\known_marketplaces.json')
}

Write-Host '== PowerShell profile'
if (Test-Path $PROFILE) {
    Save-Tokenized $PROFILE (Join-Path $OutPs 'profile.ps1')
    $profileText = [IO.File]::ReadAllText($PROFILE)
    $m = [regex]::Match($profileText, '--config\s+["'']?([^"''\s|)]+)')
    if ($m.Success) {
        $themePath = [Environment]::ExpandEnvironmentVariables($m.Groups[1].Value.Replace('$env:POSH_THEMES_PATH', $env:POSH_THEMES_PATH).Replace('$HOME', $HOME).Replace('~', $HOME))
        if (($themePath -notmatch '^https?://') -and (Test-Path $themePath)) {
            $name = Split-Path $themePath -Leaf
            Copy-Item $themePath (Join-Path $OutPs $name) -Force
            [IO.File]::WriteAllText((Join-Path $OutPs 'theme-path.txt'), (Convert-ToTokens $themePath), $Utf8)
            Write-Host "  exported Oh My Posh theme $themePath"
        }
    }
} else {
    Write-Host "  no profile at $PROFILE"
}

Write-Host ''
Write-Host 'Done. Review the files (especially claude/settings.json) before committing.'
