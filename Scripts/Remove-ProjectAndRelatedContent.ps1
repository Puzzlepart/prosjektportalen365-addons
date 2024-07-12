[CmdletBinding()]
Param(    
    [Parameter(Mandatory = $false)]
    [string]$ProjectUrl = "https://prosjektportalen.sharepoint.com/sites/Amatrenesinntogsmarsj",
    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

# This script removes a project and all related content from the hub site. This includes (in order of removal):
# - All items in the Tidslinjeinnhold list referencing the project
# - All items in the Prosjektstatus list referencing the project
# - The Microsoft 365 group and site
# - The project entry in the Prosjekter list (there may be multiple)


# *** Config ***

$pnpParams = @{
    ReturnConnection = $true
}

if($null -ne $PSPrivateMetadata){ #azure runbook context
    Write-Output "In Azure Runbook context. Using Managed Identity"
    $pnpParams.Add("ManagedIdentity",$true)
} else {
    Write-Output "In local context. Using interactive login"
    $pnpParams.Add("Interactive",$true)
}

$connections = @{
    ProjectSite = $null
    HubSite = $null
}

$filter = @{
    whereProjectSiteId = @"
<View>
    <Query>
        <Where>
            <Eq>
                <FieldRef Name='GtSiteId' /><Value Type='Text'>{0}</Value>
            </Eq>
        </Where>
    </Query>
</View>
"@ 
    whereProjectItemLookup = "@
    <View Scope='RecursiveAll'>
        <Query>
            <Where>
                <Eq>
                    <FieldRef Name='GtSiteIdLookup' LookupId='TRUE'/><Value Type='Lookup'>{0}</Value>
                </Eq>
            </Where>
        </Query>
    </View>"

}

# *** Functions ***
function Remove-ListItems {
    param (
        [Parameter(Mandatory = $true)]
        [System.Object[]]$ListItems,
        [Parameter(Mandatory = $false)]
        [string]$ListName,
        [Parameter(Mandatory = $true)]
        $Connection
    )
    Write-Host "Removing $($ListItems.Count) items from $ListName"
    # Create a new batch
    $batch = New-PnPBatch -Connection $Connection

    # Add delete commands to the batch
    foreach ($item in $ListItems) {
        Write-Host "`tRemoving item:     ID:$($item.Id)  Title: $($item["Title"])"
        if($DryRun){
            continue
        }
        Remove-PnPListItem -List $ListName -Identity $item.Id -Connection $Connection -Batch $batch
    }

    # Execute the batch
    Invoke-PnPBatch -Batch $batch -Connection $Connection
}

function Initialize-Connections {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ProjectUrl,
        [Parameter(Mandatory = $true)]
        $pnpParams,
        [Parameter(Mandatory = $true)]
        $connections
    )

    # reconnecting and stuffing the connection in our $connections master object
    $connections.ProjectSite = Connect-PnPOnline -Url $ProjectUrl @pnpParams
    $projectSite = Get-PnPSite -Connection $connections.ProjectSite -Includes HubSiteId,Id,GroupId

    $hubSiteUrl = $(Get-PnPHubSite -Identity ([string]$projectSite.HubSiteId) -Connection $connections.ProjectSite).SiteUrl
    # stuffing the hubsite connection in our $connections master object. Reusing auth from project site, assming same credentials
    $connections.HubSite = Connect-PnPOnline -Url $hubSiteUrl -Connection $connections.ProjectSite @pnpParams
}

# *** Main ***

if($DryRun) {
    Write-Host "Running in dry-run mode. No changes will be made" -ForegroundColor Yellow
}

Initialize-Connections -ProjectUrl $ProjectUrl -pnpParams $pnpParams -connections $connections
$projectSite = $connections.ProjectSite.Context.Site

# We may in some cases have multiple projects with the same site id. This is an error condition, but needs to be handled
$projectListItems = @(Get-PnPListItem -List "Prosjekter" -Query ($filter.whereProjectSiteId -f [string]$projectSite.Id) -Connection $connections.HubSite)

$projectListItems | ForEach-Object {
    $projectListItem = $_

    $tidslinjeItems = @(Get-PnPListItem -List "Tidslinjeinnhold" -Query ($filter.whereProjectItemLookup -f $projectListItem.Id) -Connection $connections.HubSite)
    if ($tidslinjeItems.Count -gt 0) {
        Remove-ListItems -ListItems $tidslinjeItems -ListName "Tidslinjeinnhold" -Connection $connections.HubSite
    }

    $statusrapportItems = @(Get-PnPListItem -List "Prosjektstatus" -Query ($filter.whereProjectSiteId -f [string]$projectSite.Id) -Connection $connections.HubSite)
    if($statusrapportItems.Count -gt 0){
        Remove-ListItems -ListItems $statusrapportItems -ListName "Prosjektstatus" -Connection $connections.HubSite
    }
}

Write-Host "Removing Microsoft 365 group, including site: $($projectSite.Url)"
if(-not $DryRun){
    Out-Null | Get-PnPProperty -ClientObject $projectSite -Property GroupId -Connection $connections.ProjectSite #make sure we get the group id, as it is not always included even when requested
    Remove-PnPMicrosoft365Group -Identity $projectSite.GroupId -Connection $connections.HubSite
}

Write-Host "Removing entries in Prosjekter list"
Remove-ListItems -ListItems $projectListItems -ListName "Prosjekter" -Connection $connections.HubSite

Write-Host "Done!"