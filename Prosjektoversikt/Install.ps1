Param(
    [Parameter(Mandatory = $true, HelpMessage = "URL to the site where you want to add the page with web part")]
    [string]$Url
)

Set-PnPTraceLog -Off

Connect-PnPOnline -Url $Url -Interactive
$AppCatalogUrl = Get-PnPTenantAppCatalogUrl

Write-Host "Adding app to the tenant app catalog"
Connect-PnPOnline -Url $AppCatalogUrl --Interactive
$App = Add-PnPApp -Path ./pp-addons-prosjektoversikt.sppkg -Scope Tenant -Publish -Overwrite -SkipFeatureDeployment -ErrorAction Stop

Write-Host "Adding page and app to $Url"
Connect-PnPOnline -Url $Url -Interactive
Invoke-PnPSiteTemplate -Path ./Templates/Template.xml

Write-Host "Installation completed. The app is available at $($Url + "/SitePages/Prosjektoversikt.aspx")"
Write-Host "Verify that the correct portfolio(s) is configured at $($Url + "/Lists/Prosjektoversiktkonfigurasjon/AllItems.aspx")"