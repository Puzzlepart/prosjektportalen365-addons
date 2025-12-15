Param(
    [Parameter(Mandatory = $false)][string]$HubUrl,# = "https://prosjektportalen.sharepoint.com/sites/pp365",
    [Parameter(Mandatory = $false)][string]$ClientId = "da6c31a6-b557-4ac3-9994-7315da06ea3a" ## PP Client Id
)

class AggregatedBenefitValue {
    [string]$GtcUniqueKey
    [string]$GtcProjectName
    [string]$GtcProjectUrl
    [string]$GtcChangeTitle
    [string]$GtProcess
    [string]$GtChallengeDescription
    [string]$GtcBenefitTitle
    [string]$GtGainsType
    [string]$GtPrereqProfitAchievement
    [string]$GtGainsTurnover
    [string]$GtGainsResponsible
    [string]$GtGainsOwner
    [string]$GtRealizationTime
    [string]$GtcMeasurementIndicator
    [string]$GtStartValue
    [string]$GtDesiredValue
    [string]$GtMeasurementUnit
    [string]$GtMeasurementDate
    [string]$GtMeasurementValue
    [string]$GtMeasurementComment
    [string]$GtcGoalAchievement
}

function Connect-SharePoint($Url) {
    $pnpParams = @{ 
        Url = $Url
    }
    if ($null -ne $PSPrivateMetadata) {
        #azure runbook context
        $pnpParams.Add("ManagedIdentity", $true)
    }
    else {
        $pnpParams.Add("ClientId", $global:__ClientId)
    }

    Connect-PnPOnline @pnpParams
}

function Calculate-Achievement($StartValue, $DesiredValue, $MeasurementValue, $FractionDigits = 2) {
    if ([string]::IsNullOrEmpty($StartValue) -or [string]::IsNullOrEmpty($DesiredValue) -or [string]::IsNullOrEmpty($MeasurementValue)) {
        return $null
    }
    
    try {
        $startVal = [double]$StartValue
        $desiredVal = [double]$DesiredValue
        $measurementVal = [double]$MeasurementValue
        
        # Avoid division by zero
        if ($desiredVal -eq $startVal) {
            return $null
        }
        
        $achievement = (($measurementVal - $startVal) / ($desiredVal - $startVal))

        return $achievement
    }
    catch {
        Write-Warning "Failed to calculate achievement for StartValue: $StartValue, DesiredValue: $DesiredValue, MeasurementValue: $MeasurementValue. Error: $($_.Exception.Message)"
        return $null
    }
}
function EnsureBenefitsListExists($Url, $UniqueKeyFieldXml) {
    $BenefitsListName = "Gevinstoversikt"
    $BenefitsList = Get-PnPList -Identity $BenefitsListName -ErrorAction SilentlyContinue
    if ($null -eq $BenefitsList) {
        Write-Output "Creating '$BenefitsListName' list in hub site $Url"
        $NewList = New-PnPList -Title $BenefitsListName -Template GenericList -EnableVersioning

        $NewField = Add-PnPFieldFromXml -List $BenefitsListName -FieldXml $UniqueKeyFieldXml
        $NewField = Add-PnPField -List $BenefitsListName -DisplayName "Prosjektnavn" -InternalName "GtcProjectName" -Type Text
        $NewField = Add-PnPField -List $BenefitsListName -DisplayName "Prosjekt-URL" -InternalName "GtcProjectUrl" -Type Text
        $NewField = Add-PnPField -List $BenefitsListName -DisplayName "Endring" -InternalName "GtcChangeTitle" -Type Text
        $NewField = Add-PnPField -List $BenefitsListName -DisplayName "Gevinst" -InternalName "GtcBenefitTitle" -Type Text
        $NewField = Add-PnPField -List $BenefitsListName -DisplayName "Måleindikator" -InternalName "GtcMeasurementIndicator" -Type Text
        $NewField = Add-PnPField -List $BenefitsListName -DisplayName "Måloppnåelse" -InternalName "GtcGoalAchievement" -Type Number

        $FieldsToAdd = @(
            "GtProcess", # Endringsprosess
            "GtChallengeDescription", # Beskrivelse av utfordring
            "GtGainsType", # Type gevinst
            "GtPrereqProfitAchievement", # Forutsetning for gevinstrealisering
            "GtGainsTurnover", # Omsetning
            "GtGainsResponsible", # Ansvarlig for gevinst
            "GtGainsOwner", # Eier av gevinst
            "GtRealizationTime", # Tidslinje for gevinstrealisering
            "GtStartValue", # Startverdi
            "GtDesiredValue", # Ønsket verdi
            "GtMeasurementUnit", # Måleenhet
            "GtMeasurementDate", # Måledato
            "GtMeasurementValue", # Måleverdi
            "GtMeasurementComment" # Målkommentar
        )
        
        foreach ($field in $FieldsToAdd) {
            $AddedField = Add-PnPField -List $BenefitsListName -Field $field
        }

        $NewView = Add-PnPView -List $BenefitsListName -Title "Alle gevinster" -Fields @("GtcProjectName", "GtcChangeTitle", "GtcBenefitTitle", "GtGainsType", "GtcMeasurementIndicator", "GtStartValue", "GtDesiredValue", "GtMeasurementUnit", "GtMeasurementValue", "GtcGoalAchievement") -RowLimit 500 -Paged -Aggregations "GtMeasurementValue" -SetAsDefault
    }
}

