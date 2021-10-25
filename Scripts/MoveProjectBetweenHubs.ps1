Param(
    [string]$SourceHubUrl = "https://puzzlepart.sharepoint.com/sites/pp365",
    [string]$DestinationHubUrl = "https://puzzlepart.sharepoint.com/sites/pp365_578908758",
    [string]$ProjectUrl = "https://puzzlepart.sharepoint.com/sites/Lykkepillen124c"
)

function GetSPItemPropertiesValues($MatchingItem) {
    $SourceRawProperties = @{}
    foreach ($key in $MatchingItem.FieldValues.Keys) { 
        if ($key.startswith("Gt") -or $key -eq "Title" -or $key -eq "Created" -or $key -eq "Modified" -or $key -eq "Author" -or $key -eq "Editor") {
            $SourceRawProperties[$key] = $MatchingItem.FieldValues[$key]
        }
    } 
    $ProjectPropertiesValues = @{}
    foreach ($fld in $SourceRawProperties.Keys) {
            
        $SourceValue = $SourceRawProperties[$fld]
        if ($null -eq $SourceValue) { continue }
        switch ($SourceValue.GetType().ToString()) {
            "Microsoft.SharePoint.Client.Taxonomy.TaxonomyFieldValue" { 
                if ($null -ne $SourceValue.TermGuid) {
                    $ProjectPropertiesValues[$fld] = $SourceValue.TermGuid
                }
            }
            "Microsoft.SharePoint.Client.Taxonomy.TaxonomyFieldValueCollection" { 
                if ($SourceValue.Count -gt 0) {
                    $TermGuids = @()
                    $SourceValue | ForEach-Object { $TermGuids += $_.TermGuid }
                    $ProjectPropertiesValues[$fld] = $TermGuids
                }
            }
            "Microsoft.SharePoint.Client.FieldUserValue" {
                if ($SourceValue.Email -ne "") {
                    $User = New-PnPUser -LoginName $SourceValue.Email
                    if ($null -ne $User) {
                        $ProjectPropertiesValues[$fld] = $User.Email, $User.Id
                    }
                }
            }
            default {
                $ProjectPropertiesValues[$fld] = $SourceValue;
            }
        }
    }
    return $ProjectPropertiesValues
}

