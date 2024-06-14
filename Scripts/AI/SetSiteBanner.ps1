Param(
    [Parameter(Mandatory = $false)]
    [string]$Url,
    [string]$BannerText = "Prosjektet ditt fylles nå med innhold generert av Puzzleparts hjelpsomme assistenter! 🤖 Dette tar bare noen få minutter! 🚚",
    [string]$BannerInternalName = "CustomAIBanner",
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
    Get-PnPCustomAction | Where-Object {$_.Name -eq $BannerInternalName} | Remove-PnPCustomAction -Force
    $CustomAction = Add-PnPCustomAction -Title $BannerInternalName -Name $BannerInternalName -Location "ClientSideExtension.ApplicationCustomizer" -ClientSideComponentId "1e2688c4-99d8-4897-8871-a9c151ccfc87" -ClientSideComponentProperties "{`"message`":`"$BannerText`",`"textColor`":`"`#000000`",`"backgroundColor`":`"`#E9FCFD`",`"textFontSizePx`":16,`"bannerHeightPx`":48,`"visibleStartDate`":null,`"enableSetPreAllocatedTopHeight`":false,`"disableSiteAdminUI`":false}" -Scope Web
} else {
    Write-Output "`tRemoving banner from site $Url"
    Get-PnPCustomAction | Where-Object {$_.Name -eq $BannerInternalName} | Remove-PnPCustomAction -Force
}