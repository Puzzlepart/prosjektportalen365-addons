Param(    
    [Parameter(Mandatory = $true)][string]$SourceHubUrl,
    [Parameter(Mandatory = $true)][string]$DestinationHubUrl,
    [Parameter(Mandatory = $true)][string]$ProjectUrl,
    [Parameter(Mandatory = $false)][string]$ClientId = "da6c31a6-b557-4ac3-9994-7315da06ea3a", ## PP Client Id
    [Parameter(Mandatory = $false)][bool]$Force
)

function VerifyUser($UserObject, $Connection) {
    if ($SourceValue.Email -ne "") {
        try {
            $User = New-PnPUser -LoginName $UserObject.Email -Connection $Connection -ErrorAction SilentlyContinue
        
            if ($null -ne $User) {
                $ADUser = Get-PnPAzureADUser -Identity $UserObject.Email -Connection $Connection -ErrorAction SilentlyContinue

                if ($null -ne $ADUser -and $ADUser.AccountEnabled) {
                    return $UserObject.Email
                }
            }
        }
        catch {
            Write-Host "`t`tUser $($UserObject.Email) does not exist anymore" -ForegroundColor Yellow
            return $null
        }
    }
    Write-Host "`t`tUser $($UserObject.Email) does not exist anymore" -ForegroundColor Yellow
    return $null
}