function Aggregate-BenefitsToHub($ProjectName, $ProjectUrl, $HubUrl) {
    $BenefitsAggregationItems = @()
    
    try {        
        # Get the current site ID for the unique key
        $CurrentSite = Get-PnPSite -Includes Id
        $SiteId = $CurrentSite.Id.ToString()
    }
    catch {
        Write-Warning "Failed to get Site ID for project site $ProjectUrl. Skipping aggregation."
        return @()
    }

    # Check if required lists exist before processing
    $RequiredLists = @("Endringsanalyse", "Gevinstanalyse og gevinstrealiseringsplan", "Måleindikatorer", "Gevinstoppfølging")
    
    foreach ($listName in $RequiredLists) {
        if ($null -eq (Get-PnPList -Identity $listName -ErrorAction SilentlyContinue)) {
            Write-Warning "Skipping site '$ProjectUrl' - Missing list: $listName"
            return @()
        }
    }
    
    $Endringer = Get-PnPListItem -List "Endringsanalyse" -PageSize 500 -Fields "Id", "Title", "GtProcess", "GtChallengeDescription"
    $Gevinster = Get-PnPListItem -List "Gevinstanalyse og gevinstrealiseringsplan" -PageSize 500 -Fields "Id", "Title", "GtChangeLookup", "GtGainsType", "GtPrereqProfitAchievement", "GtGainsTurnover", "GtGainsResponsible", "GtGainsOwner", "GtRealizationTime"
    $MeasurementIndicators = Get-PnPListItem -List "Måleindikatorer" -PageSize 500 -Fields "Id", "Title", "GtGainLookup", "GtStartValue", "GtDesiredValue", "GtMeasurementUnit"
    $Gevinstfollowups = Get-PnPListItem -List "Gevinstoppfølging" -PageSize 500 -Fields "Id", "Title", "Modified", "GtMeasureIndicatorLookup", "GtMeasurementDate", "GtMeasurementValue", "GtMeasurementComment"

    # Create a hashtable to store the most recent followup for each measurement indicator
    $MostRecentFollowups = @{}
    foreach ($followup in $Gevinstfollowups) {
        $measurementIndicatorId = $followup.FieldValues["GtMeasureIndicatorLookup"]
        if ($measurementIndicatorId) {
            $indicatorId = $measurementIndicatorId.LookupId
            if (-not $MostRecentFollowups.ContainsKey($indicatorId) -or 
                $followup.FieldValues["Modified"] -gt $MostRecentFollowups[$indicatorId].FieldValues["Modified"]) {
                $MostRecentFollowups[$indicatorId] = $followup
            }
        }
    }

    # Helper function to process benefits with optional change information
    function Get-BenefitItems($gevinst, $endring = $null) {
        $results = @()
        # Get all measurement indicators for this benefit
        $relatedIndicators = $MeasurementIndicators | Where-Object { 
            $_.FieldValues["GtGainLookup"] -and 
            $_.FieldValues["GtGainLookup"].LookupId -eq $gevinst.Id 
        }
        
        $changeId = if ($endring) { $endring.Id } else { "0" }
        
        if ($relatedIndicators.Count -eq 0) {
            # No measurement indicators for this benefit, but we still include it
            $benefitItem = [AggregatedBenefitValue]::new()
            $benefitItem.GtcUniqueKey = "$SiteId-$changeId-$($gevinst.Id)-0-0"
            $benefitItem.GtcProjectName = $ProjectName
            $benefitItem.GtcProjectUrl = $ProjectUrl
            if ($endring) {
                $benefitItem.GtcChangeTitle = $endring.FieldValues["Title"]
                $benefitItem.GtProcess = $endring.FieldValues["GtProcess"]
                $benefitItem.GtChallengeDescription = $endring.FieldValues["GtChallengeDescription"]
            }
            $benefitItem.GtcBenefitTitle = $gevinst.FieldValues["Title"]
            $benefitItem.GtGainsType = $gevinst.FieldValues["GtGainsType"]
            $benefitItem.GtPrereqProfitAchievement = $gevinst.FieldValues["GtPrereqProfitAchievement"]
            $benefitItem.GtGainsTurnover = $gevinst.FieldValues["GtGainsTurnover"]
            $benefitItem.GtGainsResponsible = if ($gevinst.FieldValues["GtGainsResponsible"]) { $gevinst.FieldValues["GtGainsResponsible"].Email } else { $null }
            $benefitItem.GtGainsOwner = if ($gevinst.FieldValues["GtGainsOwner"]) { $gevinst.FieldValues["GtGainsOwner"].Email } else { $null }
            if ($gevinst.FieldValues["GtRealizationTime"] -and -not [string]::IsNullOrEmpty($gevinst.FieldValues["GtRealizationTime"])) { 
                $benefitItem.GtRealizationTime = ([datetime]$gevinst.FieldValues["GtRealizationTime"]).ToString("yyyy-MM-ddTHH:mm:ssZ")
            }
            $benefitItem.GtcGoalAchievement = $null # No measurement indicators, so no achievement calculation possible
            $results += $benefitItem
        }
        else {
            # Process each measurement indicator for this benefit
            foreach ($indicator in $relatedIndicators) {
                $benefitItem = [AggregatedBenefitValue]::new()
                
                # Build unique key - check if there's a followup for this measurement indicator
                $followupId = "0"
                if ($MostRecentFollowups.ContainsKey($indicator.Id)) {
                    $followupId = $MostRecentFollowups[$indicator.Id].Id
                }
                $benefitItem.GtcUniqueKey = "$SiteId-$changeId-$($gevinst.Id)-$($indicator.Id)-$followupId"
                
                $benefitItem.GtcProjectName = $ProjectName
                $benefitItem.GtcProjectUrl = $ProjectUrl
                if ($endring) {
                    $benefitItem.GtcChangeTitle = $endring.FieldValues["Title"]
                    $benefitItem.GtProcess = $endring.FieldValues["GtProcess"]
                    $benefitItem.GtChallengeDescription = $endring.FieldValues["GtChallengeDescription"]
                }
                $benefitItem.GtcBenefitTitle = $gevinst.FieldValues["Title"]
                $benefitItem.GtGainsType = $gevinst.FieldValues["GtGainsType"]
                $benefitItem.GtPrereqProfitAchievement = $gevinst.FieldValues["GtPrereqProfitAchievement"]
                $benefitItem.GtGainsTurnover = $gevinst.FieldValues["GtGainsTurnover"]
                $benefitItem.GtGainsResponsible = if ($gevinst.FieldValues["GtGainsResponsible"]) { $gevinst.FieldValues["GtGainsResponsible"].Email } else { $null }
                $benefitItem.GtGainsOwner = if ($gevinst.FieldValues["GtGainsOwner"]) { $gevinst.FieldValues["GtGainsOwner"].Email } else { $null }
                if ($gevinst.FieldValues["GtRealizationTime"] -and -not [string]::IsNullOrEmpty($gevinst.FieldValues["GtRealizationTime"])) { 
                    $benefitItem.GtRealizationTime = ([datetime]$gevinst.FieldValues["GtRealizationTime"]).ToString("yyyy-MM-ddTHH:mm:ssZ")
                }
                $benefitItem.GtcMeasurementIndicator = $indicator.FieldValues["Title"]
                $benefitItem.GtStartValue = $indicator.FieldValues["GtStartValue"]
                $benefitItem.GtDesiredValue = $indicator.FieldValues["GtDesiredValue"]
                $benefitItem.GtMeasurementUnit = $indicator.FieldValues["GtMeasurementUnit"]
                
                # Check if there's a most recent followup for this measurement indicator
                if ($MostRecentFollowups.ContainsKey($indicator.Id)) {
                    $mostRecentFollowup = $MostRecentFollowups[$indicator.Id]
                    if ($mostRecentFollowup.FieldValues["GtMeasurementDate"] -and -not [string]::IsNullOrEmpty($mostRecentFollowup.FieldValues["GtMeasurementDate"])) { 
                        $benefitItem.GtMeasurementDate = ([datetime]$mostRecentFollowup.FieldValues["GtMeasurementDate"]).ToString("yyyy-MM-ddTHH:mm:ssZ")
                    }
                    $benefitItem.GtMeasurementValue = $mostRecentFollowup.FieldValues["GtMeasurementValue"]
                    $benefitItem.GtMeasurementComment = $mostRecentFollowup.FieldValues["GtMeasurementComment"]
                    
                    # Calculate achievement based on TypeScript implementation
                    $benefitItem.GtcGoalAchievement = Calculate-Achievement -StartValue $benefitItem.GtStartValue -DesiredValue $benefitItem.GtDesiredValue -MeasurementValue $benefitItem.GtMeasurementValue
                }
                
                $results += $benefitItem
            }
        }
        return $results
    }

    # Keep track of processed benefits to avoid duplicates
    $ProcessedBenefits = @()
    
    # Create a mapping of benefits to their first associated change
    $BenefitToFirstChange = @{}
    foreach ($gevinst in $Gevinster) {
        if ($gevinst.FieldValues["GtChangeLookup"]) {
            $changeId = $gevinst.FieldValues["GtChangeLookup"].LookupId
            if (-not $BenefitToFirstChange.ContainsKey($gevinst.Id)) {
                # Find the first change for this benefit
                $firstChange = $Endringer | Where-Object { $_.Id -eq $changeId } | Select-Object -First 1
                if ($firstChange) {
                    $BenefitToFirstChange[$gevinst.Id] = $firstChange
                }
            }
        }
    }

    # Process benefits with their first associated change only
    foreach ($gevinst in $Gevinster) {
        if ($BenefitToFirstChange.ContainsKey($gevinst.Id)) {
            # This benefit has associated changes - use the first one
            $firstChange = $BenefitToFirstChange[$gevinst.Id]
            $BenefitsAggregationItems += Get-BenefitItems -gevinst $gevinst -endring $firstChange
            $ProcessedBenefits += $gevinst.Id
        }
    }

    # Process any standalone benefits that weren't linked to changes
    $StandaloneBenefits = $Gevinster | Where-Object { 
        $_.Id -notin $ProcessedBenefits
    }
    
    foreach ($gevinst in $StandaloneBenefits) {
        $BenefitsAggregationItems += Get-BenefitItems -gevinst $gevinst
    }

    
    return $BenefitsAggregationItems
}

