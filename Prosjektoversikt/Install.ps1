Param(
    [Parameter(Mandatory = $true, HelpMessage = "N/A")]
    [string]$Url,
    [Parameter(Mandatory = $false, HelpMessage = "N/A")]
    [string]$AppCatalogUrl
)

if ($AppCatalogUrl) {
    Connect-PnPOnline -Url $Url -UseWebLogin
    Add-PnPApp -Path .\sharepoint\solution\pp-addons-prosjektoversikt.sppkg -Scope Tenant -Publish -Overwrite -SkipFeatureDeployment -ErrorAction Stop >$null 2>&1
}
else {
    Connect-PnPOnline -Url $Url -UseWebLogin
    Apply-PnPProvisioningTemplate -Path .\template.xml
}