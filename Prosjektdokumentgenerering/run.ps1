###
# How to start runbook from local context:
# Start-AzAutomationRunbook -ResourceGroupName "Prosjektportalen" -AutomationAccountName "Prosjektportalen-Premium-Account" -Name "ProjectDocumentGeneration" -Parameters @{ProjectUrl="https://puzzlepart.sharepoint.com/sites/Vino001";TemplatePath="/sites/pp-vmp/Dokumentgenereringsmaler/MAL_Styringsdokument.pptx";HubSiteUrl="https://puzzlepart.sharepoint.com/sites/pp-vmp"}
param(
    [Parameter(Mandatory=$true)] [string]$ProjectUrl,
    [Parameter(Mandatory=$true)] [string]$TemplatePath,
    [Parameter(Mandatory=$true)] [string]$HubSiteUrl
)

# Helper function to connect to SharePoint with managed identity or ClientId/Secret
# This function detects the execution context:
# - In Azure Automation ($PSPrivateMetadata exists): Uses managed identity authentication
# - Outside Azure Automation: Uses ClientId/Secret from Automation variables (requires Azure Automation context)
function Connect-SharePoint {
    param(
        [Parameter(Mandatory=$true)]
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
        # Fallback to ClientId/Secret from Automation variables
        # Note: This requires running in an Azure Automation context
        try {
            $ClientId = Get-AutomationVariable -Name "ClientId"
            $ClientSecret = Get-AutomationVariable -Name "ClientSecret"
            Write-Output "Using ClientId/Secret authentication for $Url"
            $PnpParams.Add("ClientId", $ClientId)
            $PnpParams.Add("ClientSecret", $ClientSecret)
        }
        catch {
            Write-Error "Failed to retrieve authentication variables. This script must run in Azure Automation context."
            throw
        }
    }

    Connect-PnPOnline @PnpParams
}

# Connect to Hub site to download template
Connect-SharePoint -Url $HubSiteUrl

$TempDir = [System.IO.Path]::GetTempPath()
$FileName = Split-Path $TemplatePath -Leaf
Get-PnPFile -Url $TemplatePath -Path $TempDir -FileName $FileName -AsFile -Force | Out-Null
$LocalPath = Join-Path $TempDir $FileName
Write-Output "Lastet ned mal: $TemplatePath"

# Parse tokens in PPTX
Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null