$global:__ClientId = $ClientId
$UseManagedIdentity = ($null -ne $PSPrivateMetadata)
$ErrorActionPreference = "Stop"

if ($null -eq (Get-Command Connect-PnPOnline -ErrorAction SilentlyContinue)) {
    Write-Output "You have to load the PnP.PowerShell module before running this script!"
    exit 0
}

$UniqueKeyFieldXml = '<Field Type="Text" Name="GtcUniqueKey" DisplayName="Unik nøkkel" ID="{32832a92-8ccb-42a6-a4df-0763df3c35a5}" Required="FALSE" StaticName="GtcUniqueKey" ShowInNewForm="FALSE" ShowInEditForm="FALSE" />'
Connect-SharePoint -Url $HubUrl
EnsureBenefitsListExists -Url $HubUrl -UniqueKeyFieldXml $UniqueKeyFieldXml

if (-not $UseManagedIdentity) {
    try {
        $AdminUrl = $HubUrl -replace "^(https://[^\.]+)\.sharepoint\.com.*$", '$1-admin.sharepoint.com/'

        Connect-SharePoint -Url $AdminUrl
        $HubSite = Get-PnPHubSite -Identity $HubUrl
        $ProjectsOfHub = Get-PnPHubSiteChild -Identity $HubUrl
        $CurrentUser = Get-PnPProperty -Property CurrentUser -ClientObject (Get-PnPContext).Web -ErrorAction SilentlyContinue
        $ProjectsOfHub | ForEach-Object {
            Write-Output "Setting owner of site $_ to current user $($CurrentUser.LoginName)"
            Set-PnPTenantSite -Identity $_ -Owner $CurrentUser.LoginName -ErrorAction SilentlyContinue
        }
        Write-Output "Successfully assigned permissions to all hub sites."
    }
    catch {
        Write-Warning "Unable to assign permissions to all sites. This requires SharePoint Administrator permissions."
        Write-Warning "The script will continue and process only sites where you already have access."
        Write-Output ""
    }
}


