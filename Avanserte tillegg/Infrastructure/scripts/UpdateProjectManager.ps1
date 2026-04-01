param (
    [Parameter(Mandatory = $true)]
    [string]
    $Url,
    [Parameter(Mandatory = $true)]
    [string]
    $HubSiteUrl
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

# Get default manager role
$defaultManagerRole = Get-ConfigurationValue -VariableName 'DefaultManagerRole' -DefaultValue 'Full Kontroll'
function Connect-SharePoint($Url) {
    $pnpParams = @{ 
        Url           = $Url
        ErrorAction   = "Stop"
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

$global:__ClientId = "da6c31a6-b557-4ac3-9994-7315da06ea3a"

Connect-SharePoint -Url $Url

$ProjectProperties = Get-PnPListItem -List "Prosjektegenskaper" -Id 1 -ErrorAction SilentlyContinue

if ($null -eq $ProjectProperties) {
    Write-Output "Prosjektegenskaper not found"
    exit
}

$CurrentPhase = $ProjectProperties.FieldValues["GtProjectPhase"]
$PMPlan = $ProjectProperties.FieldValues["GtVeiPlanningManager"]
$PMBygger = $ProjectProperties.FieldValues["GtVeiProjectingManager"]

function BreakInheritanceAndSetPermissions($UserEmail) {
    $DocLib = Get-PnPList -Identity "Dokumenter" -ErrorAction SilentlyContinue
    if ($null -eq $DocLib) {
        Write-Output "Could not find Document library to break inheritance and update permissions"
        return
    }

    $FolderPaths = @(
        "Delte dokumenter/2 Byggeplanfase/20 Konkuransegrunnlag og kontrahering/Kontrahering",
        "Delte dokumenter/2 Byggeplanfase/10 Byggeplanlegging/Anskaffelser/Tilbud",
        "Delte dokumenter/2 Byggeplanfase/10 Byggeplanlegging/Anskaffelser/Kontrakter",
        "Delte dokumenter/1 Planfase/20 Prosjektledelse/Anskaffelser/Tilbud",
        "Delte dokumenter/1 Planfase/20 Prosjektledelse/Anskaffelser/Kontrakter"
    )

    foreach ($FolderPath in $FolderPaths) {
        $Folder = Get-PnPFolder -Url $FolderPath -ErrorAction SilentlyContinue
        if ($null -ne $Folder) {
            # Check if inheritance is already broken
            $FolderItem = Get-PnPProperty -ClientObject $Folder -Property ListItemAllFields
            $HasUniquePermissions = Get-PnPProperty -ClientObject $FolderItem -Property HasUniqueRoleAssignments
            
            $FolderName = $FolderPath.Split('/')[-1]
            
            if (-not $HasUniquePermissions) {
                Write-Output "Breaking permission inheritance for folder '$FolderName' at path: $FolderPath"
                # Break inheritance and give the project manager the configured permission level (clears inherited permissions)
                Set-PnPListItemPermission -List $DocLib -Identity $Folder.ListItemAllFields.Id -User $UserEmail -AddRole $defaultManagerRole -ClearExisting -SystemUpdate
            }
            else {
                Write-Output "Folder '$FolderName' already has unique permissions - ensuring project manager has access"
                # Ensure the project manager has access without clearing existing manually added permissions
                Set-PnPListItemPermission -List $DocLib -Identity $Folder.ListItemAllFields.Id -User $UserEmail -AddRole $defaultManagerRole -SystemUpdate
            }
        }
        else {
            Write-Output "Could not find folder at path: $FolderPath"
        }
    }
}

Write-Output "Processing phase change to the '$($CurrentPhase.Label)' phase"
if ($CurrentPhase -and $CurrentPhase.Label -eq "Planfase") {
    if ($PMPlan -and $PMPlan.Email -ne "") {
        Write-Output "Setting Project Manager to $($PMPlan.Email) from GtVeiPlanningManager"
        $Values = @{"GtProjectManager" = $PMPlan.Email }
        # Break inheritance and set permissions for planning manager
        BreakInheritanceAndSetPermissions -UserEmail $PMPlan.Email
    }
    else {
        Write-Output "Cannot find user/email for GtVeiPlanningManager. Nothing to update."
    }
}
else {
    if ($PMBygger -and $PMBygger.Email -ne "") {
        Write-Output "Setting Project Manager to $($PMBygger.Email) from GtVeiProjectingManager"
        $Values = @{"GtProjectManager" = $PMBygger.Email }
        # Break inheritance and set permissions for building/project manager
        BreakInheritanceAndSetPermissions -UserEmail $PMBygger.Email
    }
    else {
        Write-Output "Cannot find user/email for GtVeiProjectingManager. Nothing to update."
    }
}



if ($null -ne $Values) {
    
    $Output = Set-PnPListItem -List "Prosjektegenskaper" -Identity 1 -Values $Values -UpdateType SystemUpdate

    Connect-SharePoint -Url $HubSiteUrl
    $MatchingProjectInHub = Get-PnPListItem -List "Prosjekter" -Query "<View><Query><Where><Eq><FieldRef Name='GtSiteUrl' /><Value Type='Text'>$Url</Value></Eq></Where></Query></View>" -ErrorAction SilentlyContinue
    
    if ($null -ne $MatchingProjectInHub) {
        Write-Output "Updating project list item in hub with project manager data"
        $Output = Set-PnPListItem -List "Prosjekter" -Identity $MatchingProjectInHub -Values $Values -UpdateType SystemUpdate -ErrorAction Continue
    }
    else {
        Write-Output "`tFailed to update project list item in hub with project data - no matching project found"
    }
}
