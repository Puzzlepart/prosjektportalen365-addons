#Requires -Modules PnP.PowerShell

###
# How to start runbook from local context:
# Start-AzAutomationRunbook -ResourceGroupName "Prosjektportalen" -AutomationAccountName "Prosjektportalen-Premium-Account" -Name "ProjectDocumentGeneration" -Parameters @{ProjectUrl="https://puzzlepart.sharepoint.com/sites/Vino001";TemplatePath="/sites/pp-vmp/Dokumentgenereringsmaler/MAL_Styringsdokument.pptx";HubSiteUrl="https://puzzlepart.sharepoint.com/sites/pp-vmp"}
param(
    [Parameter(Mandatory = $true)] [string]$ProjectUrl,
    [Parameter(Mandatory = $true)] [string]$TemplatePath,
    [Parameter(Mandatory = $true)] [string]$HubSiteUrl,
    [Parameter(Mandatory = $false)] [string]$TargetFolder = "Delte dokumenter/Styringsdokumenter",
    [Parameter(Mandatory = $false)] [string]$ClientId = "da6c31a6-b557-4ac3-9994-7315da06ea3a"
)

try {

    # Helper function to connect to SharePoint with managed identity or interactive login
    # This function detects the execution context:
    # - In Azure Automation ($PSPrivateMetadata exists): Uses managed identity authentication
    # - Outside Azure Automation: Uses interactive login with delegated permissions
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
            Write-Output "Using managed identity authentication for $Url"
            $PnpParams.Add("ManagedIdentity", $true)
        }
        else {
            # Local/interactive context - use interactive login with delegated permissions
            Write-Output "Using interactive login for $Url"
            if ($ClientId) {
                $PnpParams.Add("ClientId", $ClientId)
            }
        }

        Connect-PnPOnline @PnpParams
    }

    # Connect to Hub site to download template
    Connect-SharePoint -Url $HubSiteUrl

    $TempDir = [string]([System.IO.Path]::GetTempPath()).TrimEnd('\', '/')
    $FileName = [string]([System.IO.Path]::GetFileName($TemplatePath))
    
    Get-PnPFile -Url $TemplatePath -Path $TempDir -FileName $FileName -AsFile -Force | Out-Null
    $LocalPath = Join-Path $TempDir $FileName

    if (-not (Test-Path $LocalPath)) {
        throw "Failed to download template from $TemplatePath"
    }

    $AbsoluteTemplateUrl = "$HubSiteUrl$TemplatePath"
    Write-Output "Lastet ned mal: $AbsoluteTemplateUrl"

    # Parse tokens in PPTX
    Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null

    function Find-TokensInPptx {
        param([string]$PptxPath)
    
        $TempFolder = [string](Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString()))
        try {
            [System.IO.Compression.ZipFile]::ExtractToDirectory($PptxPath, $TempFolder)
        
            $FoundTokens = @()
            $XmlFiles = Get-ChildItem -Path $TempFolder -Recurse -Include *.xml
        
            foreach ($File in $XmlFiles) {
                $Content = Get-Content -LiteralPath $File.FullName -Raw
            
                # Extract all <a:t> text elements and concatenate them to find tokens
                $TextElements = [regex]::Matches($Content, '<a:t>([^<]*)</a:t>')
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

    function Replace-TokensInPptx {
        param([string]$PptxPath, [hashtable]$TokenMap)

        $TempFolder = [string](Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString()))
        [System.IO.Compression.ZipFile]::ExtractToDirectory($PptxPath, $TempFolder)

        # Extract slide dimensions from presentation.xml
        $PresentationXml = Join-Path $TempFolder "ppt\presentation.xml"
        $SlideWidth = 9144000  # Default for 16:9
        if (Test-Path $PresentationXml) {
            $PresContent = Get-Content -LiteralPath $PresentationXml -Raw
            if ($PresContent -match '<p:sldSz[^>]*cx="(\d+)"') {
                $SlideWidth = [int]$matches[1]
            }
        }

        $XmlFiles = Get-ChildItem -Path $TempFolder -Recurse -Include *.xml
    
        foreach ($File in $XmlFiles) {
            $Content = Get-Content -LiteralPath $File.FullName -Raw
            $OriginalContent = $Content
        
            foreach ($Key in $TokenMap.Keys) {
                # Check if token exists in concatenated text (handles split tokens)
                $TextElements = [regex]::Matches($Content, '<a:t>([^<]*)</a:t>')
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
                    
                    # Find the shape (text box) containing this token
                    $ShapePattern = '(?s)<p:sp>.*?</p:sp>'
                    $AllShapes = [regex]::Matches($Content, $ShapePattern)
                    
                    $FoundShape = $null
                    $ShapeXfrm = $null
                    
                    foreach ($Shape in $AllShapes) {
                        $ShapeText = [regex]::Matches($Shape.Value, '<a:t>([^<]*)</a:t>') | 
                                     ForEach-Object { $_.Groups[1].Value } | 
                                     ForEach-Object { $_ -join '' }
                        $ShapeTextCombined = $ShapeText -join ''
                        
                        if ($ShapeTextCombined -match [regex]::Escape($Key)) {
                            $FoundShape = $Shape.Value
                            # Extract position and size from shape's transform
                            if ($FoundShape -match '(?s)<p:spPr>.*?<a:xfrm>(.*?)</a:xfrm>') {
                                $ShapeXfrm = $matches[1]
                            }
                            break
                        }
                    }
                    
                    if ($FoundShape -and $ShapeXfrm) {
                        # Use custom or default percentage of actual slide width for the table
                        $TableWidth = [int]($SlideWidth * $CustomTableWidthRatio)
                        
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
                        
                        # Center the table 
                        $XOffset = [int](($SlideWidth - $TableWidth) / 2)
                        
                        # Extract Y position from original shape, or use default
                        if ($ShapeXfrm -match '<a:off[^>]*y="(\d+)"') {
                            $YOffset = $matches[1]
                        } else {
                            $YOffset = 1000000  # Default Y position
                        }
                        
                        # Calculate table height based on number of rows
                        $RowHeight = 370840
                        $TableHeight = $RowHeight * $Rows.Count
                        
                        # Build table grid (column definitions)
                        $GridCols = ""
                        for ($i = 0; $i -lt $ColumnCount; $i++) {
                            $GridCols += "<a:gridCol w=`"$($ColumnWidthArray[$i])`"/>"
                        }
                        
                        # Build table rows
                        $TableRows = ""
                        foreach ($RowData in $Rows) {
                            $Cells = $RowData -split "`t"
                            $TableCells = ""
                            
                            foreach ($CellValue in $Cells) {
                                $EscapedCell = [System.Security.SecurityElement]::Escape($CellValue)
                                $TableCells += @"
<a:tc><a:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr lang="nb-NO" sz="1200"/><a:t>$EscapedCell</a:t></a:r></a:p></a:txBody><a:tcPr/></a:tc>
"@
                            }
                            
                            $TableRows += "<a:tr h=`"370840`">$TableCells</a:tr>"
                        }
                        
                        # Create new graphic frame with table
                        $NewGraphicFrame = $FoundShape -replace '(?s)<p:sp>(.*?)</p:sp>', @"
<p:graphicFrame>
<p:nvGraphicFramePr>
<p:cNvPr id="999" name="GeneratedTable"/>
<p:cNvGraphicFramePr><a:graphicFrameLocks noGrp="1"/></p:cNvGraphicFramePr>
<p:nvPr/>
</p:nvGraphicFramePr>
<p:xfrm>
<a:off x="$XOffset" y="$YOffset"/>
<a:ext cx="$TableWidth" cy="$TableHeight"/>
</p:xfrm>
<a:graphic>
<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table">
<a:tbl>
<a:tblPr firstRow="1" bandRow="1">
<a:tableStyleId>{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}</a:tableStyleId>
</a:tblPr>
<a:tblGrid>$GridCols</a:tblGrid>
$TableRows
</a:tbl>
</a:graphicData>
</a:graphic>
</p:graphicFrame>
"@
                        
                        $Content = $Content.Replace($FoundShape, $NewGraphicFrame)
                    }
                    continue
                }
            
                # For simple text replacement - find and replace split tokens
                # Find all paragraphs and check which one contains the token
                $ParagraphPattern = '(?s)<a:p[^>]*>.*?</a:p>'
                $AllParagraphs = [regex]::Matches($Content, $ParagraphPattern)
            
                $FoundParagraph = $null
                foreach ($Para in $AllParagraphs) {
                    # Extract text from this paragraph and check if it contains the token
                    $ParaTextMatches = [regex]::Matches($Para.Value, '<a:t>([^<]*)</a:t>')
                    $ParaText = ($ParaTextMatches | ForEach-Object { $_.Groups[1].Value }) -join ''
                
                    if ($ParaText -match [regex]::Escape($Key)) {
                        $FoundParagraph = $Para.Value
                        break
                    }
                }
            
                if ($FoundParagraph) {
                    # Extract text from all <a:t> elements in the paragraph
                    $TextMatches = [regex]::Matches($FoundParagraph, '<a:t>([^<]*)</a:t>')
                    $ParagraphText = ($TextMatches | ForEach-Object { $_.Groups[1].Value }) -join ''
                
                    # Replace the token in the concatenated text
                    $NewText = $ParagraphText -replace [regex]::Escape($Key), [System.Security.SecurityElement]::Escape($Value)
                
                    # Find the first <a:r> element to preserve its properties
                    $FirstRunMatch = [regex]::Match($FoundParagraph, '<a:r>(?<props><a:rPr.*?</a:rPr>)?<a:t>')
                    $RunProps = if ($FirstRunMatch.Success -and $FirstRunMatch.Groups['props'].Success) {
                        $FirstRunMatch.Groups['props'].Value
                    } else {
                        '<a:rPr lang="nb-NO" sz="1200"/>'
                    }
                    
                    # Get the paragraph part before first <a:r>
                    $BeforeRuns = $FoundParagraph -replace '(<a:r>.*$)', ''
                    # Get the paragraph part after last </a:r>
                    $AfterRuns = $FoundParagraph -replace '(^.*</a:r>)', ''
                    # Create new paragraph with single text run, preserving original properties
                    $NewParagraph = $BeforeRuns + "<a:r>$RunProps<a:t>$NewText</a:t></a:r>" + $AfterRuns
                
                    $Content = $Content.Replace($FoundParagraph, $NewParagraph)
                }
            }
        
            if ($Content -ne $OriginalContent) {
                Set-Content -LiteralPath $File.FullName -Value $Content -Encoding utf8NoBOM | Out-Null
            }
        }

        $NewPptx = [string]([System.IO.Path]::ChangeExtension($PptxPath, ".out.pptx"))
        if (Test-Path $NewPptx) { Remove-Item $NewPptx -Force | Out-Null }
        
        # Create ZIP with optimal compression for Office files
        [System.IO.Compression.ZipFile]::CreateFromDirectory($TempFolder, $NewPptx, [System.IO.Compression.CompressionLevel]::Optimal, $false) | Out-Null
        
        Remove-Item $TempFolder -Recurse -Force | Out-Null
        return $NewPptx
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
                    0.95  # Default to 95% of slide width
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
                    $TableText = ($Lines -join "`n")
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
    $TokensFound = Find-TokensInPptx -PptxPath $LocalPath
    $TokenMap = Get-TokenMap -ProjectUrl $ProjectUrl -Tokens $TokensFound
    $NewPptx = Replace-TokensInPptx -PptxPath $LocalPath -TokenMap $TokenMap

    # Upload the generated PPTX back to the project's document library
    Connect-SharePoint -Url $ProjectUrl | Out-Null

    $BaseFileName = [string](Split-Path $TemplatePath -LeafBase)
    $FileName = "{0}_{1:yyMMddHHmmss}.pptx" -f $BaseFileName, (Get-Date)
    Add-PnPFile -Path $NewPptx -Folder $TargetFolder -NewFileName $FileName | Out-Null
    
    $FileUrl = "/$TargetFolder/$FileName"
    Write-Output "Lastet opp generert dokument til $FileUrl"

    # Clean up temporary files
    if (Test-Path $NewPptx) { Remove-Item $NewPptx -Force -ErrorAction SilentlyContinue }
    if (Test-Path $LocalPath) { Remove-Item $LocalPath -Force -ErrorAction SilentlyContinue }

}
catch {
    Write-Error "Runbook failed: $_"
    # Clean up temporary files on error
    if ($NewPptx -and (Test-Path $NewPptx)) { Remove-Item $NewPptx -Force -ErrorAction SilentlyContinue }
    if ($LocalPath -and (Test-Path $LocalPath)) { Remove-Item $LocalPath -Force -ErrorAction SilentlyContinue }
    throw
}
