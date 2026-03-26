#Requires -Modules PnP.PowerShell

###
# How to start runbook from local context:
# Start-AzAutomationRunbook -ResourceGroupName "Prosjektportalen" -AutomationAccountName "Prosjektportalen-Premium-Account" -Name "ProjectDocxDocumentGeneration" -Parameters @{ProjectUrl="https://puzzlepart.sharepoint.com/sites/Vino001";SiteRelativeTemplateFilePath="/Dokumentgenereringsmaler/MAL_Styringsdokument.docx";HubSiteUrl="https://puzzlepart.sharepoint.com/sites/pp-vmp"}
param(
    [Parameter(Mandatory = $true)] [string]$ProjectUrl,
    [Parameter(Mandatory = $true)] [string]$SiteRelativeTemplateFilePath,  # Site-relative path (e.g., "/Dokumentgenereringsmaler/Template.docx")
    [Parameter(Mandatory = $true)] [string]$HubSiteUrl,
    [Parameter(Mandatory = $false)] [string]$TargetLibrary = "Delte dokumenter",
    [Parameter(Mandatory = $false)] [string]$TargetFolder = "Prosjektdokumenter",
    [Parameter(Mandatory = $false)] [string]$ClientId = "da6c31a6-b557-4ac3-9994-7315da06ea3a"
)

$ErrorActionPreference = "Stop"

