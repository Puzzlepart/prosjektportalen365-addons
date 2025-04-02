Param(
  [Parameter(Mandatory = $true, HelpMessage = "URL to the Prosjektportalen hub site")]
  [string]$Url,
  [Parameter(Mandatory = $false, HelpMessage = "Client ID of the Entra Id application used for interactive logins. Defaults to the multi-tenant Prosjektportalen app")]
  [string]$ClientId = "da6c31a6-b557-4ac3-9994-7315da06ea3a",
  [Parameter(Mandatory = $false, HelpMessage = "Do you want to perform an upgrade?")]
  [switch]$Upgrade
)

<#
Starts an action and writes the action name to the console. Make sure to update the $global:ACTIONS_COUNT before
adding a new action. Uses -NoNewline to avoid a line break before the elapsed time is written.
#>
function StartAction($Action) {
  $global:StopWatch_Action = [Diagnostics.Stopwatch]::StartNew()
  Write-Host "$Action... " -NoNewline
}

<#
Ends an action and writes the elapsed time to the console.
#>
function EndAction() {
  $global:StopWatch_Action.Stop()
  $ElapsedSeconds = [math]::Round(($global:StopWatch_Action.ElapsedMilliseconds) / 1000, 2)
  Write-Host "Completed in $($ElapsedSeconds)s" -ForegroundColor Green
}

#region Setting variables based on input from user
[System.Uri]$Uri = $Url.TrimEnd('/')
$ManagedPath = $Uri.Segments[1]
$Alias = $Uri.Segments[2]
$AdminSiteUrl = (@($Uri.Scheme, "://", $Uri.Authority) -join "").Replace(".sharepoint.com", "-admin.sharepoint.com")
$TemplatesBasePath = "$PSScriptRoot/Templates"
#endregion

Set-PnPTraceLog -Off

# TODO: Replace version from package.json/git-tag
Write-Host "Installing Prosjektportalen Forskningsmal version 1.0.0" -ForegroundColor Cyan

#region Print installation user
Connect-PnPOnline -Url $AdminSiteUrl -Interactive -ClientId $ClientId -ErrorAction Stop -WarningAction Ignore
$CurrentUser = Get-PnPProperty -Property CurrentUser -ClientObject (Get-PnPContext).Web
Write-Host "[INFO] Installing with user [$($CurrentUser.Email)]"
#endregion

StartAction("Adding site scripts")
$ExistingSiteScript = Get-PnPSiteScript | Where-Object { $_.Title -eq "Innholdstype - Publiseringelement" }
if ($null -eq $ExistingSiteScript) {
  $Content = (Get-Content -Path "./SiteScripts/Publiseringelement.txt" -Raw | Out-String)
  $SiteScript = Add-PnPSiteScript -Title "Innholdstype - Publiseringelement" -Content $Content
  EndAction
}

StartAction("Configuring site designs")
$SiteDesignName = "Prosjektomr%C3%A5de"
$SiteDesignName = [Uri]::UnescapeDataString($SiteDesignName)

$SiteScriptMainIds = @()
$SiteScripts = Get-PnPSiteScript | Where-Object { $_.Title -notlike "* - Test" }
foreach ($SiteScript in $SiteScripts) {
  $SiteScriptMainIds += $SiteScript.Id.Guid
}

$SiteDesign = Get-PnPSiteDesign -Identity $SiteDesignName
$SiteDesign = Set-PnPSiteDesign -Identity $SiteDesign -SiteScriptIds $SiteScriptMainIds

# Update sitedesign for Prosjektportalen with the new contenttype (Test channel)
# Pre-requisite: SiteScripts for the new contenttype must be created beforehand

$SiteDesignName = "Prosjektomr%C3%A5de [test]"
$SiteDesignName = [Uri]::UnescapeDataString($SiteDesignName)

$SiteScriptTestIds = @()
$SiteScripts = Get-PnPSiteScript | Where-Object { $_.Title -like "* - Test" -or $_.Title -like "*Publiseringelement*" }

