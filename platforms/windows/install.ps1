#Requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$InstallPackages,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
if (-not $IsWindows) {
    throw 'Run this installer from PowerShell on Windows.'
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$timestamp = Get-Date -Format 'yyyy.MM.dd-HH.mm.ss'

function Write-Step([string]$Message) {
    Write-Host "`n==> $Message" -ForegroundColor Blue
}

function Install-WingetPackages {
    if (-not $InstallPackages) {
        return
    }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'WinGet is required when -InstallPackages is used.'
    }

    Write-Step 'Installing Windows applications'
    $packages = @(
        'Alacritty.Alacritty'
        'DEVCOM.JetBrainsMonoNerdFont'
        'Git.Git'
        'XBMCFoundation.Kodi'
        'ciromattia.KCC'
        'Microsoft.PowerShell'
        'Spicetify.Spicetify'
        'Microsoft.VisualStudioCode'
        'Neovim.Neovim'
        'Starship.Starship'
        'Wez.WezTerm'
        'ZedIndustries.Zed'
        'JanDeDobbeleer.OhMyPosh'
        'JesseDuffield.lazygit'
        'junegunn.fzf'
        'BurntSushi.ripgrep.MSVC'
        'sharkdp.fd'
        'eza-community.eza'
        'ajeetdsouza.zoxide'
    )

    foreach ($package in $packages) {
        Write-Host "  winget install --id $package"
        if (-not $DryRun) {
            winget install --id $package --exact --silent `
                --accept-package-agreements --accept-source-agreements
        }
    }

    if (-not $DryRun) {
        Install-Module Terminal-Icons, PSFzf -Scope CurrentUser -Force
    }
}

function Set-DotfileLink {
    param(
        [Parameter(Mandatory)] [string]$Source,
        [Parameter(Mandatory)] [string]$Target
    )

    $sourcePath = (Resolve-Path $Source).Path
    if (Test-Path -LiteralPath $Target) {
        $item = Get-Item -LiteralPath $Target -Force
        if ($item.LinkType -and $item.Target -contains $sourcePath) {
            Write-Host "  already linked: $Target"
            return
        }

        $backup = "$Target.bak.$timestamp"
        Write-Host "  backup: $Target -> $backup"
        if (-not $DryRun) {
            Move-Item -LiteralPath $Target -Destination $backup
        }
    }

    Write-Host "  link: $Target -> $sourcePath"
    if ($DryRun) {
        return
    }

    $parent = Split-Path -Parent $Target
    New-Item -ItemType Directory -Path $parent -Force | Out-Null

    try {
        New-Item -ItemType SymbolicLink -Path $Target -Target $sourcePath | Out-Null
    }
    catch {
        Write-Warning "Symbolic links need Developer Mode or an elevated shell. Copying $Target instead."
        Copy-Item -LiteralPath $sourcePath -Destination $Target -Recurse
    }
}

Install-WingetPackages
Write-Step 'Linking Windows configuration files'

$documents = [Environment]::GetFolderPath('MyDocuments')
$links = @(
    @{
        Source = Join-Path $repoRoot '.config\wezterm\wezterm.lua'
        Target = Join-Path $HOME '.config\wezterm\wezterm.lua'
    }
    @{
        Source = Join-Path $repoRoot '.config\powershell\Microsoft.PowerShell_profile.ps1'
        Target = Join-Path $documents 'PowerShell\Microsoft.PowerShell_profile.ps1'
    }
    @{
        Source = Join-Path $repoRoot '.config\Code\User\settings.json'
        Target = Join-Path $env:APPDATA 'Code\User\settings.json'
    }
    @{
        Source = Join-Path $repoRoot '.config\nvim'
        Target = Join-Path $env:LOCALAPPDATA 'nvim'
    }
    @{
        Source = Join-Path $repoRoot '.config\starship.toml'
        Target = Join-Path $HOME '.config\starship.toml'
    }
    @{
        Source = Join-Path $repoRoot '.config\alacritty\alacritty.toml'
        Target = Join-Path $env:APPDATA 'alacritty\alacritty.toml'
    }
    @{
        Source = Join-Path $repoRoot '.config\alacritty\pinacoteca.toml'
        Target = Join-Path $env:APPDATA 'alacritty\pinacoteca.toml'
    }
    @{
        Source = Join-Path $repoRoot '.config\zed\settings.json'
        Target = Join-Path $env:APPDATA 'Zed\settings.json'
    }
    @{
        Source = Join-Path $repoRoot '.config\zed\themes\pinacoteca.json'
        Target = Join-Path $env:APPDATA 'Zed\themes\pinacoteca.json'
    }
    @{
        Source = Join-Path $repoRoot '.config\spicetify\Themes\Pinacoteca'
        Target = Join-Path $env:APPDATA 'spicetify\Themes\Pinacoteca'
    }
)

# WezTerm reads ~/.wezterm.lua before ~/.config/wezterm/wezterm.lua, so move an older one aside.
$legacyWezterm = Get-Item -LiteralPath (Join-Path $HOME '.wezterm.lua') -Force -ErrorAction SilentlyContinue
if ($legacyWezterm) {
    $backup = "$($legacyWezterm.FullName).bak.$timestamp"
    Write-Host "  backup: $($legacyWezterm.FullName) -> $backup"
    if (-not $DryRun) {
        Move-Item -LiteralPath $legacyWezterm.FullName -Destination $backup
    }
}

foreach ($link in $links) {
    Set-DotfileLink -Source $link.Source -Target $link.Target
}

# Alacritty reads the shell from an untracked local.toml so the shared config stays portable.
$alacrittyLocal = Join-Path $env:APPDATA 'alacritty\local.toml'
if (-not (Test-Path -LiteralPath $alacrittyLocal)) {
    Write-Host "  write: $alacrittyLocal"
    if (-not $DryRun) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $alacrittyLocal) -Force | Out-Null
        Set-Content -LiteralPath $alacrittyLocal -Value @(
            '# Machine-specific Alacritty settings. Not tracked in the dotfiles repository.'
            '[terminal]'
            'shell = { program = "pwsh.exe", args = ["-NoLogo"] }'
        )
    }
}

# Windows Terminal picks up colour schemes from JSON fragments.
$fragment = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\Pinacoteca\pinacoteca.json'
Write-Host "  copy: $fragment"
if (-not $DryRun) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $fragment) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot 'theme\pinacoteca\windows-terminal.json') -Destination $fragment -Force
}

Write-Step 'Windows setup complete'
if ($DryRun) {
    Write-Warning 'This was a dry run. No files or packages were changed.'
}
