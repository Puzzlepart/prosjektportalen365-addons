Param(
    [Parameter(Mandatory = $false)]
    [string]$Url
)

function Connect-SharePoint($Url) {
    $pnpParams = @{ 
        Url = $Url
    }
    if ($null -ne $PSPrivateMetadata) {
        #azure runbook context
        $pnpParams.Add("ManagedIdentity", $true)
    }
    else {
        $pnpParams.Add("Interactive", $true)
    }

    Connect-PnPOnline @pnpParams
}

function Get-SiteUsersEmails($Url) {
    Connect-SharePoint -Url $Url
    $GroupId = Get-PnPProperty -ClientObject (Get-PnPSite) -Property "GroupId"

    $UserFieldOptions = @()

    Get-PnPMicrosoft365GroupMember -Identity $GroupId | Where-Object UserType -eq "member" | ForEach-Object {
        $UserFieldOptions += $_.UserPrincipalName
    }

    return $UserFieldOptions
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

$UsersEmails = Get-SiteUsersEmails -Url $HubSiteUrl

$Result = @{
    SiteTitle = $SiteTitle
    GroupId = $GroupId.Guid
    SiteId = $SiteId.Guid
    HubSiteUrl = $HubSiteUrl
    UsersEmails = $UsersEmails
}

ConvertTo-Json $Result