foreach ($SiteScript in $SiteScripts) {
  $SiteScriptTestIds += $SiteScript.Id.Guid
}

$SiteDesign = Get-PnPSiteDesign -Identity $SiteDesignName
$SiteDesign = Set-PnPSiteDesign -Identity $SiteDesign -SiteScriptIds $SiteScriptTestIds
EndAction


#region Apply Template
StartAction("Applying Forskningsmal template")
Connect-PnPOnline -Url $Url -Interactive -ClientId $ClientId -ErrorAction Stop
Invoke-PnPSiteTemplate -Path "$($TemplatesBasePath)/Forskningsmal.pnp" -ErrorAction Stop -WarningAction Ignore
EndAction
#endregion

#region Configure tillegg 
StartAction("Configuring Forskningsmal tillegg and standardinnhold")
try {

  Connect-PnPOnline -Url $Url -Interactive -ClientId $ClientId -ErrorAction Stop

  $ListContent = Get-PnPListItem -List Listeinnhold
  $Prosjekttillegg = Get-PnPListItem -List Prosjekttillegg
  $Maloppsett = Get-PnPListItem -List Maloppsett
  
  $MalOppsettTemplate = $Maloppsett | Where-Object { $_["Title"] -eq "Forskning" }
  if ($null -ne $MalOppsettTemplate) {
    $TemplateChecklist = $ListContent | Where-Object { $_["Title"] -eq "Fasesjekkpunkter Forskning" }
    $TemplateDefaultContent = @()
    $TemplateDefaultContent += [Microsoft.SharePoint.Client.FieldLookupValue]@{"LookupId" = $TemplateChecklist.Id }
    $MalOppsettTemplate["ListContentConfigLookup"] = $TemplateDefaultContent

    $TemplateTillegg = $Prosjekttillegg | Where-Object { $_["Title"] -eq "Forskningsmal" }
    $MalOppsettTemplate["GtProjectExtensions"] = [Microsoft.SharePoint.Client.FieldLookupValue]@{"LookupId" = $TemplateTillegg.Id }
  
    $MalOppsettTemplate.SystemUpdate()
    $MalOppsettTemplate.Context.ExecuteQuery()
  }
  else {
    Write-Host "[WARNING] Failed to find Forskningsmal template. Please check the Maloppsett list." -ForegroundColor Yellow
  }
}
catch {
  EndAction
  Write-Host "[WARNING] Failed to configure tillegg and standardinnhold: $($_.Exception.Message)" -ForegroundColor Yellow
}
EndAction
#endregion

#region Logging installation
Write-Host "[INFO] Logging installation entry" 
Connect-PnPOnline -Url $Url -Interactive -ClientId $ClientId -ErrorAction Stop
$LastInstall = Get-PnPListItem -List "Installasjonslogg" -Query "<View><Query><OrderBy><FieldRef Name='Created' Ascending='False' /></OrderBy></Query></View>" | Select-Object -First 1 -Wait
$PreviousVersion = "N/A"
if ($null -ne $LastInstall) {
  $PreviousVersion = $LastInstall.FieldValues["InstallVersion"]
}

# TODO: Replace version from package.json/git-tag
$CustomizationInfo = "Prosjektportalen Forskningsmal 1.0.0"
$InstallStartTime = (Get-Date -Format o)
$InstallEndTime = (Get-Date -Format o)

$InstallEntry = @{
  Title            = $CustomizationInfo;
  InstallStartTime = $InstallStartTime; 
  InstallEndTime   = $InstallEndTime; 
  InstallVersion   = $PreviousVersion;
  InstallCommand   = $MyInvocation.Line.Substring(2);
}

if ($null -ne $CurrentUser.Email) {
  $InstallEntry.InstallUser = $CurrentUser.Email
}

## Logging installation to SharePoint list
Add-PnPListItem -List "Installasjonslogg" -Values $InstallEntry -ErrorAction SilentlyContinue >$null 2>&1

#endregion

Write-Host "Installation of Forskningsmalen complete!" -ForegroundColor Green