# Pinacoteca colours for PSReadLine. Palette and provenance: theme/pinacoteca/colors.toml
if (Get-Module -ListAvailable PSReadLine) {
    Set-PSReadLineOption -Colors @{
        Command                = '{{blue}}'
        Parameter              = '{{fg}}'
        Operator               = '{{fg_dim}}'
        Variable               = '{{fg}}'
        String                 = '{{green}}'
        Number                 = '{{orange}}'
        Type                   = '{{gold}}'
        Keyword                = '{{purple}}'
        Member                 = '{{fg}}'
        Comment                = '{{comment}}'
        Emphasis               = '{{gold}}'
        Error                  = '{{red}}'
        Selection              = "`e[48;2;{{bg3:rgb}}m"
        InlinePrediction       = '{{comment}}'
        ListPrediction         = '{{aqua}}'
        ListPredictionSelected = "`e[48;2;{{bg2:rgb}}m"
        ContinuationPrompt     = '{{comment}}'
        Default                = '{{fg}}'
    }
}
