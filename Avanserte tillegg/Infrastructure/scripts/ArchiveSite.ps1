param(
    $Url,
    $GroupId,
    $HubSiteUrl,
    $Status
)

# Get configuration from Azure Automation Variables (when running in automation) or use defaults
function Get-ConfigurationValue {
    param(
        [string]$VariableName,
        [string]$DefaultValue
    )
    
    if ($null -ne $PSPrivateMetadata) {
        # Running in Azure Automation context
        try {
            $value = Get-AutomationVariable -Name $VariableName -ErrorAction SilentlyContinue
            if ($null -ne $value) {
                return $value
            }
        }
        catch {
            Write-Output "Warning: Could not get automation variable '$VariableName', using default value"
        }
    }
    return $DefaultValue
}

# Set default status if not provided
if (-not $Status) {
    $Status = Get-ConfigurationValue -VariableName 'ArchiveStatusName' -DefaultValue 'Avsluttet'
}

function Connect-SharePoint($Url) {
    $pnpParams = @{ 
        Url = $Url
        ErrorAction = "Stop"
        WarningAction = "Ignore"
    }
    if ($null -ne $PSPrivateMetadata) {
        #azure runbook context
        $pnpParams.Add("ManagedIdentity", $true)
    }
    else {
        $pnpParams.Add("UseWebLogin", $true)
        #$pnpParams.Add("ClientId", $global:__ClientId)
    }

    Connect-PnPOnline @pnpParams
}

function Set-SiteArchivedBanner($Url, [switch]$Disable) {
    Connect-SharePoint -Url $Url
    
    $bannerText = Get-ConfigurationValue -VariableName 'ArchiveBannerText' -DefaultValue 'Dette området er arkivert og skrivebeskyttet. Er det behov for å åpne det igjen, send epost til brukerstøtte'
    
    if (-not $Disable.IsPresent) {
        Write-Output "`tAdding archive banner to site $Url"
        #Remove-PnPCustomAction -Identity "CustomArchiveBanner" -Scope Site -Force -ErrorAction SilentlyContinue
        #$CustomAction = Add-PnPCustomAction -Title "CustomArchiveBanner" -Name "CustomArchiveBanner" -Location "ClientSideExtension.ApplicationCustomizer" -ClientSideComponentId "1e2688c4-99d8-4897-8871-a9c151ccfc87" -ClientSideComponentProperties "{`"message`":`"$bannerText`",`"textColor`":`"`#000000`",`"backgroundColor`":`"`#ffd9b3`",`"textFontSizePx`":16,`"bannerHeightPx`":42,`"visibleStartDate`":null,`"enableSetPreAllocatedTopHeight`":false,`"disableSiteAdminUI`":true}" -Scope Site
    } else {
        Write-Output "`tRemoving archive banner from site $Url"
        #Remove-PnPCustomAction -Identity "CustomArchiveBanner" -Scope Site -Force -ErrorAction SilentlyContinue
    }
}

function Set-ProjectLifecycleStatus($Url, $Status) {
    Write-Output "`tSetting project lifecycle status to $Status for project $Url"
    Connect-SharePoint -Url $Url
    
    $ProjectProperties = Get-PnPListItem -List "Prosjektegenskaper" -Id 1 -ErrorAction SilentlyContinue
    if ($null -eq $ProjectProperties) {
        Write-Output "`tFailed to get project properties, unable to update status"
    }
     else {
        Write-Output "`t`tUpdating project properties with status $Status (previous status was $($ProjectProperties.FieldValues.GtProjectLifecycleStatus)))"
        $Output = Set-PnPListItem -List "Prosjektegenskaper" -Identity 1 -Values @{"GtProjectLifecycleStatus" = $Status} -UpdateType SystemUpdate -ErrorAction Continue
     }
}

function Set-ProjectLifecycleStatusHubLevel($Url, $Status, $HubSiteUrl) {
    Write-Output "`tSetting project lifecycle status to $Status for project $Url in hub site $HubSiteUrl"
    $IsArchived = $false
    if ($Status -eq $archiveStatusName) {
        $IsArchived = $true
    }
    Connect-SharePoint -Url $HubSiteUrl
    $MatchingProjectInHub = Get-PnPListItem -List "Prosjekter" -Query "<View><Query><Where><Eq><FieldRef Name='GtSiteUrl' /><Value Type='Text'>$Url</Value></Eq></Where></Query></View>" -ErrorAction SilentlyContinue

    if ($null -ne $MatchingProjectInHub) {
        $Output = Set-PnPListItem -List "Prosjekter" -Identity $MatchingProjectInHub -Values @{"GtProjectLifecycleStatus" = $Status; "GtIsArchived" = $IsArchived} -UpdateType SystemUpdate -ErrorAction Continue
    }
    else {
        Write-Output "`tFailed to update project list item in hub with project data - no matching project found"
    }
}

$global:__ClientId = "da6c31a6-b557-4ac3-9994-7315da06ea3a"

Write-Output "Processing $Url with status $Status"
$ProjectUri = [System.Uri]$Url
$TenantAdminUrl = "https://" + $ProjectUri.Authority.Replace(".sharepoint.com", "-admin.sharepoint.com")

Connect-SharePoint -Url $TenantAdminUrl
$TenantSite = Get-PnPTenantSite -Url $Url
$CurrentLockState = $TenantSite.LockState

$archiveStatusName = Get-ConfigurationValue -VariableName 'ArchiveStatusName' -DefaultValue 'Avsluttet'

if ($Status -eq $archiveStatusName -and $CurrentLockState -ne "ReadOnly") {
    Set-ProjectLifecycleStatus -Url $Url -Status $Status
    Set-ProjectLifecycleStatusHubLevel -Url $Url -Status $Status -HubSiteUrl $HubSiteUrl
    Set-SiteArchivedBanner -Url $Url
    Write-Output "`tSetting site $Url LockState to ReadOnly"
    Set-PnPTenantSite -Identity $Url -LockState ReadOnly

    try {
        $team = Get-PnPTeamsTeam -Identity $GroupId -ErrorAction SilentlyContinue
        if ($null -ne $team) {
            Write-Output "`tArchiving team $GroupId"
            Set-PnPTeamsTeamArchivedState -Identity $team -Archived:$true
        } else {
            Write-Output "`tNo team to archive"
        }
    } catch {
        Write-Output "`tFailed to archive team $GroupId"
    }
} elseif ($Status -eq $archiveStatusName -and $CurrentLockState -eq "ReadOnly") {
    Write-Output "`tCurrent lock state is ReadOnly, skipping"
} else {
    if ($CurrentLockState -eq "ReadOnly") {
        Write-Output "`tSetting site $Url LockState to Unlock"
        Set-PnPTenantSite -Identity $Url -LockState Unlock
        Start-Sleep -Seconds 60
    }
    try {
        $team = Get-PnPTeamsTeam -Identity $GroupId -ErrorAction SilentlyContinue
        if ($null -ne $team) {
            Write-Output "`tUnarchiving team $GroupId"
            Set-PnPTeamsTeamArchivedState -Identity $team -Archived:$false
        } else {
            Write-Output "`tNo team to unarchive"
        }
    } catch {
        Write-Output "`tFailed to unarchive team $GroupId"
    }
    Set-PnPTenantSite -Identity $Url -Owners $UserName
    Set-ProjectLifecycleStatus -Url $Url -Status $Status
    Set-ProjectLifecycleStatusHubLevel -Url $Url -Status $Status -HubSiteUrl $HubSiteUrl
    Set-SiteArchivedBanner -Url $Url -Disable
}
