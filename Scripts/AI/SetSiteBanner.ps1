Param(
    [Parameter(Mandatory = $false)]
    [string]$Url,
    [string]$BannerText = "Prosjektet ditt fylles med innhold generert av Puzzleparts hjelpsomme assistenter! Klart om få strakser!",
    [bool]$Disable
)

function Connect-SharePoint($Url) {
    $pnpParams = @{ 
        Url = $Url
    }
    if ($null -ne $PSPrivateMetadata) {
        #azure runbook context
        $pnpParams.Add("ManagedIdentity", $true)
    }
    else {
        $pnpParams.Add("Interactive", $true)
    }

    Connect-PnPOnline @pnpParams
}

Connect-SharePoint -Url $Url

if (-not $Disable) {
    Write-Output "`tAdding banner to site $Url"
    Set-PnPSite -NoScriptSite $false
    $Output = Remove-PnPCustomAction -Identity "CustomAIBanner" -Scope Site -Force -ErrorAction SilentlyContinue
    $CustomAction = Add-PnPCustomAction -Title "CustomAIBanner" -Name "CustomAIBanner" -Location "ClientSideExtension.ApplicationCustomizer" -ClientSideComponentId "1e2688c4-99d8-4897-8871-a9c151ccfc87" -ClientSideComponentProperties "{`"message`":`"$BannerText`",`"textColor`":`"`#000000`",`"backgroundColor`":`"`#E9FCFD`",`"textFontSizePx`":12,`"bannerHeightPx`":32,`"visibleStartDate`":null,`"enableSetPreAllocatedTopHeight`":false,`"disableSiteAdminUI`":true}" -Scope Web
} else {
    Write-Output "`tRemoving banner from site $Url"
    Set-PnPSite -NoScriptSite $false
    $Output = Remove-PnPCustomAction -Identity "CustomAIBanner" -Scope Web -Force -ErrorAction SilentlyContinue
}
Set-PnPSite -NoScriptSite $true
