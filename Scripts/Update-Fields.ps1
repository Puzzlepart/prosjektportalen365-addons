Param(
    [Parameter(Mandatory = $true)]
    [string]$HubSiteUrl,
    [Parameter(Mandatory = $true)]
    [string[]]$Fields,
    [Parameter(Mandatory = $false)]
    [string]$ProjectSiteUrl,
    [Parameter(Mandatory = $false)]
    [string]$ClientId
)

$FieldsSchemas = @{}

Write-Host "Connecting to $HubSiteUrl"
if (Get-Command Connect-SharePoint -ErrorAction SilentlyContinue) {
    Connect-SharePoint -Url $HubSiteUrl
}
else {
    Connect-PnPOnline -Url $HubSiteUrl -ClientId $ClientId -Interactive
}

Write-Host "Getting field schemas for $($Fields -join ', ')"

foreach ($Field in $Fields) {
    $SchemaXml = Get-PnPField -Identity $Field | Select-Object -ExpandProperty SchemaXml
    $FieldsSchemas[$Field] = $SchemaXml
}

$FieldsSchemas | ConvertTo-Json | Out-File "FieldsSchemas.json"


function UpdateFields {
    Param(
        [string]$Url
    )
    if (Get-Command Connect-SharePoint -ErrorAction SilentlyContinue) {
        Connect-SharePoint -Url $Url
    }
    else {
        Connect-PnPOnline -Url $Url -ClientId $ClientId -Interactive
    }
    foreach ($Field in $Fields) {
        Write-Host "Updating field $Field in $Url"
        $SchemaXml = $FieldsSchemas[$Field]
        $FieldInstance = Get-PnPField -Identity $Field
        $FieldInstance.SchemaXml = $SchemaXml
        $FieldInstance.UpdateAndPushChanges($true)
        $FieldInstance.Context.ExecuteQuery()
    }
}

if ($ProjectSiteUrl) {
    Disconnect-PnPOnline
    Write-Host "Parameter ProjectSiteUrl is set, connecting to $ProjectSiteUrl"
    UpdateFields -Url $ProjectSiteUrl
} else {
    Write-Host "ProjectSiteUrl is not set, retrieving all sites in hub"
    $Sites = Get-PnPHubSiteChild 
    foreach ($SiteUrl in $Sites) {
        UpdateFields -Url $SiteUrl
    }
}