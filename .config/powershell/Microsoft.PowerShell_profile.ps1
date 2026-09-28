if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/takuya.omp.json" | Invoke-Expression
}

Import-Module -Name Terminal-Icons -ErrorAction SilentlyContinue

# pinacoteca:begin
# Pinacoteca colours for PSReadLine. Palette and provenance: theme/pinacoteca/colors.toml
if (Get-Module -ListAvailable PSReadLine) {
    Set-PSReadLineOption -Colors @{
        Command                = '#799dbb'
        Parameter              = '#e6ccaf'
        Operator               = '#b19a80'
        Variable               = '#e6ccaf'
        String                 = '#88ab75'
        Number                 = '#d77f47'
        Type                   = '#d7a447'
        Keyword                = '#ad8ab6'
        Member                 = '#e6ccaf'
        Comment                = '#7d6b59'
        Emphasis               = '#d7a447'
        Error                  = '#d67066'
        Selection              = "`e[48;2;69;59;50m"
        InlinePrediction       = '#7d6b59'
        ListPrediction         = '#6cabab'
        ListPredictionSelected = "`e[48;2;46;40;34m"
        ContinuationPrompt     = '#7d6b59'
        Default                = '#e6ccaf'
    }
}
# pinacoteca:end

Set-Alias -Name vim -Value nvim
Set-Alias ll ls
Set-Alias g git
if ($IsWindows) {
    Set-Alias grep findstr
    Set-Alias tig 'C:\Program Files\Git\usr\bin\tig.exe'
    Set-Alias less 'C:\Program Files\Git\usr\bin\less.exe'
}

if (Get-Module -ListAvailable PSFzf) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f' -PSReadlineChordReverseHistory 'Ctrl+r'
}