try {
    # Validate SharePoint URLs to catch typos early
    foreach ($Url in @($ProjectUrl, $HubSiteUrl)) {
        if ($Url -notmatch '^https://[a-zA-Z0-9\-]+\.sharepoint\.(com|us|de|cn)/') {
            throw "Invalid SharePoint URL format: $Url. Expected format: https://tenant.sharepoint.com/sites/sitename"
        }
    }

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

    Connect-SharePoint -Url $HubSiteUrl

    $TempDir = [string]([System.IO.Path]::GetTempPath()).TrimEnd('\', '/')
    $FileName = [string]([System.IO.Path]::GetFileName($SiteRelativeTemplateFilePath))

    # Add unique suffix to prevent temp file collisions during concurrent execution
    $UniqueSuffix = [System.Guid]::NewGuid().ToString().Substring(0, 8)
    $SafeFileName = [System.IO.Path]::GetFileNameWithoutExtension($FileName) + "_$UniqueSuffix" + [System.IO.Path]::GetExtension($FileName)

    Get-PnPFile -Url $SiteRelativeTemplateFilePath -Path $TempDir -FileName $SafeFileName -AsFile -Force | Out-Null
    $LocalPath = Join-Path $TempDir $SafeFileName

    if (-not (Test-Path $LocalPath)) {
        throw "Failed to download template from $SiteRelativeTemplateFilePath"
    }

    # Validate file is actually a DOCX (ZIP file with PK signature)
    $FileBytes = [System.IO.File]::ReadAllBytes($LocalPath)
    if ($FileBytes.Length -lt 2 -or $FileBytes[0] -ne 0x50 -or $FileBytes[1] -ne 0x4B) {
        Remove-Item $LocalPath -Force
        throw "Template file is not a valid DOCX file. Ensure the template path points to a .docx file."
    }

    # Parse tokens in DOCX
    Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null

    function Find-TokensInDocx {
        param([string]$DocxPath)

        $TempFolder = [string](Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString()))
        try {
            [System.IO.Compression.ZipFile]::ExtractToDirectory($DocxPath, $TempFolder)

            $FoundTokens = @()
            $XmlFiles = Get-ChildItem -Path $TempFolder -Recurse -Include *.xml

            foreach ($File in $XmlFiles) {
                $Content = Get-Content -LiteralPath $File.FullName -Raw

                # Extract all <w:t> text elements and concatenate them to find tokens
                # Note: <w:t> can have xml:space="preserve" attribute, so match <w:t ...>
                $TextElements = [regex]::Matches($Content, '<w:t[^>]*>([^<]*)</w:t>')
                $ConcatenatedText = ($TextElements | ForEach-Object { $_.Groups[1].Value }) -join ''

                # Find all tokens in the concatenated text
                $Matches = [regex]::Matches($ConcatenatedText, '\{\{([^}]+)\}\}')

                foreach ($Match in $Matches) {
                    $FullToken = $Match.Value

                    if ($FoundTokens -notcontains $FullToken) {
                        $FoundTokens += $FullToken
                    }
                }
            }
        }
        finally {
            # Clean up temp folder
            Remove-Item $TempFolder -Recurse -Force | Out-Null
        }

        return $FoundTokens
    }

    function Replace-TokensInDocx {
        param([string]$DocxPath, [hashtable]$TokenMap)

        $TempFolder = [string](Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString()))
        [System.IO.Compression.ZipFile]::ExtractToDirectory($DocxPath, $TempFolder)

        # Extract page dimensions from word/document.xml for table width calculations
        $DocumentXml = Join-Path $TempFolder "word\document.xml"
        $PageWidth = 11906   # Default A4 width in twips
        $LeftMargin = 1440   # Default left margin in twips
        $RightMargin = 1440  # Default right margin in twips
        if (Test-Path $DocumentXml) {
            $DocContent = Get-Content -LiteralPath $DocumentXml -Raw
            if ($DocContent -match '<w:pgSz[^>]*w:w="(\d+)"') {
                $PageWidth = [int]$matches[1]
            }
            if ($DocContent -match '<w:pgMar[^>]*w:left="(\d+)"') {
                $LeftMargin = [int]$matches[1]
            }
            if ($DocContent -match '<w:pgMar[^>]*w:right="(\d+)"') {
                $RightMargin = [int]$matches[1]
            }
        }
        $AvailableWidth = $PageWidth - $LeftMargin - $RightMargin

        $XmlFiles = Get-ChildItem -Path $TempFolder -Recurse -Include *.xml

        foreach ($File in $XmlFiles) {
            $Content = Get-Content -LiteralPath $File.FullName -Raw
            $OriginalContent = $Content

            foreach ($Key in $TokenMap.Keys) {
                # Check if token exists in concatenated text (handles split tokens)
                $TextElements = [regex]::Matches($Content, '<w:t[^>]*>([^<]*)</w:t>')
                $ConcatenatedText = ($TextElements | ForEach-Object { $_.Groups[1].Value }) -join ''

                if ($ConcatenatedText -notmatch [regex]::Escape($Key)) {
                    continue
                }

                $Value = $TokenMap[$Key]

                # Special handling for multi-column table data (tabs indicate columns, newlines indicate rows)
                if ($Value -match "`t") {
                    # Check if value contains width metadata and header row marker
                    $CustomColumnWidths = @()
                    $HasCustomWidths = $false
                    $CustomTableWidthRatio = 0.95  # Default

                    # Extract table width ratio if present
                    if ($Value -match "###TABLEWIDTH###([0-9.]+)###") {
                        $CustomTableWidthRatio = [double]$matches[1]
                        $Value = $Value -replace "###TABLEWIDTH###[0-9.]+###", ""
                    }

                    if ($Value -match "^###WIDTHS###([^#]+)###") {
                        $WidthsString = $matches[1]
                        $CustomColumnWidths = @($WidthsString -split '\|' | ForEach-Object {
                            $CleanValue = $_ -replace ',', '.'
                            [double]$CleanValue
                        })
                        $HasCustomWidths = $true
                        $Value = $Value -replace "^###WIDTHS###[^#]+###", ""
                    }

                    $HasHeader = $Value -match "^###HEADER###"
                    $ValueToProcess = $Value -replace "^###HEADER###", ""

                    # Parse table data
                    $Rows = $ValueToProcess -split "`n" | ForEach-Object { $_.TrimEnd("`r") } | Where-Object { $_ -ne "" }

                    if ($Rows.Count -eq 0) {
                        continue
                    }

                    # Split first row to determine column count
                    $FirstRowCells = $Rows[0] -split "`t"
                    $ColumnCount = $FirstRowCells.Count

                    # Validate all rows have same column count
                    $InvalidRows = $Rows | Where-Object { ($_ -split "`t").Count -ne $ColumnCount }
                    if ($InvalidRows.Count -gt 0) {
                        Write-Warning "Token '$Key' has inconsistent column counts. Treating as plain text."
                        # Fallback to plain text
                        $EscapedValue = [System.Security.SecurityElement]::Escape($Value)
                        $Content = $Content -replace [regex]::Escape($Key), $EscapedValue
                        continue
                    }

                    # Find the paragraph containing this token
                    $ParagraphPattern = '(?s)<w:p[ >].*?</w:p>'
                    $AllParagraphs = [regex]::Matches($Content, $ParagraphPattern)

                    $FoundParagraph = $null

                    foreach ($Para in $AllParagraphs) {
                        $ParaText = [regex]::Matches($Para.Value, '<w:t[^>]*>([^<]*)</w:t>') |
                                     ForEach-Object { $_.Groups[1].Value } |
                                     ForEach-Object { $_ -join '' }
                        $ParaTextCombined = $ParaText -join ''

                        if ($ParaTextCombined -match [regex]::Escape($Key)) {
                            $FoundParagraph = $Para.Value
                            break
                        }
                    }

                    if ($FoundParagraph) {
                        # Use custom or default percentage of available page width for the table
                        $TableWidth = [int]($AvailableWidth * $CustomTableWidthRatio)

                        # Calculate column widths based on custom widths or equal distribution
                        $ColumnWidthArray = @()
                        if ($HasCustomWidths -and $CustomColumnWidths.Count -eq $ColumnCount) {
                            # Use custom widths
                            foreach ($Width in $CustomColumnWidths) {
                                $ColWidth = [int]($TableWidth * $Width)
                                $ColumnWidthArray += $ColWidth
                            }
                        } else {
                            # Equal distribution
                            $ColumnWidth = [int]($TableWidth / $ColumnCount)
                            for ($i = 0; $i -lt $ColumnCount; $i++) {
                                $ColumnWidthArray += $ColumnWidth
                            }
                        }

                        # Table width in fifths-of-percent (5000 = 100%)
                        $TableWidthPct = [int](5000 * $CustomTableWidthRatio)

                        # Build table grid (column definitions in twips)
                        $GridCols = ""
                        for ($i = 0; $i -lt $ColumnCount; $i++) {
                            $GridCols += "<w:gridCol w:w=`"$($ColumnWidthArray[$i])`"/>"
                        }

                        # Build table rows
                        $TableRows = ""
                        $RowIndex = 0
                        foreach ($RowData in $Rows) {
                            $Cells = $RowData -split "`t"
                            $TableCells = ""

                            foreach ($CellValue in $Cells) {
                                $EscapedCell = [System.Security.SecurityElement]::Escape($CellValue)
                                # Bold formatting for header row (first row when ###HEADER### marker is present)
                                $BoldProp = ""
                                if ($HasHeader -and $RowIndex -eq 0) {
                                    $BoldProp = "<w:b/><w:bCs/>"
                                }
                                $TableCells += @"
<w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/></w:tcPr><w:p><w:r><w:rPr>$BoldProp<w:lang w:val="nb-NO"/></w:rPr><w:t xml:space="preserve">$EscapedCell</w:t></w:r></w:p></w:tc>
"@
                            }

                            $TableRows += "<w:tr>$TableCells</w:tr>"
                            $RowIndex++
                        }

                        # Create Word table element to replace the paragraph
                        $NewTable = @"
<w:tbl>
<w:tblPr>
<w:tblW w:w="$TableWidthPct" w:type="pct"/>
<w:tblBorders>
<w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>
<w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>
<w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>
<w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>
<w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>
<w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>
</w:tblBorders>
</w:tblPr>
<w:tblGrid>$GridCols</w:tblGrid>
$TableRows
</w:tbl>
"@

                        $Content = $Content.Replace($FoundParagraph, $NewTable)
                    }
                    continue
                }

                # For simple text replacement - find and replace split tokens
                # Find all paragraphs and check which one contains the token
                $ParagraphPattern = '(?s)<w:p[ >].*?</w:p>'
                $AllParagraphs = [regex]::Matches($Content, $ParagraphPattern)

                $FoundParagraph = $null
                foreach ($Para in $AllParagraphs) {
                    # Extract text from this paragraph and check if it contains the token
                    $ParaTextMatches = [regex]::Matches($Para.Value, '<w:t[^>]*>([^<]*)</w:t>')
                    $ParaText = ($ParaTextMatches | ForEach-Object { $_.Groups[1].Value }) -join ''

                    if ($ParaText -match [regex]::Escape($Key)) {
                        $FoundParagraph = $Para.Value
                        break
                    }
                }

                if ($FoundParagraph) {
                    # Extract text from all <w:t> elements in the paragraph
                    $TextMatches = [regex]::Matches($FoundParagraph, '<w:t[^>]*>([^<]*)</w:t>')
                    $ParagraphText = ($TextMatches | ForEach-Object { $_.Groups[1].Value }) -join ''

                    # Replace the token in the concatenated text
                    $NewText = $ParagraphText -replace [regex]::Escape($Key), [System.Security.SecurityElement]::Escape($Value)

                    # Find the first <w:r> element to preserve its properties
                    $FirstRunMatch = [regex]::Match($FoundParagraph, '(?s)<w:r>(?<props><w:rPr>.*?</w:rPr>)?<w:t[^>]*>')
                    $RunProps = if ($FirstRunMatch.Success -and $FirstRunMatch.Groups['props'].Success) {
                        $FirstRunMatch.Groups['props'].Value
                    } else {
                        '<w:rPr><w:lang w:val="nb-NO"/></w:rPr>'
                    }

                    # Get the paragraph properties (<w:pPr>) if present
                    $ParagraphProps = ""
                    if ($FoundParagraph -match '(?s)(<w:pPr>.*?</w:pPr>)') {
                        $ParagraphProps = $matches[1]
                    }

                    # Rebuild paragraph: preserve <w:pPr> and create single run with replaced text
                    $NewParagraph = "<w:p>$ParagraphProps<w:r>$RunProps<w:t xml:space=`"preserve`">$NewText</w:t></w:r></w:p>"

                    $Content = $Content.Replace($FoundParagraph, $NewParagraph)
                }
            }

            if ($Content -ne $OriginalContent) {
                Set-Content -LiteralPath $File.FullName -Value $Content -Encoding utf8NoBOM | Out-Null
            }
        }

        $NewDocx = [string]([System.IO.Path]::ChangeExtension($DocxPath, ".out.docx"))
        if (Test-Path $NewDocx) { Remove-Item $NewDocx -Force | Out-Null }

        # Create ZIP with optimal compression for Office files
        [System.IO.Compression.ZipFile]::CreateFromDirectory($TempFolder, $NewDocx, [System.IO.Compression.CompressionLevel]::Optimal, $false) | Out-Null

        Remove-Item $TempFolder -Recurse -Force | Out-Null
        return $NewDocx
    }

    # Fetch data from project and build token map from SharePoint lists
    function Get-TokenMap {
        param($ProjectUrl, $Tokens)

        Connect-SharePoint -Url $ProjectUrl | Out-Null
        $Map = @{}

        foreach ($Token in $Tokens) {
            # Handle {{Today}} token - replace with current date
            if ($Token -eq '{{Today}}') {
                $Map[$Token] = Get-Date -Format "dd.MM.yyyy"
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
                        $Value = $R.FieldValues[$Field]

                        $ExtractedValue = ""
                        if ($null -eq $Value -or $Value -eq "") {
                            $ExtractedValue = ""
                        }
                        elseif ($Value -is [Microsoft.SharePoint.Client.FieldLookupValue]) {
                            # Single lookup value
                            $ExtractedValue = $Value.LookupValue
                        }
                        elseif ($Value -is [Array] -and $Value.Count -gt 0 -and $Value[0] -is [Microsoft.SharePoint.Client.FieldLookupValue]) {
                            # Array of lookup values - join them with comma
                            $ExtractedValue = ($Value | ForEach-Object { $_.LookupValue }) -join ", "
                        }
                        elseif ($Value -is [Microsoft.SharePoint.Client.Taxonomy.TaxonomyFieldValue]) {
                            # Single taxonomy value - use Label property
                            $ExtractedValue = $Value.Label
                        }
                        elseif ($Value -is [Microsoft.SharePoint.Client.Taxonomy.TaxonomyFieldValueCollection]) {
                            # Multiple taxonomy values - join labels with comma
                            $ExtractedValue = ($Value | ForEach-Object { $_.Label }) -join ", "
                        }
                        elseif ($Value -is [Array] -and $Value.Count -gt 0 -and $Value[0] -is [Microsoft.SharePoint.Client.Taxonomy.TaxonomyFieldValue]) {
                            # Array of taxonomy values - join labels with comma
                            $ExtractedValue = ($Value | ForEach-Object { $_.Label }) -join ", "
                        }
                        elseif ($Value -is [System.Collections.Hashtable] -and $Value.ContainsKey('Label')) {
                            # Taxonomy value as hashtable (alternative format)
                            $ExtractedValue = $Value.Label
                        }
                        else {
                            $ExtractedValue = "$Value"
                        }

                        $CellValues += $ExtractedValue
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

    # Find all tokens in the template
    $TokensFound = Find-TokensInDocx -DocxPath $LocalPath
    $TokenMap = Get-TokenMap -ProjectUrl $ProjectUrl -Tokens $TokensFound
    $NewDocx = Replace-TokensInDocx -DocxPath $LocalPath -TokenMap $TokenMap

    # Upload the generated DOCX back to the project's document library
    Connect-SharePoint -Url $ProjectUrl | Out-Null

    # Validate TargetFolder doesn't contain path traversal or absolute paths
    if ($TargetFolder -match '\.\.' -or $TargetFolder -match '^[/\\]' -or $TargetFolder -match ':') {
        throw "Invalid TargetFolder path. Must be a simple folder name without '..' or absolute paths."
    }

    # Normalize and validate TargetLibrary exists
    $TargetLibrary = $TargetLibrary.TrimStart('/', '\').Replace('\', '/')
    try {
        $Library = Get-PnPList -Identity $TargetLibrary -ErrorAction Stop
        if ($null -eq $Library) {
            throw "Library '$TargetLibrary' not found in project site."
        }
    }
    catch {
        throw "Failed to validate target library '$TargetLibrary': $_"
    }

    # Construct full folder path
    $FullFolderPath = if ($TargetFolder) { "$TargetLibrary/$TargetFolder" } else { $TargetLibrary }

    $BaseFileName = [string](Split-Path $SiteRelativeTemplateFilePath -LeafBase)
    $FileName = "{0}_{1:yyMMddHHmmss}.docx" -f $BaseFileName, (Get-Date)
    Add-PnPFile -Path $NewDocx -Folder $FullFolderPath -NewFileName $FileName | Out-Null

    $FileUrl = "$ProjectUrl/$FullFolderPath/$FileName"
    Write-Output $FileUrl

    # Clean up temporary files
    if (Test-Path $NewDocx) { Remove-Item $NewDocx -Force -ErrorAction SilentlyContinue }
    if (Test-Path $LocalPath) { Remove-Item $LocalPath -Force -ErrorAction SilentlyContinue }

}
catch {
    Write-Error "Runbook failed: $_"
    # Clean up temporary files on error
    if ($NewDocx -and (Test-Path $NewDocx)) { Remove-Item $NewDocx -Force -ErrorAction SilentlyContinue }
    if ($LocalPath -and (Test-Path $LocalPath)) { Remove-Item $LocalPath -Force -ErrorAction SilentlyContinue }
    throw
}
