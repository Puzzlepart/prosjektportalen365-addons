Param(
    [Parameter(Mandatory = $false)]
    [string]$Url
)
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

Connect-SharePoint -Url $Url

$Site = Get-PnPSite
$GroupId = Get-PnPProperty -ClientObject $Site -Property "GroupId"
$SiteId = Get-PnPProperty -ClientObject $Site -Property "Id"
$HubSiteDataRaw = Invoke-PnPSPRestMethod -Url '/_api/web/HubSiteData'
$HubSiteData = ConvertFrom-Json $HubSiteDataRaw.value
$HubSiteUrl = $HubSiteData.url

$Web = Get-PnPWeb
$SiteTitle = $Web.Title


$PhaseLabel = "N/A"
$ProjectProperties = Get-PnPListItem -List "Prosjektegenskaper" -Id 1 -ErrorAction SilentlyContinue
if ($null -ne $ProjectProperties) {
    $CurrentPhase = $ProjectProperties.FieldValues["GtProjectPhase"]
    if ($CurrentPhase -and $CurrentPhase.Label -ne "") {
        $PhaseLabel = $CurrentPhase.Label
    }
}

$Result = @{
    SiteTitle = $SiteTitle
    GroupId = $GroupId.Guid
    SiteId = $SiteId.Guid
    HubSiteUrl = $HubSiteUrl
    Phase = $PhaseLabel
}

ConvertTo-Json $Result