Function Copy-ListItemAttachments() {  
    param(  
        [Parameter(Mandatory = $true)][Microsoft.SharePoint.Client.ListItem]$SourceItem,  
        [Parameter(Mandatory = $true)][Microsoft.SharePoint.Client.ListItem]$DestinationItem
    ) 

    #Get All Attachments from Source list items  
    $Attachments = Get-PnPProperty -ClientObject $SourceItem -Property "AttachmentFiles"  
    $Attachments | ForEach-Object {  
        #Download the Attachment to Temp  
        $File = Get-PnPFile -Connection $SourceConn -Url $_.ServerRelativeUrl -FileName $_.FileName -Path $Env:TEMP -AsFile -Force  
        #Add Attachment to Destination List Item  
        $FileStream = New-Object IO.FileStream(($Env:TEMP + "\" + $_.FileName), [System.IO.FileMode]::Open)  
        $AttachmentInfo = New-Object -TypeName Microsoft.SharePoint.Client.AttachmentCreationInformation 
        $AttachmentInfo.FileName = $_.FileName 
        $AttachmentInfo.ContentStream = $FileStream 
        $AttachFile = $DestinationItem.AttachmentFiles.Add($AttachmentInfo) 
        Invoke-PnPQuery -Connection $DestinationConn 
        #Delete the Temporary File 
        Remove-Item -Path ($Env:TEMP + "\" + $_.FileName) -Force
    }
}  
$ErrorActionPreference = "Stop"

$Url = [System.Uri]$SourceHubUrl
$TenantAdminUrl = "https://" + $Url.Authority.Replace(".sharepoint.com", "-admin.sharepoint.com")

Connect-PnPOnline -Url $TenantAdminUrl -UseWebLogin

Write-Host "Changing hub association"
$SourceHub = Get-PnPHubSite -Identity $SourceHubUrl
$DestinationHub = Get-PnPHubSite -Identity $DestinationHubUrl
$DestinationHubSite = Get-PnPTenantSite -Url $DestinationHubUrl
$ProjectSite = Get-PnPTenantSite -Url $ProjectUrl

if ($null -eq $SourceHub -or $null -eq $DestinationHub -or $null -eq $SourceHub.ID -or $null -eq $DestinationHub.ID -or $null -eq $DestinationHubSite) {
    Write-Host "Cannot find source or destination hub. Aborting"
    exit 1
}

Remove-PnPHubSiteAssociation -Site $ProjectUrl
Add-PnPHubSiteAssociation -Site $ProjectUrl -HubSite $DestinationHubUrl

Connect-PnPOnline -Url $ProjectUrl -UseWebLogin
$Site = Get-PnPSite
$SiteId = (Get-PnPProperty -ClientObject $Site -Property "Id").Guid

Write-Host "Looking for relevant entries in Projects list"
Connect-PnPOnline -Url $SourceHubUrl -UseWebLogin
$MatchingItem = Get-PnPListItem -List "Prosjekter" -Query @"
<View>
    <Query>
        <Where>
            <Eq>
                <FieldRef Name='GtSiteId' /><Value Type='Text'>$SiteId</Value>
            </Eq>
        </Where>
    </Query>
</View>
"@

if ($null -ne $MatchingItem -and $MatchingItem.length -eq 1) {
    Write-Host "Copying project element from Projects list"
    $ProjectPropertiesValues = GetSPItemPropertiesValues -MatchingItem $MatchingItem
    Connect-PnPOnline -Url $DestinationHubUrl -UseWebLogin
    $NewItem = Add-PnPListItem -List "Prosjekter" -Values $ProjectPropertiesValues
    Write-Host "Successfully migrated properties for $($MatchingItem.FieldValues['Title'])" -ForegroundColor Green
}
else {
    Write-Host "Cannot find project object in source site"
}


Write-Host "Looking for relevant entries in Projects Status list"
$SourceConn = Connect-PnPOnline -Url $SourceHubUrl -UseWebLogin -ReturnConnection

$MatchingReports = Get-PnPListItem -List "Prosjektstatus" -Connection $SourceConn -Query @"
<View>
    <Query>
        <Where>
            <Eq>
                <FieldRef Name='GtSiteId' /><Value Type='Text'>$SiteId</Value>
            </Eq>
        </Where>
    </Query>
</View>
"@

$DestinationConn = Connect-PnPOnline -Url $DestinationHubUrl -UseWebLogin -ReturnConnection
if ($null -ne $MatchingReports -and $MatchingReports.length -eq 1) {
    Write-Host "Copying project status element from Projects status list"    
    $ProjectPropertiesValues = GetSPItemPropertiesValues -MatchingItem $MatchingReports    
    $NewItem = Add-PnPListItem -List "Prosjektstatus" -Values $ProjectPropertiesValues -Connection $DestinationConn
    Copy-ListItemAttachments -SourceItem $MatchingReports -DestinationItem $NewItem
    Write-Host "Successfully migrated status report $($MatchingReports.Id) for $($MatchingItem.FieldValues['Title'])" -ForegroundColor Green
}
elseif ($null -ne $MatchingReports -and $MatchingReports.length -gt 1) {
    $MatchingReports | ForEach-Object {
        $MatchingReport = $_
        Write-Host "Copying project status element from Projects status list"
        $ProjectPropertiesValues = GetSPItemPropertiesValues -MatchingItem $MatchingReport
        $NewItem = Add-PnPListItem -List "Prosjektstatus" -Values $ProjectPropertiesValues -Connection $DestinationConn
        Copy-ListItemAttachments -SourceItem $MatchingReport -DestinationItem $NewItem
        Write-Host "Successfully migrated status report $($MatchingReport.Id) for $($MatchingItem.FieldValues['Title'])" -ForegroundColor Green
    }
}
else {
    Write-Host "Cannot find project status objects in source site"
}

Write-Host "Copying complete. It is recommended to delete project properties and status reports for the project in the source site."
Write-Host "You might want to verify that the project has been copied correctly first."
do {
    $YesOrNo = Read-Host "Do you want to delete project properties and status reports for the project in the source site? (y/n)"
} 
while ("y","n" -notcontains $YesOrNo)

if ($YesOrNo -eq "y") {
    $SourceConn = Connect-PnPOnline -Url $SourceHubUrl -UseWebLogin -ReturnConnection
    if ($null -ne $MatchingItem -and $MatchingItem.length -eq 1) {
        Write-Host "Deleting project properties item with ID $($MatchingItem.Id)"
        $MatchingItem.DeleteObject()
        $MatchingItem.Update()
    }
    if ($null -ne $MatchingReports -and $MatchingReports.length -eq 1) {
        Write-Host "Deleting project status item with ID $($MatchingReports.Id)"
        $MatchingReports.DeleteObject()
        $MatchingReports.Update()
    }
    elseif ($null -ne $MatchingReports -and $MatchingReports.length -gt 1) {
        $MatchingReports | ForEach-Object {
            $MatchingReport = $_
            Write-Host "Deleting project status item with ID $($MatchingReport.Id)"
            $MatchingReport.DeleteObject()
            $MatchingReport.Update()

        }
    }
    Invoke-PnPQuery
}