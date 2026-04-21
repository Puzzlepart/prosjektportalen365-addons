Param(
    [Parameter(Mandatory = $false)][string]$HubUrl = "https://prosjektportalen.sharepoint.com/sites/pp365",
    [Parameter(Mandatory = $false)][string]$ClientId = "da6c31a6-b557-4ac3-9994-7315da06ea3a", ## PP Client Id
    [Parameter(Mandatory = $false)][Nullable[datetime]]$Since
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
    [string]$GtcPartOfProgram
}

function Connect-SharePoint($Url) {
    $pnpParams = @{ 
        Url = $Url
    }
    if ($global:__UseManagedIdentity) {
        Write-Debug "Connecting to $Url using Managed Identity"
        $pnpParams.Add("ManagedIdentity", $true)
    }
    else {
        Write-Debug "Connecting to $Url using ClientId $($global:__ClientId)"
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

function Get-LastRunTimestamp {
    if ($Since) {
        return $Since.ToUniversalTime()
    }
    if ($global:__UseManagedIdentity) {
        try {
            $lastRunStr = Get-AutomationVariable -Name "AggregationLastRun" -ErrorAction SilentlyContinue
            if (-not [string]::IsNullOrEmpty($lastRunStr)) {
                return [datetime]::Parse($lastRunStr).ToUniversalTime()
            }
        }
        catch {
            Write-Warning "Could not read AggregationLastRun variable: $($_.Exception.Message)"
        }
    }
    return $null
}

function Test-ProjectSiteHasChanges($LastRun) {
    if ($null -eq $LastRun) {
        return $true
    }
    $lastRunISO = $LastRun.ToString("yyyy-MM-ddTHH:mm:ssZ")
    $SourceLists = @("Endringsanalyse", "Gevinstanalyse og gevinstrealiseringsplan", "Måleindikatorer", "Gevinstoppfølging", "Prosjektegenskaper")
    foreach ($listName in $SourceLists) {
        $list = Get-PnPList -Identity $listName -ErrorAction SilentlyContinue
        if ($null -eq $list) { continue }
        $changedItems = Get-PnPListItem -List $listName -Query "<View><RowLimit>1</RowLimit><Query><Where><Geq><FieldRef Name='Modified'/><Value Type='DateTime' IncludeTimeValue='TRUE'>$lastRunISO</Value></Geq></Where></Query></View>" -ErrorAction SilentlyContinue
        if ($changedItems -and @($changedItems).Count -gt 0) {
            return $listName
        }
    }
    return $null
}

function Compare-ItemValues($ExistingFieldValues, $NewValues) {
    foreach ($key in $NewValues.Keys) {
        $newVal = $NewValues[$key]
        $existingVal = $ExistingFieldValues[$key]

        # Normalize person fields (SharePoint returns FieldUserValue objects)
        if ($existingVal -is [Microsoft.SharePoint.Client.FieldUserValue]) {
            $existingVal = $existingVal.Email
        }
        # Normalize lookup fields
        if ($existingVal -is [Microsoft.SharePoint.Client.FieldLookupValue]) {
            $existingVal = $existingVal.LookupValue
        }
        # Normalize DateTime to ISO string
        if ($existingVal -is [datetime]) {
            $existingVal = $existingVal.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        }

        # Treat null and empty string as equivalent
        $existingIsEmpty = ($null -eq $existingVal -or [string]::IsNullOrEmpty("$existingVal"))
        $newIsEmpty = ($null -eq $newVal -or [string]::IsNullOrEmpty("$newVal"))
        if ($existingIsEmpty -and $newIsEmpty) { continue }
        if ($existingIsEmpty -ne $newIsEmpty) { return $true }

        if ("$existingVal" -ne "$newVal") {
            return $true
        }
    }
    return $false
}

function Get-DynamicProjectPropertyFields {
    $BenefitsListName = "Gevinstoversikt"
    # All fields already handled by the AggregatedBenefitValue class and script logic
    $KnownFields = @(
        "GtcUniqueKey", "GtcProjectName", "GtcProjectUrl", "GtcChangeTitle", "GtProcess",
        "GtChallengeDescription", "GtcBenefitTitle", "GtGainsType", "GtPrereqProfitAchievement",
        "GtGainsTurnover", "GtGainsResponsible", "GtGainsOwner", "GtRealizationTime",
        "GtcMeasurementIndicator", "GtStartValue", "GtDesiredValue", "GtMeasurementUnit",
        "GtMeasurementDate", "GtMeasurementValue", "GtMeasurementComment",
        "GtcGoalAchievement", "GtcPartOfProgram"
    )
    try {
        $AllFields = Get-PnPField -List $BenefitsListName -ErrorAction SilentlyContinue
        $DynamicFields = $AllFields | Where-Object {
            $_.InternalName.StartsWith("Gt") -and
            $_.InternalName -notin $KnownFields -and
            $_.Hidden -eq $false
        } | Select-Object -ExpandProperty InternalName
        if ($DynamicFields) {
            return @($DynamicFields)
        }
    }
    catch {
        Write-Warning "Unable to discover dynamic fields on '$BenefitsListName': $($_.Exception.Message)"
    }
    return @()
}

function Get-DynamicProjectPropertyValues($DynamicFields) {
    if ($DynamicFields.Count -eq 0) {
        return @{}
    }
    try {
        $ProjectProperties = Get-PnPListItem -List "Prosjektegenskaper" -Id 1 -ErrorAction SilentlyContinue
        if ($null -eq $ProjectProperties) {
            return @{}
        }
    }
    catch {
        return @{}
    }
    $Values = @{}
    foreach ($fieldName in $DynamicFields) {
        $val = $ProjectProperties.FieldValues[$fieldName]
        if ($null -eq $val) { continue }
        # Handle User fields
        if ($val -is [Microsoft.SharePoint.Client.FieldUserValue]) {
            $Values[$fieldName] = $val.Email
        }
        # Handle Lookup fields
        elseif ($val -is [Microsoft.SharePoint.Client.FieldLookupValue]) {
            $Values[$fieldName] = $val.LookupValue
        }
        # Handle Taxonomy fields
        elseif ($val -is [Microsoft.SharePoint.Client.Taxonomy.TaxonomyFieldValue]) {
            $Values[$fieldName] = $val.Label
        }
        # Handle DateTime fields
        elseif ($val -is [datetime]) {
            $Values[$fieldName] = $val.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
        # Handle everything else as string
        elseif (-not [string]::IsNullOrEmpty("$val")) {
            $Values[$fieldName] = "$val"
        }
    }
    return $Values
}

function EnsureBenefitsListExists($Url, $UniqueKeyFieldXml) {
    $BenefitsListName = "Gevinstoversikt"
    $BenefitsList = Get-PnPList -Identity $BenefitsListName -ErrorAction SilentlyContinue
    if ($null -eq $BenefitsList) {
        Write-Output "Creating '$BenefitsListName' list in hub site $Url"
        try {
            $NewList = New-PnPList -Title $BenefitsListName -Template GenericList -EnableVersioning
        }
        catch {
            Write-Warning "Failed to create list '$BenefitsListName': $($_.Exception.Message)"
            if ($global:__UseManagedIdentity) {
                Write-Warning "The Managed Identity may not have sufficient permissions (Sites.FullControl.All) on the hub site."
                Write-Warning "Please run this script once in interactive mode as a SharePoint admin to set up the list and columns."
            }
            throw
        }
    }
    else {
        Write-Output "'$BenefitsListName' list already exists in hub site $Url. Ensuring all columns and view exist."
    }

    # Define custom fields to create directly on the list
    $CustomFields = @(
        @{ InternalName = "GtcProjectName"; DisplayName = "Prosjektnavn"; Type = "Text" },
        @{ InternalName = "GtcProjectUrl"; DisplayName = "Prosjekt-URL"; Type = "Text" },
        @{ InternalName = "GtcChangeTitle"; DisplayName = "Endring"; Type = "Text" },
        @{ InternalName = "GtcBenefitTitle"; DisplayName = "Gevinst"; Type = "Text" },
        @{ InternalName = "GtcMeasurementIndicator"; DisplayName = "Måleindikator"; Type = "Text" },
        @{ InternalName = "GtcGoalAchievement"; DisplayName = "Måloppnåelse"; Type = "Number" },
        @{ InternalName = "GtcPartOfProgram"; DisplayName = "Tilhører program"; Type = "Note" }
    )

    # Define site columns to add from the site
    $SiteColumnsToAdd = @(
        "GtProcess",                # Endringsprosess
        "GtChallengeDescription",   # Beskrivelse av utfordring
        "GtGainsType",              # Type gevinst
        "GtPrereqProfitAchievement", # Forutsetning for gevinstrealisering
        "GtGainsTurnover",          # Omsetning
        "GtGainsResponsible",       # Ansvarlig for gevinst
        "GtGainsOwner",             # Eier av gevinst
        "GtRealizationTime",        # Tidslinje for gevinstrealisering
        "GtStartValue",             # Startverdi
        "GtDesiredValue",           # Ønsket verdi
        "GtMeasurementUnit",        # Måleenhet
        "GtMeasurementDate",        # Måledato
        "GtMeasurementValue",       # Måleverdi
        "GtMeasurementComment"      # Målkommentar
    )

    # Schema modifications are non-breaking if the list already exists.
    # When running with Managed Identity without Sites.FullControl.All, these may fail
    # but the script can still continue if the list was previously set up interactively.
    $SchemaErrors = @()

    # Get existing fields on the list to check what's already there
    try {
        $ExistingFields = Get-PnPField -List $BenefitsListName | Select-Object -ExpandProperty InternalName
    }
    catch {
        Write-Warning "Unable to read existing fields on '$BenefitsListName': $($_.Exception.Message)"
        Write-Warning "Skipping schema verification. The script will attempt to continue with existing list schema."
        return
    }

    # Ensure the UniqueKey XML field exists
    if ("GtcUniqueKey" -notin $ExistingFields) {
        try {
            Write-Output "`tAdding field 'GtcUniqueKey' to '$BenefitsListName'"
            $NewField = Add-PnPFieldFromXml -List $BenefitsListName -FieldXml $UniqueKeyFieldXml
        }
        catch {
            $SchemaErrors += "GtcUniqueKey"
            Write-Warning "`tFailed to add field 'GtcUniqueKey': $($_.Exception.Message)"
        }
    }

    # Ensure all custom fields exist
    foreach ($field in $CustomFields) {
        if ($field.InternalName -notin $ExistingFields) {
            try {
                Write-Output "`tAdding field '$($field.InternalName)' to '$BenefitsListName'"
                $NewField = Add-PnPField -List $BenefitsListName -DisplayName $field.DisplayName -InternalName $field.InternalName -Type $field.Type
            }
            catch {
                $SchemaErrors += $field.InternalName
                Write-Warning "`tFailed to add field '$($field.InternalName)': $($_.Exception.Message)"
            }
        }
    }

    # Ensure all site columns exist on the list
    foreach ($fieldName in $SiteColumnsToAdd) {
        if ($fieldName -notin $ExistingFields) {
            try {
                Write-Output "`tAdding site column '$fieldName' to '$BenefitsListName'"
                $AddedField = Add-PnPField -List $BenefitsListName -Field $fieldName
            }
            catch {
                $SchemaErrors += $fieldName
                Write-Warning "`tFailed to add site column '$fieldName': $($_.Exception.Message)"
            }
        }
    }

    # Ensure the default view exists
    $ViewName = "Alle gevinster"
    $ExistingView = Get-PnPView -List $BenefitsListName -Identity $ViewName -ErrorAction SilentlyContinue
    if ($null -eq $ExistingView) {
        try {
            Write-Output "`tCreating view '$ViewName' on '$BenefitsListName'"
            $NewView = Add-PnPView -List $BenefitsListName -Title $ViewName -Fields @("GtcProjectName", "GtcPartOfProgram", "GtcChangeTitle", "GtcBenefitTitle", "GtGainsType", "GtcMeasurementIndicator", "GtStartValue", "GtDesiredValue", "GtMeasurementUnit", "GtMeasurementValue", "GtcGoalAchievement") -RowLimit 500 -Paged -Aggregations "GtMeasurementValue" -SetAsDefault
        }
        catch {
            $SchemaErrors += "View: $ViewName"
            Write-Warning "`tFailed to create view '$ViewName': $($_.Exception.Message)"
        }
    }

    if ($SchemaErrors.Count -gt 0) {
        Write-Warning "Some schema modifications could not be applied to '$BenefitsListName': $($SchemaErrors -join ', ')"
        if ($global:__UseManagedIdentity) {
            Write-Warning "The Managed Identity may not have sufficient permissions (Sites.FullControl.All) on the hub site."
            Write-Warning "Please run this script once in interactive mode as a SharePoint admin to set up the list and columns,"
            Write-Warning "or run the AssignPermissionsToManagedIdentity.ps1 script to grant the required permissions."
        }
        Write-Warning "Continuing with existing list schema..."
    }
}

function Aggregate-BenefitsToHub($ProjectName, $ProjectUrl, $HubUrl, $PartOfProgram) {
    $BenefitsAggregationItems = @()
    
    try {        
        # Get the current site ID for the unique key
        $CurrentSite = Get-PnPSite -Includes Id
        $SiteId = $CurrentSite.Id.ToString()
    }
    catch {
        Write-Warning "Failed to access project site $ProjectUrl. You may not have sufficient permissions on this site. Skipping aggregation."
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
            $benefitItem.GtcUniqueKey = "$SiteId-$changeId-$($gevinst.Id)-0"
            $benefitItem.GtcProjectName = $ProjectName
            $benefitItem.GtcProjectUrl = $ProjectUrl
            $benefitItem.GtcPartOfProgram = $PartOfProgram
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
                
                $benefitItem.GtcUniqueKey = "$SiteId-$changeId-$($gevinst.Id)-$($indicator.Id)"
                
                $benefitItem.GtcProjectName = $ProjectName
                $benefitItem.GtcProjectUrl = $ProjectUrl
                $benefitItem.GtcPartOfProgram = $PartOfProgram
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
$global:__UseManagedIdentity = ($null -ne $PSPrivateMetadata) -or ($null -ne (Get-Command Get-AutomationVariable -ErrorAction SilentlyContinue)) -or ($env:IDENTITY_ENDPOINT -ne $null)
$ErrorActionPreference = "Stop"

if ($global:__UseManagedIdentity) {
    Write-Output "Running in Azure Automation context (Managed Identity)"
    Write-Output "PowerShell version: $($PSVersionTable.PSVersion)"
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Error "Managed Identity authentication requires PowerShell 7.2+. Current version: $($PSVersionTable.PSVersion). Please update the runbook runtime to PowerShell 7.2 in Azure Automation."
        exit 1
    }
} else {
    Write-Output "Running in interactive context (ClientId: $ClientId)"
}

if ($null -eq (Get-Command Connect-PnPOnline -ErrorAction SilentlyContinue)) {
    Write-Output "You have to load the PnP.PowerShell module before running this script!"
    exit 0
}

$UniqueKeyFieldXml = '<Field Type="Text" Name="GtcUniqueKey" DisplayName="Unik nøkkel" ID="{32832a92-8ccb-42a6-a4df-0763df3c35a5}" Required="FALSE" StaticName="GtcUniqueKey" ShowInNewForm="FALSE" ShowInEditForm="FALSE" />'
Connect-SharePoint -Url $HubUrl
EnsureBenefitsListExists -Url $HubUrl -UniqueKeyFieldXml $UniqueKeyFieldXml

# Discover dynamic Gt* fields on the hub benefits list that should be stamped from project properties
$DynamicProjectPropertyFields = Get-DynamicProjectPropertyFields
if ($DynamicProjectPropertyFields.Count -gt 0) {
    Write-Output "Discovered $($DynamicProjectPropertyFields.Count) dynamic project property field(s) to stamp: $($DynamicProjectPropertyFields -join ', ')"
} else {
    Write-Output "No dynamic project property fields found on 'Gevinstoversikt'."
}

if (-not $global:__UseManagedIdentity) {
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
$AllProjects = Get-PnPListItem -List "Prosjekter" -PageSize 500 -Fields "Id", "Title", "GtSiteUrl", "GtChildProjects"

$LastRunTimestamp = Get-LastRunTimestamp
if ($null -eq $LastRunTimestamp) {
    Write-Output "No previous run timestamp found. Running full sync."
} else {
    Write-Output "Delta sync: processing changes since $LastRunTimestamp"
}

# Build program membership lookup: ProjectSiteUrl -> list of program titles
$ProgramMembership = @{}
foreach ($proj in $AllProjects) {
    $ChildProjectsValue = $proj.FieldValues["GtChildProjects"]
    if (-not [string]::IsNullOrEmpty($ChildProjectsValue)) {
        try {
            $ChildProjects = $ChildProjectsValue | ConvertFrom-Json
            foreach ($ChildProject in $ChildProjects) {
                $ChildUrl = $ChildProject.Path
                if (-not [string]::IsNullOrEmpty($ChildUrl)) {
                    $ChildUrl = $ChildUrl.TrimEnd("/")
                    if (-not $ProgramMembership.ContainsKey($ChildUrl)) {
                        $ProgramMembership[$ChildUrl] = @()
                    }
                    $ProgramMembership[$ChildUrl] += $proj.FieldValues["Title"]
                }
            }
        }
        catch {
            Write-Warning "Failed to parse GtChildProjects for '$($proj.FieldValues["Title"])': $($_.Exception.Message)"
        }
    }
}

$AllProjects | ForEach-Object {
    $ProjectItemId = $_.Id
    $ProjectName = $_.FieldValues["Title"]
    $ProjectUrl = $_.FieldValues["GtSiteUrl"]

    # Determine program membership for this project
    $PartOfProgram = ""
    $ProjectUrlTrimmed = if ($ProjectUrl) { $ProjectUrl.TrimEnd("/") } else { "" }
    if ($ProjectUrlTrimmed -and $ProgramMembership.ContainsKey($ProjectUrlTrimmed)) {
        $PartOfProgram = $ProgramMembership[$ProjectUrlTrimmed] -join "; "
    }

    Write-Output "Processing project site: $ProjectUrl"
    Connect-SharePoint -Url $ProjectUrl

    # Delta sync: skip project sites with no changes since last run
    $ChangedList = Test-ProjectSiteHasChanges -LastRun $LastRunTimestamp
    if (-not $ChangedList) {
        Write-Output "`tNo changes since last run, skipping."
        return
    }
    if ($ChangedList -is [string]) {
        Write-Output "`tChanges detected in '$ChangedList' since last run"
    }

    # Read dynamic project property values from the project's Prosjektegenskaper list
    $DynamicPropertyValues = Get-DynamicProjectPropertyValues -DynamicFields $DynamicProjectPropertyFields
    if ($DynamicPropertyValues.Count -gt 0) {
        Write-Output "`tRead $($DynamicPropertyValues.Count) dynamic property value(s) from project properties"
    }

    Write-Output "Aggregating benefits from $ProjectUrl to $HubUrl"
    $AggregationItems = Aggregate-BenefitsToHub -ProjectName $ProjectName -ProjectUrl $ProjectUrl -HubUrl $HubUrl -PartOfProgram $PartOfProgram
    Write-Output "Built array with $($AggregationItems.Count) items for project '$ProjectName'"
        
    if ( $AggregationItems.Count -eq 0) {
        return
    }

    # Connect to hub once per project batch, not per item
    Connect-SharePoint -Url $HubUrl

    foreach ($AggregationItem in $AggregationItems) {
        # Convert the object to a hashtable for SharePoint operations
        $ItemValues = @{}
        $AggregationItem.PSObject.Properties | ForEach-Object {
            $ItemValues[$_.Name] = $_.Value
        }
        # Add Title field for SharePoint (using unique key as title)
        $ItemValues["Title"] = $AggregationItem.GtcProjectName + " - " + $AggregationItem.GtcBenefitTitle

        # Stamp dynamic project property values (only for keys not already set)
        foreach ($dpKey in $DynamicPropertyValues.Keys) {
            if (-not $ItemValues.ContainsKey($dpKey)) {
                $ItemValues[$dpKey] = $DynamicPropertyValues[$dpKey]
            }
        }
            
        try {
            $ExistingItem = Get-PnPListItem -List "Gevinstoversikt" -Query "<View><Query><Where><Eq><FieldRef Name='GtcUniqueKey'/><Value Type='Text'>$($AggregationItem.GtcUniqueKey)</Value></Eq></Where></Query></View>" -ErrorAction SilentlyContinue
            if ($null -ne $ExistingItem) {
                # Skip update if no field values have changed
                if (-not (Compare-ItemValues -ExistingFieldValues $ExistingItem.FieldValues -NewValues $ItemValues)) {
                    Write-Output "`tItem '$($AggregationItem.GtcBenefitTitle)' unchanged, skipping."
                    continue
                }
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

# Save last run timestamp for next delta sync
if ($global:__UseManagedIdentity) {
    try {
        $now = (Get-Date).ToUniversalTime().ToString("o")
        Set-AutomationVariable -Name "AggregationLastRun" -Value $now
        Write-Output "Saved last run timestamp: $now"
    }
    catch {
        Write-Warning "Failed to save AggregationLastRun variable: $($_.Exception.Message)"
    }
}