function GetSPItemPropertiesValues($MatchingProject, $Connection) {
    $SourceRawProperties = @{}
    foreach ($key in $MatchingProject.FieldValues.Keys) { 
        if (($key.startswith("Gt") -or $key -eq "Title" -or $key -eq "Created" -or $key -eq "Modified" -or $key -eq "Author" -or $key -eq "Editor") -and ($key -ne "GtcProjectCategory")) {
            $SourceRawProperties[$key] = $MatchingProject.FieldValues[$key]
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
                $User = VerifyUser -UserObject $SourceValue
                if ($null -ne $User) {                    
                    $ProjectPropertiesValues[$fld] = $User
                }
            }
            "Microsoft.SharePoint.Client.FieldUserValue[]" {
                $VerifiedUsers = @()
                $SourceValue | ForEach-Object {
                    $User = VerifyUser -UserObject $_ -Connection $Connection
                    if ($null -ne $User) {
                        $VerifiedUsers += $User
                    }
                }
                $ProjectPropertiesValues[$fld] = $VerifiedUsers
            }
            "Microsoft.SharePoint.Client.FieldLookupValue" {
                $LookupValue = $SourceValue.LookupValue
                if ($null -ne $LookupValue) {
                    $NewLookupValue = Get-PnPListItem -List "Tidslinjekonfigurasjon" -Connection $Connection | Where-Object { $_.FieldValues['Title'] -eq $LookupValue }
                    $ProjectPropertiesValues[$fld] = $NewLookupValue.Id
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

if ($null -eq (Get-Command Set-PnPTraceLog -ErrorAction SilentlyContinue)) {
    Write-Host "You have to load the PnP.PowerShell module before running this script!" -ForegroundColor Red
    exit 0
}

$ErrorActionPreference = "Stop"
Set-PnPTraceLog -Off

$Url = [System.Uri]$ProjectUrl
$TenantAdminUrl = "https://" + $Url.Authority.Replace(".sharepoint.com", "-admin.sharepoint.com")

Connect-PnPOnline -Url $TenantAdminUrl -Interactive -ClientId $ClientId

$ProjectSite = Get-PnPTenantSite -Url $ProjectUrl
$SourceHub = Get-PnPHubSite -Identity $SourceHubUrl
$DestinationHub = Get-PnPHubSite -Identity $DestinationHubUrl

if ($null -eq $SourceHub -or $null -eq $DestinationHub -or $null -eq $SourceHub.ID -or $null -eq $DestinationHub.ID) {
    Write-Host "Cannot find source or destination hub. Aborting"
    exit 1
}

$ctx = Get-PnPContext
$ctx.Load($ctx.Web.CurrentUser)
$ctx.ExecuteQuery()
$CurrentUserEmail = $ctx.Web.CurrentUser.Email
if ($null -eq $CurrentUserEmail) {
    $CurrentUserEmail = $ctx.Web.CurrentUser.UserPrincipalName
}

if ($null -eq $CurrentUserEmail) {
    Write-Host "Cannot find current user. Aborting"
    exit 1
}

Write-Host "Setting current user as owner of project site, source hub and destination hub"
Set-PnPTenantSite -Identity $ProjectUrl -Owners $CurrentUserEmail -ErrorAction SilentlyContinue
Set-PnPTenantSite -Identity $DestinationHubUrl -Owners $CurrentUserEmail -ErrorAction SilentlyContinue
Set-PnPTenantSite -Identity $SourceHubUrl -Owners $CurrentUserEmail -ErrorAction SilentlyContinue

Write-Host "Starting to move site $($ProjectSite.Title) [$ProjectUrl]"
if ($DestinationHub.ID -ne $ProjectSite.HubSiteId) {
    Write-Host "`tChanging hub association"
    Remove-PnPHubSiteAssociation -Site $ProjectUrl
    Add-PnPHubSiteAssociation -Site $ProjectUrl -HubSite $DestinationHubUrl
}

Connect-PnPOnline -Url $ProjectUrl -Interactive -ClientId $ClientId
$Site = Get-PnPSite
$SiteId = (Get-PnPProperty -ClientObject $Site -Property "Id").Guid

Write-Host "`tLooking for relevant entries in Projects list"

$MatchingProjectCaml = @"
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

Connect-PnPOnline -Url $SourceHubUrl -Interactive -ClientId $ClientId
$MatchingProject = Get-PnPListItem -List "Prosjekter" -Query $MatchingProjectCaml

if ($null -ne $MatchingProject -and $MatchingProject.length -eq 1) {
    Write-Host "`t`tCopying project element from Projects list"
    $DestinationConn = Connect-PnPOnline -Url $DestinationHubUrl -Interactive -ReturnConnection -ClientId $ClientId
    $ProjectPropertiesValues = GetSPItemPropertiesValues -MatchingProject $MatchingProject -Connection $DestinationConn
    $MatchingDestinationProject = Get-PnPListItem -List "Prosjekter" -Query $MatchingProjectCaml -Connection $DestinationConn
    if ($null -eq $MatchingDestinationProject) {
        $NewItem = Add-PnPListItem -List "Prosjekter" -Values $ProjectPropertiesValues -Connection $DestinationConn
        Write-Host "`t`tSuccessfully added project properties" -ForegroundColor Green
    } else {
        $NewItem = Set-PnPListItem -List "Prosjekter" -Identity $MatchingDestinationProject.Id -Values $ProjectPropertiesValues -Connection $DestinationConn
        Write-Host "`t`tSuccessfully updated project properties" -ForegroundColor Green
    }
}
else {
    Write-Host "`t`tCannot find project object in source site"
}


Write-Host "`tLooking for relevant entries in Projects Status list"
$SourceConn = Connect-PnPOnline -Url $SourceHubUrl -Interactive -ReturnConnection -ClientId $ClientId

[array]$MatchingReports = Get-PnPListItem -List "Prosjektstatus" -Connection $SourceConn -Query $MatchingProjectCaml

$DestinationConn = Connect-PnPOnline -Url $DestinationHubUrl -Interactive -ReturnConnection -ClientId $ClientId
[array]$MatchingDestReports = Get-PnPListItem -List "Prosjektstatus" -Connection $DestinationConn -Query $MatchingProjectCaml
$ProjectStatusAttachmentsList = Get-PnPList -Identity "Prosjektstatusvedlegg" -Connection $DestinationConn

if ($null -ne $MatchingReports -and $MatchingReports.Length -gt 0) {
    if ($null -eq $MatchingDestReports -or $MatchingDestReports.Length -eq 0) {
        $MatchingReports | ForEach-Object {
            $MatchingReport = $_
            Write-Host "`t`tCopying project status element from Projects status list with ID: $($MatchingReport.Id)"
            $ProjectStatusValues = GetSPItemPropertiesValues -MatchingProject $MatchingReport -Connection $DestinationConn
            $NewItem = Add-PnPListItem -List "Prosjektstatus" -Values $ProjectStatusValues -Connection $DestinationConn
            Copy-ListItemAttachments -SourceItem $MatchingReport -DestinationItem $NewItem
            
            $ExistingStatusAttachment = Get-PnPFolder -Url "Prosjektstatusvedlegg/$($MatchingReport.Id)" -Connection $SourceConn -ErrorAction SilentlyContinue
            if ($null -ne $ExistingStatusAttachment) {
                Write-Host "`t`tCopying project status attachments with path Prosjektstatusvedlegg/$($MatchingReport.Id)"
                $CopyFileResult = Copy-PnPFile -SourceUrl "Prosjektstatusvedlegg/$($MatchingReport.Id)" -TargetUrl "$($ProjectStatusAttachmentsList.ParentWebUrl)/Prosjektstatusvedlegg" -Overwrite -Force -ErrorAction Continue -Connection $SourceConn
                $RenameResult = Rename-PnPFolder -Folder "Prosjektstatusvedlegg/$($MatchingReport.Id)" -TargetFolderName $NewItem.Id -Connection $DestinationConn -ErrorAction Continue                
            }
            Write-Host "`t`tSuccessfully migrated status report $($MatchingReport.Id)" -ForegroundColor Green
        }
    } else {
        Write-Host "`t`tSkipping migrating status reports as they are already present"
    }
}
else {
    Write-Host "`t`tCannot find project status objects in source site"
}

Write-Host "`tMigrating any timeline items for project"
if ($null -ne $MatchingProject -and $MatchingProject.length -eq 1) {
    $MatchingTimelineSourceItemsCaml = "@
    <View Scope='RecursiveAll'>
        <Query>
            <Where>
                <Eq>
                    <FieldRef Name='GtSiteIdLookup' LookupId='TRUE'/><Value Type='Lookup'>$($MatchingProject.Id)</Value>
                </Eq>
            </Where>
        </Query>
    </View>"

    $SourceConn = Connect-PnPOnline -Url $SourceHubUrl -Interactive -ReturnConnection -ClientId $ClientId
    [array]$TimelineItems = Get-PnPListItem -List "Tidslinjeinnhold" -Query $MatchingTimelineSourceItemsCaml -Connection $SourceConn

    $DestinationConn = Connect-PnPOnline -Url $DestinationHubUrl -Interactive -ReturnConnection -ClientId $ClientId
    $MatchingDestinationProject = Get-PnPListItem -List "Prosjekter" -Query $MatchingProjectCaml -Connection $DestinationConn
    if ($null -ne $MatchingDestinationProject -and $MatchingDestinationProject.length -eq 1) {
        $MatchingTimelineDestItemsCaml = "@
        <View Scope='RecursiveAll'>
            <Query>
                <Where>
                    <Eq>
                        <FieldRef Name='GtSiteIdLookup' LookupId='TRUE'/><Value Type='Lookup'>$($MatchingDestinationProject.Id)</Value>
                    </Eq>
                </Where>
            </Query>
        </View>"
        $MatchingDestTimelineItems = Get-PnPListItem -List "Tidslinjeinnhold" -Query $MatchingTimelineDestItemsCaml -Connection $DestinationConn
        if ($null -eq $MatchingDestTimelineItems) {
            $TimelineItems | ForEach-Object {
                $TimelineItem = GetSPItemPropertiesValues -MatchingProject $_ -Connection $DestinationConn
                $TimelineItem["GtSiteIdLookup"] = $MatchingDestinationProject.Id
                $NewItem = Add-PnPListItem -List "Tidslinjeinnhold" -Values $TimelineItem -Connection $DestinationConn
                Write-Host "`t`tSuccessfully migrated timeline item '$($TimelineItem.Title)'" -ForegroundColor Green
            }
        }
        else {
            Write-Host "`t`tSkipping migrating timeline items as they already exists in destination site"
        }
    }
}

Write-Host "`tCleaning up project data in source hub"
$SourceConn = Connect-PnPOnline -Url $SourceHubUrl -Interactive -ReturnConnection -ClientId $ClientId
if ($null -ne $MatchingProject -and $MatchingProject.length -eq 1) {
    Write-Host "`t`tDeleting project properties item with ID $($MatchingProject.Id)"
    $RemovedItem = Remove-PnPListItem -List "Prosjekter" -Identity $MatchingProject.Id -Force:$Force -Recycle -Connection $SourceConn
}
if ($null -ne $MatchingReports -and $MatchingReports.length -gt 0) {
    $MatchingReports | ForEach-Object {
        $MatchingReport = $_
        Write-Host "`t`tDeleting project status item with ID $($MatchingReport.Id)"
        $RemovedItem = Remove-PnPListItem -List "Prosjektstatus" -Identity $MatchingReport.Id -Force:$Force -Recycle -Connection $SourceConn
        $RemovedFolder = Remove-PnPFolder -Name $MatchingReport.Id -Folder "Prosjektstatusvedlegg" -Force:$Force -Recycle -Connection $SourceConn
    }
}
if ($null -ne $TimelineItems -and $TimelineItems.length -gt 0) {
    $TimelineItems | ForEach-Object {
        $TimelineItem = $_
        Write-Host "`t`tDeleting timeline item with ID $($TimelineItem.Id)"
        $RemovedItem = Remove-PnPListItem -List "Tidslinjeinnhold" -Identity $TimelineItem.Id -Force:$Force -Recycle -Connection $SourceConn
    }
}