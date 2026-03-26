function Connect-SharePoint {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    $PnpParams = @{
        Url = $Url
    }

    if ($null -ne $PSPrivateMetadata) {
        # Azure Automation runbook context - use managed identity
        $PnpParams.Add("ManagedIdentity", $true)
    }
    else {
        # Local/interactive context - use interactive login with delegated permissions
        if ($ClientId) {
            $PnpParams.Add("ClientId", $ClientId)
        }
    }

    Connect-PnPOnline @PnpParams
}

function Get-FieldValue {
    param($Value)

    if ($null -eq $Value -or $Value -eq "") {
        return ""
    }
    elseif ($Value -is [Microsoft.SharePoint.Client.FieldLookupValue]) {
        return $Value.LookupValue
    }
    elseif ($Value -is [Array] -and $Value.Count -gt 0 -and $Value[0] -is [Microsoft.SharePoint.Client.FieldLookupValue]) {
        return ($Value | ForEach-Object { $_.LookupValue }) -join ", "
    }
    elseif ($Value -is [Microsoft.SharePoint.Client.Taxonomy.TaxonomyFieldValue]) {
        return $Value.Label
    }
    elseif ($Value -is [Microsoft.SharePoint.Client.Taxonomy.TaxonomyFieldValueCollection]) {
        return ($Value | ForEach-Object { $_.Label }) -join ", "
    }
    elseif ($Value -is [Array] -and $Value.Count -gt 0 -and $Value[0] -is [Microsoft.SharePoint.Client.Taxonomy.TaxonomyFieldValue]) {
        return ($Value | ForEach-Object { $_.Label }) -join ", "
    }
    elseif ($Value -is [System.Collections.Hashtable] -and $Value.ContainsKey('Label')) {
        return $Value.Label
    }
    else {
        return "$Value"
    }
}

