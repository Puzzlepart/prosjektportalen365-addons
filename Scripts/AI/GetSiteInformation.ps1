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

Connect-SharePoint -Url $Url

$Site = Get-PnPSite
$GroupId = Get-PnPProperty -ClientObject $Site -Property "GroupId"
$SiteId = Get-PnPProperty -ClientObject $Site -Property "Id"
$HubSiteDataRaw = Invoke-PnPSPRestMethod -Url '/_api/web/HubSiteData'
$HubSiteData = ConvertFrom-Json $HubSiteDataRaw.value
$HubSiteUrl = $HubSiteData.url

$Web = Get-PnPWeb
$SiteTitle = $Web.Title

Connect-SharePoint -Url $HubSiteUrl
$HubSite = Get-PnPSite
$GroupId = Get-PnPProperty -ClientObject $HubSite -Property "GroupId"


$HubUri = [System.Uri]$HubSiteUrl
$TenantAdminUrl = "https://" + $HubUri.Authority.Replace(".sharepoint.com", "-admin.sharepoint.com")

Connect-SharePoint -Url $TenantAdminUrl
$UsersEmails = @()
$HubMembers = Get-PnPMicrosoft365GroupMember -Identity $GroupId | Where-Object UserType -eq "member"
$HubMembers | ForEach-Object {
    $UsersEmails += $_.UserPrincipalName
}
if ($UsersEmails.Length -eq 0) {
    $UsersEmails += "admin@prosjektportalen.onmicrosoft.com"
}

$Result = @{
    SiteTitle = $SiteTitle
    GroupId = $GroupId.Guid
    SiteId = $SiteId.Guid
    HubSiteUrl = $HubSiteUrl
    UsersEmails = $UsersEmails
}

ConvertTo-Json $Result