Connect-SharePoint -Url $HubUrl
Get-PnPListItem -List "Prosjekter" -PageSize 500 -Fields "Id", "Title", "GtSiteUrl" | ForEach-Object {
    $ProjectName = $_.FieldValues["Title"]
    $ProjectUrl = $_.FieldValues["GtSiteUrl"]

    Write-Output "Processing project site: $ProjectUrl"
    Connect-SharePoint -Url $ProjectUrl

    Write-Output "Aggregating benefits from $ProjectUrl to $HubUrl"
    $AggregationItems = Aggregate-BenefitsToHub -ProjectName $ProjectName -ProjectUrl $ProjectUrl -HubUrl $HubUrl
    Write-Output "Built array with $($AggregationItems.Count) items for project '$ProjectName'"
        
    if ( $AggregationItems.Count -eq 0) {
        return
    }
    foreach ($AggregationItem in $AggregationItems) {
        # Convert the object to a hashtable for SharePoint operations
        $ItemValues = @{}
        $AggregationItem.PSObject.Properties | ForEach-Object {
            $ItemValues[$_.Name] = $_.Value
        }
        # Add Title field for SharePoint (using unique key as title)
        $ItemValues["Title"] = $AggregationItem.GtcProjectName + " - " + $AggregationItem.GtcBenefitTitle
            
        try {
            Connect-SharePoint -Url $HubUrl
            $ExistingItem = Get-PnPListItem -List "Gevinstoversikt" -Query "<View><Query><Where><Eq><FieldRef Name='GtcUniqueKey'/><Value Type='Text'>$($AggregationItem.GtcUniqueKey)</Value></Eq></Where></Query></View>" -ErrorAction SilentlyContinue
            if ($null -ne $ExistingItem) {
                Write-Output "`tUpdating existing item '$($AggregationItem.GtcBenefitTitle)' with key '$($AggregationItem.GtcUniqueKey)'"
                $GevinstItem = Set-PnPListItem -List "Gevinstoversikt" -Identity $ExistingItem.Id -Values $ItemValues -ErrorAction Stop
            }
            else {
                Write-Output "`tCreating new item '$($AggregationItem.GtcBenefitTitle)' with key '$($AggregationItem.GtcUniqueKey)'"
                $GevinstItem = Add-PnPListItem -List "Gevinstoversikt" -Values $ItemValues -ErrorAction Stop
            }
        }
        catch {
            Write-Warning "`tFailed to process item, see error: $($_.Exception.Message)"
        }
    }
}