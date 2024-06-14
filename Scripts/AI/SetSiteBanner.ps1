Param(
    [Parameter(Mandatory = $false)]
    [string]$Url,
    [string]$BannerText = "Prosjektet ditt fylles med innhold generert av Puzzleparts hjelpsomme assistenter! Klart om få strakser!",
    [bool]$Disable
)

. .\CommonPPAI.ps1

Connect-SharePoint -Url $Url

try {
    Set-PnPSite -NoScriptSite $false
}
catch {
    Write-Output "Error setting noscriptsite"
}

if (-not $Disable) {
    Write-Output "`tAdding banner to site $Url"
    $Output = Remove-PnPCustomAction -Identity "CustomAIBanner" -Scope Site -Force -ErrorAction SilentlyContinue
    $CustomAction = Add-PnPCustomAction -Title "CustomAIBanner" -Name "CustomAIBanner" -Location "ClientSideExtension.ApplicationCustomizer" -ClientSideComponentId "1e2688c4-99d8-4897-8871-a9c151ccfc87" -ClientSideComponentProperties "{`"message`":`"$BannerText`",`"textColor`":`"`#000000`",`"backgroundColor`":`"`#E9FCFD`",`"textFontSizePx`":12,`"bannerHeightPx`":32,`"visibleStartDate`":null,`"enableSetPreAllocatedTopHeight`":false,`"disableSiteAdminUI`":true}" -Scope Web
} else {
    Write-Output "`tRemoving banner from site $Url"
    $Output = Remove-PnPCustomAction -Identity "CustomAIBanner" -Scope Web -Force -ErrorAction SilentlyContinue
}