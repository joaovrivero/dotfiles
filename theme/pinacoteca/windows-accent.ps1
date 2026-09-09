#Requires -Version 5.1
<#
Sets the Windows accent colour to Pinacoteca gold (#D7A447) and switches Windows and
apps to dark mode. Run from PowerShell on Windows. Reversible from
Settings > Personalization > Colors.
#>
[CmdletBinding()]
param([switch]$DryRun)

$gold = 0xD7, 0xA4, 0x47          # R G B
$abgr = [uint32](($gold[2] -shl 16) -bor ($gold[1] -shl 8) -bor $gold[0]) -bor 0xFF000000

$dwm = 'HKCU:\Software\Microsoft\Windows\DWM'
$accent = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
$personalize = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'

$changes = @(
    @{ Path = $dwm; Name = 'AccentColor'; Value = $abgr; Type = 'DWord' }
    @{ Path = $dwm; Name = 'ColorizationColor'; Value = [uint32](0xC4000000 -bor ($gold[0] -shl 16) -bor ($gold[1] -shl 8) -bor $gold[2]); Type = 'DWord' }
    @{ Path = $dwm; Name = 'ColorizationAfterglow'; Value = [uint32](0xC4000000 -bor ($gold[0] -shl 16) -bor ($gold[1] -shl 8) -bor $gold[2]); Type = 'DWord' }
    @{ Path = $dwm; Name = 'ColorPrevalence'; Value = 1; Type = 'DWord' }
    @{ Path = $accent; Name = 'AccentColorMenu'; Value = $abgr; Type = 'DWord' }
    @{ Path = $accent; Name = 'StartColorMenu'; Value = $abgr; Type = 'DWord' }
    @{ Path = $personalize; Name = 'AppsUseLightTheme'; Value = 0; Type = 'DWord' }
    @{ Path = $personalize; Name = 'SystemUsesLightTheme'; Value = 0; Type = 'DWord' }
    @{ Path = $personalize; Name = 'ColorPrevalence'; Value = 1; Type = 'DWord' }
)

foreach ($c in $changes) {
    Write-Host ("  {0}\{1} = 0x{2:X8}" -f $c.Path, $c.Name, [uint32]$c.Value)
    if (-not $DryRun) {
        if (-not (Test-Path $c.Path)) { New-Item -Path $c.Path -Force | Out-Null }
        Set-ItemProperty -Path $c.Path -Name $c.Name -Value $c.Value -Type $c.Type
    }
}

if ($DryRun) { Write-Warning 'Dry run: nothing changed.'; return }

# Ask the shell to re-read the colour set.
Add-Type -Namespace Win32 -Name Native -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
$result = [UIntPtr]::Zero
[Win32.Native]::SendMessageTimeout([IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, 'ImmersiveColorSet', 2, 5000, [ref]$result) | Out-Null
Write-Host 'Accent set to #D7A447. If the taskbar does not update, sign out and back in, or pick Custom colour #D7A447 in Settings > Personalization > Colors.'
