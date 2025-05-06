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

[System.Uri]$Uri = $Url.TrimEnd('/')
$ManagedPath = $Uri.Segments[1]
$Alias = $Uri.Segments[2]
$AdminSiteUrl = (@($Uri.Scheme, "://", $Uri.Authority) -join "").Replace(".sharepoint.com", "-admin.sharepoint.com")
$TemplatesBasePath = "$PSScriptRoot/Templates"

Set-PnPTraceLog -Off

# TODO: Replace version from package.json/git-tag
Write-Host "Installing Prosjektportalen Leverandørmal version 1.0.0" -ForegroundColor Cyan

Connect-PnPOnline -Url $AdminSiteUrl -Interactive -ClientId $ClientId -ErrorAction Stop -WarningAction Ignore
$CurrentUser = Get-PnPProperty -Property CurrentUser -ClientObject (Get-PnPContext).Web
Write-Host "[INFO] Installing with user [$($CurrentUser.Email)]"

StartAction("Adding site scripts")
$ExistingSiteScript = Get-PnPSiteScript | Where-Object { $_.Title -eq "Innholdstype - Sikkerhetsloggelement" }
if ($null -eq $ExistingSiteScript) {
  $Content = (Get-Content -Path "./SiteScripts/Sikkerhetsloggelement.txt" -Raw | Out-String)
  $SiteScript = Add-PnPSiteScript -Title "Innholdstype - Sikkerhetsloggelement" -Content $Content
}
EndAction

StartAction("Configuring site designs")
$SiteDesignMainName = [Uri]::UnescapeDataString("Prosjektomr%C3%A5de")

$SiteScriptMainIds = @()
$SiteScripts = Get-PnPSiteScript | Where-Object { $_.Title -notlike "* - Test" }
foreach ($SiteScript in $SiteScripts) {
  $SiteScriptMainIds += $SiteScript.Id.Guid
}

$SiteDesignMain = Get-PnPSiteDesign -Identity $SiteDesignMainName
if ($null -eq $SiteDesignMain) {
  Write-Host "[WARNING] Site design '$SiteDesignMainName' not found. Skipping update." -ForegroundColor Yellow
} else {
  $SiteDesignMain = Set-PnPSiteDesign -Identity $SiteDesignMain -SiteScriptIds $SiteScriptMainIds
}

$SiteDesignTestName = [Uri]::UnescapeDataString("Prosjektomr%C3%A5de [test]")

$SiteScriptTestIds = @()
$SiteScripts = Get-PnPSiteScript | Where-Object { $_.Title -like "* - Test" -or $_.Title -like "*Sikkerhetsloggelement*" }

foreach ($SiteScript in $SiteScripts) {
  $SiteScriptTestIds += $SiteScript.Id.Guid
}

$SiteDesignTest = Get-PnPSiteDesign -Identity $SiteDesignTestName
if ($null -eq $SiteDesignTest) {
  Write-Host "[WARNING] Site design '$SiteDesignTestName' not found. Skipping update." -ForegroundColor Yellow
} else {
  $SiteDesignTest = Set-PnPSiteDesign -Identity $SiteDesignTest -SiteScriptIds $SiteScriptTestIds
}
EndAction

StartAction("Applying Leverandørmal template")
Connect-PnPOnline -Url $Url -Interactive -ClientId $ClientId -ErrorAction Stop
Invoke-PnPSiteTemplate -Path "$($TemplatesBasePath)/Leverandørmal.pnp" -ErrorAction Stop -WarningAction Ignore
EndAction

StartAction("Configuring Leverandørmal tillegg and standardinnhold")
try {

  Connect-PnPOnline -Url $Url -Interactive -ClientId $ClientId -ErrorAction Stop

  $Prosjekttillegg = Get-PnPListItem -List Prosjekttillegg
  $Maloppsett = Get-PnPListItem -List Maloppsett
  
  $MalOppsettTemplate = $Maloppsett | Where-Object { $_["Title"] -eq "Leverandørmal" }
  if ($null -ne $MalOppsettTemplate) {
    $TemplateTillegg = $Prosjekttillegg | Where-Object { $_["Title"] -eq "Leverandørmal" }
    $MalOppsettTemplate["GtProjectExtensions"] = [Microsoft.SharePoint.Client.FieldLookupValue]@{"LookupId" = $TemplateTillegg.Id }
  
    $MalOppsettTemplate.SystemUpdate()
    $MalOppsettTemplate.Context.ExecuteQuery()
  }
  else {
    Write-Host "[WARNING] Failed to find Leverandørmal template. Please check the Maloppsett list." -ForegroundColor Yellow
  }

  $MalOppsettTemplate = $Maloppsett | Where-Object { $_["Title"] -eq "Overordnet leverandørmal" }
  if ($null -ne $MalOppsettTemplate) {
    $TemplateTillegg = $Prosjekttillegg | Where-Object { $_["Title"] -eq "Overordnet leverandørmal" }
    $MalOppsettTemplate["GtProjectExtensions"] = [Microsoft.SharePoint.Client.FieldLookupValue]@{"LookupId" = $TemplateTillegg.Id }
  
    $MalOppsettTemplate.SystemUpdate()
    $MalOppsettTemplate.Context.ExecuteQuery()
  }
  else {
    Write-Host "[WARNING] Failed to find Leverandørmal template. Please check the Maloppsett list." -ForegroundColor Yellow
  }
}
catch {
  EndAction
  Write-Host "[WARNING] Failed to configure tillegg and standardinnhold: $($_.Exception.Message)" -ForegroundColor Yellow
}
EndAction

Write-Host "[INFO] Logging installation entry" 
Connect-PnPOnline -Url $Url -Interactive -ClientId $ClientId -ErrorAction Stop
$LastInstall = Get-PnPListItem -List "Installasjonslogg" -Query "<View><Query><OrderBy><FieldRef Name='Created' Ascending='False' /></OrderBy></Query></View>" | Select-Object -First 1 -Wait
$PreviousVersion = "N/A"
if ($null -ne $LastInstall) {
  $PreviousVersion = $LastInstall.FieldValues["InstallVersion"]
}

# TODO: Replace version from package.json/git-tag
$CustomizationInfo = "Prosjektportalen Leverandørmal 1.0.0"
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

$LoggedEntry = Add-PnPListItem -List "Installasjonslogg" -Values $InstallEntry -ErrorAction Continue

Write-Host "Installation of Leverandørmalen complete!" -ForegroundColor Green