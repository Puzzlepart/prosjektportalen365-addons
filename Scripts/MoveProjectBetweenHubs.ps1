Param(
    [string]$SourceHubUrl,
    [string]$DestinationHubUrl,
    [string]$ProjectUrl
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
                    try {
                        $User = New-PnPUser -LoginName $SourceValue.Email -ErrorAction Continue
                        
                        if ($null -ne $User) {
                            $ADUser = Get-AzureADUser -ObjectId $SourceValue.Email -ErrorAction Continue

                            if ($null -ne $ADUser -and $ADUser.AccountEnabled) {
                                $ProjectPropertiesValues[$fld] = $User.Email, $User.Id
                            }
                        }

                    }
                    catch {
                        Write-Host "`t`tUser $($SourceValue.Email) does not exist anymore" -ForegroundColor Yellow
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
Set-PnPTraceLog -Off

Start-Transcript -Path "$PSScriptRoot/MoveSites_Log-$((Get-Date).ToString('yyyy-MM-dd-HH-mm')).txt"

try { 
    $AzureADCommand = Get-AzureADTenantDetail 
} 
catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException] { 
    Write-Host "Connecting to Azure AD" 
    $AzureConnection = Connect-AzureAD 
}


$Url = [System.Uri]$SourceHubUrl
$TenantAdminUrl = "https://" + $Url.Authority.Replace(".sharepoint.com", "-admin.sharepoint.com")

Connect-PnPOnline -Url $TenantAdminUrl -Interactive

$SourceHub = Get-PnPHubSite -Identity $SourceHubUrl
$DestinationHub = Get-PnPHubSite -Identity $DestinationHubUrl
$DestinationHubSite = Get-PnPTenantSite -Url $DestinationHubUrl
$ProjectSite = Get-PnPTenantSite -Url $ProjectUrl

if ($null -eq $SourceHub -or $null -eq $DestinationHub -or $null -eq $SourceHub.ID -or $null -eq $DestinationHub.ID -or $null -eq $DestinationHubSite) {
    Write-Host "Cannot find source or destination hub. Aborting"
    exit 1
}

Write-Host "Starting to move site $($ProjectSite.Title) [$ProjectUrl]"
if ($DestinationHub.ID -ne $ProjectSite.HubSiteId) {
    Write-Host "`tChanging hub association"
    Remove-PnPHubSiteAssociation -Site $ProjectUrl
    Add-PnPHubSiteAssociation -Site $ProjectUrl -HubSite $DestinationHubUrl
}

Connect-PnPOnline -Url $ProjectUrl -Interactive
$Site = Get-PnPSite
$SiteId = (Get-PnPProperty -ClientObject $Site -Property "Id").Guid

Write-Host "`tLooking for relevant entries in Projects list"
Connect-PnPOnline -Url $SourceHubUrl -Interactive
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
    Write-Host "`t`tCopying project element from Projects list"
    $ProjectPropertiesValues = GetSPItemPropertiesValues -MatchingItem $MatchingItem
    $DestinationConn = Connect-PnPOnline -Url $DestinationHubUrl -Interactive -ReturnConnection
    $NewItem = Add-PnPListItem -List "Prosjekter" -Values $ProjectPropertiesValues -Connection $DestinationConn
    Write-Host "`t`tSuccessfully migrated properties for $($MatchingItem.FieldValues['Title'])" -ForegroundColor Green
}
else {
    Write-Host "`t`tCannot find project object in source site"
}


Write-Host "`tLooking for relevant entries in Projects Status list"
$SourceConn = Connect-PnPOnline -Url $SourceHubUrl -Interactive -ReturnConnection

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

$DestinationConn = Connect-PnPOnline -Url $DestinationHubUrl -Interactive -ReturnConnection
if ($null -ne $MatchingReports -and $MatchingReports.length -eq 1) {
    Write-Host "`t`tCopying project status element from Projects status list"    
    $ProjectStatusValues = GetSPItemPropertiesValues -MatchingItem $MatchingReports    
    $NewItem = Add-PnPListItem -List "Prosjektstatus" -Values $ProjectStatusValues -Connection $DestinationConn
    Copy-ListItemAttachments -SourceItem $MatchingReports -DestinationItem $NewItem
    Write-Host "`t`tSuccessfully migrated status report $($MatchingReports.Id) for $($MatchingItem.FieldValues['Title'])" -ForegroundColor Green
}
elseif ($null -ne $MatchingReports -and $MatchingReports.length -gt 1) {
    $MatchingReports | ForEach-Object {
        $MatchingReport = $_
        Write-Host "`t`tCopying project status element from Projects status list"
        $ProjectStatusValues = GetSPItemPropertiesValues -MatchingItem $MatchingReport
        $NewItem = Add-PnPListItem -List "Prosjektstatus" -Values $ProjectStatusValues -Connection $DestinationConn
        Copy-ListItemAttachments -SourceItem $MatchingReport -DestinationItem $NewItem
        Write-Host "`t`tSuccessfully migrated status report $($MatchingReport.Id) for $($MatchingItem.FieldValues['Title'])" -ForegroundColor Green
    }
}
else {
    Write-Host "`t`tCannot find project status objects in source site"
}

Write-Host "`tCleaning up project data in source hub"
# Deleting properties and status elements from source
$SourceConn = Connect-PnPOnline -Url $SourceHubUrl -Interactive -ReturnConnection
if ($null -ne $MatchingItem -and $MatchingItem.length -eq 1) {
    Write-Host "`t`tDeleting project properties item with ID $($MatchingItem.Id)"
    $RemovedItem = Remove-PnPListItem -List "Prosjekter" -Identity $MatchingItem.Id -Force -Recycle -Connection $SourceConn
}
if ($null -ne $MatchingReports -and $MatchingReports.length -eq 1) {
    Write-Host "`t`tDeleting project status item with ID $($MatchingReports.Id)"
    $RemovedItem = Remove-PnPListItem -List "Prosjektstatus" -Identity $MatchingReports.Id -Force -Recycle -Connection $SourceConn
}
elseif ($null -ne $MatchingReports -and $MatchingReports.length -gt 1) {
    $MatchingReports | ForEach-Object {
        $MatchingReport = $_
        Write-Host "`t`tDeleting project status item with ID $($MatchingReport.Id)"
        $RemovedItem = Remove-PnPListItem -List "Prosjektstatus" -Identity $MatchingReport.Id -Force -Recycle -Connection $SourceConn
    }
}

Disconnect-PnPOnline
#Disconnect-AzureAD
Stop-Transcript