function Find-TokensInPptx {
    param([string]$PptxPath)
    
    $TempFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
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

    $TempFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    [System.IO.Compression.ZipFile]::ExtractToDirectory($PptxPath, $TempFolder)

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
            $ReplacementCount = 0
            
            # Special handling for table data - only if there are multiple fields (tabs) AND multiple rows
            # Single field tokens should be treated as plain text
            if ($Value -match "`t" -and $Value -match "`n") {
                # Validate that all rows have the same number of columns (tab-separated values)
                $Rows = $Value -split "`n"
                $ColumnCounts = @()
                foreach ($Row in $Rows) {
                    # Remove any trailing carriage return for Windows line endings
                    $CleanRow = $Row.TrimEnd("`r")
                    if ($CleanRow -eq "") { continue }
                    $Columns = $CleanRow -split "`t"
                    $ColumnCounts += @($Columns.Count)
                }
                $UniqueColumnCounts = $ColumnCounts | Select-Object -Unique
                if ($UniqueColumnCounts.Count -ne 1) {
                    Write-Warning "Token '$Key' value does not have consistent column counts per row. Treating as plain text."
                    # Fallback to plain text replacement
                    $Content = $Content -replace [regex]::Escape($Key), [regex]::Escape($Value)
                    continue
                }
                # Find the table row containing this token by searching for <a:tr> containing the concatenated text
                # Use a simpler pattern that looks for any part of the token text
                $RowPattern = '(?s)<a:tr[^>]*>.*?</a:tr>'
                $AllRows = [regex]::Matches($Content, $RowPattern)
                
                $TemplateRow = $null
                foreach ($Row in $AllRows) {
                    # Extract text from this row and check if it contains the token
                    $RowTextMatches = [regex]::Matches($Row.Value, '<a:t>([^<]*)</a:t>')
                    $RowText = ($RowTextMatches | ForEach-Object { $_.Groups[1].Value }) -join ''
                    
                    if ($RowText -match [regex]::Escape($Key)) {
                        $TemplateRow = $Row.Value
                        break
                    }
                }
                
                if ($TemplateRow) {
                    
                    $Lines = $Value -split "`n"
                    $NewRows = @()
                    
                    foreach ($Line in $Lines) {
                        # Skip truly empty lines, but keep lines with just tabs (empty cells)
                        if ($Line -eq '') { continue }
                        
                        $Cells = $Line -split "`t"
                        $NewRow = $TemplateRow
                        
                        # Extract all table cells (<a:tc>) from the row
                        $CellMatches = [regex]::Matches($NewRow, '(?s)<a:tc>.*?</a:tc>')
                        
                        # Replace each table cell's text with corresponding cell data
                        $Offset = 0
                        for ($I = 0; $I -lt [Math]::Min($Cells.Count, $CellMatches.Count); $I++) {
                            $EscapedCell = [System.Security.SecurityElement]::Escape($Cells[$I])
                            $OldCell = $CellMatches[$I].Value
                            
                            # Replace ALL text in the cell with new value
                            # Find all <a:r> elements and replace them with a single new one
                            if ($OldCell -match '<a:r>') {
                                # Get the paragraph part before first <a:r>
                                $BeforeRuns = $OldCell -replace '(<a:r>.*$)', ''
                                # Get the paragraph part after last </a:r>
                                $AfterRuns = $OldCell -replace '(^.*</a:r>)', ''
                                # Create new cell with single text run
                                $NewCell = $BeforeRuns + "<a:r><a:rPr/><a:t>$EscapedCell</a:t></a:r>" + $AfterRuns
                            } elseif ($OldCell -match '<a:p>') {
                                # Cell has paragraph but no text runs, add one
                                $NewCell = $OldCell -replace '(<a:p[^>]*>)', "`$1<a:r><a:rPr/><a:t>$EscapedCell</a:t></a:r>"
                            } else {
                                # Shouldn't happen, but keep original
                                $NewCell = $OldCell
                            }
                            
                            # Find and replace in the newRow using index to handle multiple identical cells
                            $CellIndex = $NewRow.IndexOf($OldCell, $Offset)
                            if ($CellIndex -ge 0) {
                                $NewRow = $NewRow.Remove($CellIndex, $OldCell.Length).Insert($CellIndex, $NewCell)
                                $Offset = $CellIndex + $NewCell.Length
                            }
                        }
                        $NewRows += $NewRow
                    }
                    
                    $Content = $Content.Replace($TemplateRow, ($NewRows -join "`n"))
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
                
                # Get the paragraph part before first <a:r>
                $BeforeRuns = $FoundParagraph -replace '(<a:r>.*$)', ''
                # Get the paragraph part after last </a:r>
                $AfterRuns = $FoundParagraph -replace '(^.*</a:r>)', ''
                # Create new paragraph with single text run
                $NewParagraph = $BeforeRuns + "<a:r><a:rPr/><a:t>$NewText</a:t></a:r>" + $AfterRuns
                
                $Content = $Content.Replace($FoundParagraph, $NewParagraph)
            }
        }
        
        if ($Content -ne $OriginalContent) {
            Set-Content -LiteralPath $File.FullName -Value $Content -Encoding UTF8 | Out-Null
        }
    }

    $NewPptx = [System.IO.Path]::ChangeExtension($PptxPath, ".out.pptx")
    if (Test-Path $NewPptx) { Remove-Item $NewPptx -Force | Out-Null }
    [System.IO.Compression.ZipFile]::CreateFromDirectory($TempFolder, $NewPptx) | Out-Null
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
        
        # Parse token format: {{List:ListName;Fields:Field1,Field2,Field3}}
        if ($Token -match '\{\{List:([^;]+);Fields:([^}]+)\}\}') {
            $ListName = $matches[1]
            $Fields = $matches[2] -split ','
            
            # Fetch data from SharePoint list
            $Rows = Get-PnPListItem -List $ListName -Fields $Fields
            $Lines = @()
            
            foreach ($R in $Rows) {
                $CellValues = @()
                foreach ($Field in $Fields) {
                    $Value = $R.FieldValues[$Field]
                    
                    $ExtractedValue = ""
                    if ($null -eq $Value -or $Value -eq "") {
                        $ExtractedValue = ""
                    } elseif ($Value -is [Microsoft.SharePoint.Client.FieldLookupValue]) {
                        # Single lookup value
                        $ExtractedValue = $Value.LookupValue
                    } elseif ($Value -is [Array] -and $Value.Count -gt 0 -and $Value[0] -is [Microsoft.SharePoint.Client.FieldLookupValue]) {
                        # Array of lookup values - join them with comma
                        $ExtractedValue = ($Value | ForEach-Object { $_.LookupValue }) -join ", "
                    } else {
                        $ExtractedValue = "$Value"
                    }
                    
                    $CellValues += $ExtractedValue
                }
                
                # If only one field, just use the value; otherwise tab-separate
                if ($Fields.Count -eq 1) {
                    $Lines += $CellValues[0]
                } else {
                    $LineText = ($CellValues -join "`t")
                    $Lines += $LineText
                }
            }
            
            # If only one field, join with newlines (plain text list); otherwise create table format
            if ($Fields.Count -eq 1) {
                $Map[$Token] = ($Lines -join "`n")
            } else {
                $TableText = ($Lines -join "`n")
                $Map[$Token] = $TableText
            }
        } else {
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

$TargetFolder = "Delte dokumenter/Styringsdokumenter"
$FileName = ("{0}_{1:yyMMdd}.pptx" -f (Split-Path $TemplatePath -LeafBase), (Get-Date))
Add-PnPFile -Path $NewPptx -Folder $TargetFolder -NewFileName $FileName | Out-Null
Write-Output "Lastet opp $FileName til $TargetFolder"
