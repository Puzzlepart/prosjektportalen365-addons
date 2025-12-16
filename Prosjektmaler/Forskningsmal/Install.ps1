Param(
  [Parameter(Mandatory = $true, HelpMessage = "URL to the Prosjektportalen hub site")]
  [string]$Url,
  [Parameter(Mandatory = $false, HelpMessage = "Client ID of the Entra Id application used for interactive logins. Defaults to the multi-tenant Prosjektportalen app")]
  [string]$ClientId = "da6c31a6-b557-4ac3-9994-7315da06ea3a",
  [Parameter(Mandatory = $false, HelpMessage = "Language")]
  [ValidateSet('Norwegian', 'English')]
  [string]$Language = "English",
  [Parameter(Mandatory = $false, HelpMessage = "Do you want to perform an upgrade?")]
  [switch]$Upgrade
)

#region Handling installation language and culture
$LanguageCodes = @{
  "Norwegian" = 'no-NB';
  "English"   = 'en-US';
}

$LanguageCode = $LanguageCodes[$Language]
. "$PSScriptRoot/Scripts/Resources.ps1"
Initialize-Resources -LanguageCode $LanguageCode

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

$LogFilePath = "$PSScriptRoot/Install_Log_$([datetime]::Now.ToString("yy-MM-ddThh-mm-ss")).txt"
Start-PnPTraceLog -Path $LogFilePath -Level Debug

# TODO: Replace version from package.json/git-tag
Write-Host "Installing Prosjektportalen Forskningsmal version 1.0.1" -ForegroundColor Cyan

#region Print installation user
Connect-PnPOnline -Url $AdminSiteUrl -ClientId $ClientId -ErrorAction Stop -WarningAction Ignore
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
$SiteDesignMainName = [Uri]::UnescapeDataString("Prosjektomr%C3%A5de")

$SiteScriptMainIds = @()
$SiteScripts = Get-PnPSiteScript | Where-Object { $_.Title -notlike "* - Test" }
foreach ($SiteScript in $SiteScripts) {
  $SiteScriptMainIds += $SiteScript.Id.Guid
}

$SiteDesignMain = Get-PnPSiteDesign -Identity $SiteDesignMainName
if ($null -eq $SiteDesignMain) {
  Write-Host "[WARNING] Site design '$SiteDesignMainName' not found. Skipping update." -ForegroundColor Yellow
}
else {
  $SiteDesignMain = Set-PnPSiteDesign -Identity $SiteDesignMain -SiteScriptIds $SiteScriptMainIds
}

$SiteDesignTestName = [Uri]::UnescapeDataString("Prosjektomr%C3%A5de [test]")

$SiteScriptTestIds = @()
$SiteScripts = Get-PnPSiteScript | Where-Object { $_.Title -like "* - Test" -or $_.Title -like "*Publiseringelement*" }

foreach ($SiteScript in $SiteScripts) {
  $SiteScriptTestIds += $SiteScript.Id.Guid
}

$SiteDesignTest = Get-PnPSiteDesign -Identity $SiteDesignTestName
if ($null -eq $SiteDesignTest) {
  Write-Host "[WARNING] Site design '$SiteDesignTestName' not found. Skipping update." -ForegroundColor Yellow
}
else {
  $SiteDesignTest = Set-PnPSiteDesign -Identity $SiteDesignTest -SiteScriptIds $SiteScriptTestIds
}
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

  Connect-PnPOnline -Url $Url -ClientId $ClientId -ErrorAction Stop

  $ListContentList = Get-PnPList -Identity (Get-Resource -Name "Lists_ListContent_Title") -ErrorAction Stop
  $ProjectExtensionsList = Get-PnPList -Identity (Get-Resource -Name "Lists_ProjectExtensions_Title") -ErrorAction Stop
  $TemplateOptionsList = Get-PnPList -Identity (Get-Resource -Name "Lists_TemplateOptions_Title") -ErrorAction Stop

  $ListContent = Get-PnPListItem -List $ListContentList.Id
  $ProjectExtension = Get-PnPListItem -List $ProjectExtensionsList.Id
  $TemplateOption = Get-PnPListItem -List $TemplateOptionsList.Id
  $ResearchTemplateOption = (Get-Resource -Name "Lists_ProjectExtensions_Title")
  $ResearchTemplateCheckList = (Get-Resource -Name "Lists_ListContent_PhaseCheckpoints_Title")
  $ResearchProjectExtension = (Get-Resource -Name "Files_ResearchTemplate_Title")
  
  $TemplateLayout = $TemplateOption | Where-Object { $_["Title"] -eq $ResearchTemplateOption }
  if ($null -ne $TemplateLayout) {
    $TemplateChecklist = $ListContent | Where-Object { $_["Title"] -eq $ResearchTemplateCheckList }
    $TemplateDefaultContent = @()
    $TemplateDefaultContent += [Microsoft.SharePoint.Client.FieldLookupValue]@{"LookupId" = $TemplateChecklist.Id }
    $TemplateLayout["ListContentConfigLookup"] = $TemplateDefaultContent

    $TemplateExtension = $ProjectExtension | Where-Object { $_["Title"] -eq $ResearchProjectExtension }
    $TemplateLayout["GtProjectExtensions"] = [Microsoft.SharePoint.Client.FieldLookupValue]@{"LookupId" = $TemplateExtension.Id }
  
    $TemplateLayout.SystemUpdate()
    $TemplateLayout.Context.ExecuteQuery()
  }
  else {
    Write-Host "[WARNING] Failed to find $ResearchProjectExtension template. Please check the $TemplateOptionsList list." -ForegroundColor Yellow
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
Connect-PnPOnline -Url $Url -ClientId $ClientId -ErrorAction Stop
$InstallationEntriesList = Get-PnPList -Identity (Get-Resource -Name "Lists_InstallationLog_Title") -ErrorAction Stop
$LastInstall = Get-PnPListItem -List $InstallationEntriesList.Id -Query "<View><Query><OrderBy><FieldRef Name='Created' Ascending='False' /></OrderBy></Query></View>" | Select-Object -First 1 -Wait
$PreviousVersion = "N/A"
if ($null -ne $LastInstall) {
  $PreviousVersion = $LastInstall.FieldValues["InstallVersion"]
}

# TODO: Replace version from package.json/git-tag
$CustomizationInfo = "Prosjektportalen Forskningsmal 1.0.1"
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

$LoggedEntry = Add-PnPListItem -List $InstallationEntriesList.Id -Values $InstallEntry -ErrorAction Continue

Stop-PnPTraceLog -StopFileLogging

Write-Host "Installation of Forskningsmalen complete!" -ForegroundColor Green