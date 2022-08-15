Param(
    [Parameter(Mandatory = $true, HelpMessage = "URL to the site where you want to add the page with web part")]
    [string]$Url
)

$Command = Get-Command connect-pnponline

if ($null -eq $Command -or $Command.Source -ne "SharePointPnPPowerShellOnline") {
    Write-Host "SharePointPnPPowerShellOnline is not loaded. Unable to continue" -ForegroundColor Red
    return
}

Set-PnPTraceLog -Off

Connect-PnPOnline -Url $Url -UseWebLogin
$AppCatalogUrl = Get-PnPTenantAppCatalogUrl

Write-Host "Adding app to the tenant app catalog"
Connect-PnPOnline -Url $AppCatalogUrl -UseWebLogin
$App = Add-PnPApp -Path .\pp-addons-prosjektoversikt.sppkg -Scope Tenant -Publish -Overwrite -SkipFeatureDeployment -ErrorAction Stop

Write-Host "Adding page and app to $Url"
Connect-PnPOnline -Url $Url -UseWebLogin
Apply-PnPProvisioningTemplate -Path .\template.xml

Write-Host "Installation completed. The app is available at $($Url + "/SitePages/Prosjektoversikt.aspx")"
Write-Host "Verify that the correct portfolio(s) is configured at $($Url + "/Lists/Prosjektoversiktkonfigurasjon/AllItems.aspx")"