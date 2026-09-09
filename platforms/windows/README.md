# Windows

Windows has its own PowerShell installer. It links only the files that native
Windows programs use: WezTerm, Alacritty, Zed, PowerShell, VS Code, Neovim, and
Starship. It also writes an untracked `alacritty\local.toml` holding the PowerShell
shell setting, and copies the Pinacoteca colour scheme into Windows Terminal's
fragments folder; pick it under Settings > Color schemes afterwards.

To match the Windows accent colour to the theme, run the optional script:

```powershell
pwsh -File .\theme\pinacoteca\windows-accent.ps1 -DryRun
pwsh -File .\theme\pinacoteca\windows-accent.ps1
```

Preview the changes:

```powershell
pwsh -File .\platforms\windows\install.ps1 -DryRun
```

Link the configuration files:

```powershell
pwsh -File .\platforms\windows\install.ps1
```

Package installation is opt-in:

```powershell
pwsh -File .\platforms\windows\install.ps1 -InstallPackages
```

The package option uses WinGet to install Git, PowerShell, VS Code, Neovim,
Starship, WezTerm, Alacritty, Zed, the JetBrains Mono Nerd Font and the usual
CLI tools, and also installs the `Terminal-Icons` and `PSFzf` PowerShell
modules. Existing target files get timestamped backups.

Windows Developer Mode allows the script to create symbolic links without an
elevated shell. If link creation is unavailable, the script copies the file and
prints a warning. Copied files will not follow later repository changes, so
enabling Developer Mode is the better setup.