# Fetch data from project/hub and build token map from SharePoint lists
function Get-TokenMap {
    param($ProjectUrl, $HubSiteUrl, $Tokens)

    Connect-SharePoint -Url $ProjectUrl | Out-Null
    $Map = @{}

    # Cache for Prosjektstatus tokens - fetched once from hub site
    $LatestStatusReport = $null
    $StatusReportFetched = $false

    foreach ($Token in $Tokens) {
        # Handle {{Today}} token (case-insensitive) - replace with current date
        if ($Token -ieq '{{Today}}') {
            $Map[$Token] = Get-Date -Format "dd.MM.yyyy"
            continue
        }

        # Handle {{Prosjektstatus:FieldName}} token - fetch from hub site's Prosjektstatus list
        if ($Token -match '\{\{Prosjektstatus:([^}]+)\}\}') {
            $FieldName = $matches[1]

            # Fetch latest published status report only once
            if (-not $StatusReportFetched) {
                $StatusReportFetched = $true
                try {
                    # Get project SiteId (need to be connected to project site)
                    Connect-SharePoint -Url $ProjectUrl | Out-Null
                    $SiteId = (Get-PnPProperty -ClientObject (Get-PnPSite) -Property "Id").Guid

                    # Query hub for latest published status report for this project
                    Connect-SharePoint -Url $HubSiteUrl | Out-Null
                    $Reports = Get-PnPListItem -List "Prosjektstatus" -Query "<View><Query><Where><And><Eq><FieldRef Name='GtModerationStatus' /><Value Type='Text'>Publisert</Value></Eq><Eq><FieldRef Name='GtSiteId' /><Value Type='Text'>$SiteId</Value></Eq></And></Where></Query></View>" | Sort-Object Id -Descending
                    $LatestStatusReport = $Reports | Select-Object -First 1

                    # Reconnect to project site for any subsequent List tokens
                    Connect-SharePoint -Url $ProjectUrl | Out-Null
                }
                catch {
                    Write-Warning "Failed to fetch project status from hub site: $_"
                    # Reconnect to project site
                    Connect-SharePoint -Url $ProjectUrl | Out-Null
                }
            }

            if ($null -ne $LatestStatusReport) {
                $RawValue = $LatestStatusReport.FieldValues[$FieldName]
                $Map[$Token] = Get-FieldValue -Value $RawValue
            } else {
                $Map[$Token] = ""
            }
            continue
        }

        # Parse token format: {{List:ListName;Fields:Field1,Field2,Field3}} or {{List:ListName;Fields:Field1(0.1),Field2(0.2),Field3(0.7);Width:0.7}}
        if ($Token -match '\{\{List:([^;]+);Fields:([^;]+)(?:;Width:([0-9.,]+))?\}\}') {
            $ListName = $matches[1]
            $FieldsSpec = $matches[2]
            $TableWidthRatio = if ($matches[3]) {
                $WidthValue = $matches[3] -replace ',', '.'
                [double]$WidthValue
            } else {
                0.95  # Default to 95% of available width
            }

            # Parse field names and optional width specifications
            $FieldsArray = @()
            $ColumnWidths = @()
            $HasCustomWidths = $false

            foreach ($FieldSpec in ($FieldsSpec -split ',' | ForEach-Object { $_.Trim() })) {
                # Match both dot and comma as decimal separator: FieldName(0.2) or FieldName(0,2)
                if ($FieldSpec -match '^([^(]+)\(([0-9.,]+)\)$') {
                    # Field with width specification: FieldName(0.2)
                    $FieldsArray += $matches[1].Trim()
                    # Normalize decimal separator to dot for parsing
                    $WidthString = $matches[2] -replace ',', '.'
                    $ColumnWidths += [double]$WidthString
                    $HasCustomWidths = $true
                } else {
                    # Field without width specification
                    $FieldsArray += $FieldSpec
                    $ColumnWidths += 0
                }
            }

            # Validate widths sum to ~1.0 if custom widths are specified
            if ($HasCustomWidths) {
                $WidthSum = ($ColumnWidths | Measure-Object -Sum).Sum
                if ($WidthSum -gt 0 -and [Math]::Abs($WidthSum - 1.0) -gt 0.01) {
                    # Normalize widths
                    $ColumnWidths = @($ColumnWidths | ForEach-Object { $_ / $WidthSum })
                }
            }

            # Store width metadata in token (will be parsed later during replacement)
            $WidthMetadata = ""
            if ($HasCustomWidths) {
                $WidthMetadata = "###WIDTHS###" + ($ColumnWidths -join "|") + "###"
            }
            # Store table width ratio
            $WidthMetadata += "###TABLEWIDTH###$TableWidthRatio###"

            # Fetch list fields to get display names
            $FieldTitles = @()
            try {
                $List = Get-PnPList -Identity $ListName -Includes Fields -ErrorAction Stop
                foreach ($FieldName in $FieldsArray) {
                    $Field = $List.Fields | Where-Object { $_.InternalName -eq $FieldName } | Select-Object -First 1
                    if ($Field) {
                        $FieldTitles += $Field.Title
                    } else {
                        $FieldTitles += $FieldName
                    }
                }
            }
            catch {
                Write-Warning "Failed to fetch field titles from list '$ListName': $_"
                $FieldTitles = $FieldsArray
            }

            # Fetch data from SharePoint list
            try {
                $Rows = Get-PnPListItem -List $ListName -Fields $FieldsArray -ErrorAction Stop
            }
            catch {
                Write-Warning "Failed to fetch data from list '$ListName': $_"
                $Map[$Token] = ""
                continue
            }
            $Lines = @()

            foreach ($R in $Rows) {
                $CellValues = @()
                foreach ($Field in $FieldsArray) {
                    $RawValue = $R.FieldValues[$Field]
                    $CellValues += Get-FieldValue -Value $RawValue
                }

                # If only one field, just use the value; otherwise tab-separate
                if ($FieldsArray.Count -eq 1) {
                    $Lines += $CellValues[0]
                }
                else {
                    $LineText = ($CellValues -join "`t")
                    $Lines += $LineText
                }
            }

            # If only one field, join with newlines (plain text list); otherwise create table format
            if ($FieldsArray.Count -eq 1) {
                $Map[$Token] = ($Lines -join "`n")
            }
            else {
                # Add header row with field display names, separated by special marker ###HEADER###
                $HeaderRow = ($FieldTitles -join "`t")

                # If no data rows, create a placeholder row with "Tekst" in each column
                if ($Lines.Count -eq 0) {
                    $PlaceholderCells = @()
                    for ($i = 0; $i -lt $FieldsArray.Count; $i++) {
                        $PlaceholderCells += "Tekst"
                    }
                    $TableText = ($PlaceholderCells -join "`t")
                } else {
                    $TableText = ($Lines -join "`n")
                }

                $Map[$Token] = $WidthMetadata + "###HEADER###" + $HeaderRow + "`n" + $TableText
            }
        }
        else {
            $Map[$Token] = ""
        }
    }

    return $Map
}
