param(
    [Parameter(Mandatory=$true)] [string]$projectUrl,
    [Parameter(Mandatory=$true)] [string]$templatePath,
    [Parameter(Mandatory=$true)] [string]$hubSiteUrl,
    [string]$requestedBy = "System"
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
    
    $pnpParams = @{ 
        Url = $Url
    }
    
    if ($null -ne $PSPrivateMetadata) {
        # Azure Automation runbook context - use managed identity
        Write-Output "Using managed identity authentication for $Url"
        $pnpParams.Add("ManagedIdentity", $true)
    }
    else {
        # Fallback to ClientId/Secret from Automation variables
        # Note: This requires running in an Azure Automation context
        try {
            $clientId = Get-AutomationVariable -Name "ClientId"
            $clientSecret = Get-AutomationVariable -Name "ClientSecret"
            Write-Output "Using ClientId/Secret authentication for $Url"
            $pnpParams.Add("ClientId", $clientId)
            $pnpParams.Add("ClientSecret", $clientSecret)
        }
        catch {
            Write-Error "Failed to retrieve authentication variables. This script must run in Azure Automation context."
            throw
        }
    }

    Connect-PnPOnline @pnpParams
}

# Connect to project site
Connect-SharePoint -Url $projectUrl
Write-Output "Koblet til $projectUrl"

# Connect to Hub site to download template
Connect-SharePoint -Url $hubSiteUrl

$tempDir = [System.IO.Path]::GetTempPath()
$fileName = Split-Path $templatePath -Leaf
Get-PnPFile -Url $templatePath -Path $tempDir -FileName $fileName -AsFile -Force
$localPath = Join-Path $tempDir $fileName
Write-Output "Lastet ned mal: $templatePath"

# Parse tokens in PPTX
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Find-TokensInPptx {
    param([string]$pptxPath)
    
    $tempFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($pptxPath, $tempFolder)
        
        $foundTokens = @()
        $xmlFiles = Get-ChildItem -Path $tempFolder -Recurse -Include *.xml
        
        foreach ($file in $xmlFiles) {
            $content = Get-Content -LiteralPath $file.FullName -Raw
            
            # Extract all <a:t> text elements and concatenate them to find tokens
            $textElements = [regex]::Matches($content, '<a:t>([^<]*)</a:t>')
            $concatenatedText = ($textElements | ForEach-Object { $_.Groups[1].Value }) -join ''
            
            # Find all tokens in the concatenated text
            $matches = [regex]::Matches($concatenatedText, '\{\{([^}]+)\}\}')
            
            foreach ($match in $matches) {
                $fullToken = $match.Value
                
                if ($foundTokens -notcontains $fullToken) {
                    $foundTokens += $fullToken
                }
            }
        }
    }
    finally {
        # Clean up temp folder
        Remove-Item $tempFolder -Recurse -Force
    }
    
    return $foundTokens
}

function Replace-TokensInPptx {
    param([string]$pptxPath, [hashtable]$tokenMap)

    $tempFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    [System.IO.Compression.ZipFile]::ExtractToDirectory($pptxPath, $tempFolder)

    $xmlFiles = Get-ChildItem -Path $tempFolder -Recurse -Include *.xml
    
    foreach ($file in $xmlFiles) {
        $content = Get-Content -LiteralPath $file.FullName -Raw
        $originalContent = $content
        
        foreach ($key in $tokenMap.Keys) {
            # Check if token exists in concatenated text (handles split tokens)
            $textElements = [regex]::Matches($content, '<a:t>([^<]*)</a:t>')
            $concatenatedText = ($textElements | ForEach-Object { $_.Groups[1].Value }) -join ''
            
            if ($concatenatedText -notmatch [regex]::Escape($key)) {
                continue
            }
            
            $value = $tokenMap[$key]
            $replacementCount = 0
            
            # Special handling for table data - only if there are multiple fields (tabs) AND multiple rows
            # Single field tokens should be treated as plain text
            if ($value -match "`t" -and $value -match "`n") {
                # Validate that all rows have the same number of columns (tab-separated values)
                $rows = $value -split "`n"
                $columnCounts = @()
                foreach ($row in $rows) {
                    # Remove any trailing carriage return for Windows line endings
                    $cleanRow = $row.TrimEnd("`r")
                    if ($cleanRow -eq "") { continue }
                    $columns = $cleanRow -split "`t"
                    $columnCounts += @($columns.Count)
                }
                $uniqueColumnCounts = $columnCounts | Select-Object -Unique
                if ($uniqueColumnCounts.Count -ne 1) {
                    Write-Warning "Token '$key' value does not have consistent column counts per row. Treating as plain text."
                    # Fallback to plain text replacement
                    $content = $content -replace [regex]::Escape($key), [regex]::Escape($value)
                    continue
                }
                # Find the table row containing this token by searching for <a:tr> containing the concatenated text
                # Use a simpler pattern that looks for any part of the token text
                $rowPattern = '(?s)<a:tr[^>]*>.*?</a:tr>'
                $allRows = [regex]::Matches($content, $rowPattern)
                
                $templateRow = $null
                foreach ($row in $allRows) {
                    # Extract text from this row and check if it contains the token
                    $rowTextMatches = [regex]::Matches($row.Value, '<a:t>([^<]*)</a:t>')
                    $rowText = ($rowTextMatches | ForEach-Object { $_.Groups[1].Value }) -join ''
                    
                    if ($rowText -match [regex]::Escape($key)) {
                        $templateRow = $row.Value
                        break
                    }
                }
                
                if ($templateRow) {
                    
                    $lines = $value -split "`n"
                    $newRows = @()
                    
                    foreach ($line in $lines) {
                        # Skip truly empty lines, but keep lines with just tabs (empty cells)
                        if ($line -eq '') { continue }
                        
                        $cells = $line -split "`t"
                        $newRow = $templateRow
                        
                        # Extract all table cells (<a:tc>) from the row
                        $cellMatches = [regex]::Matches($newRow, '(?s)<a:tc>.*?</a:tc>')
                        
                        # Replace each table cell's text with corresponding cell data
                        $offset = 0
                        for ($i = 0; $i -lt [Math]::Min($cells.Count, $cellMatches.Count); $i++) {
                            $escapedCell = [System.Security.SecurityElement]::Escape($cells[$i])
                            $oldCell = $cellMatches[$i].Value
                            
                            # Replace ALL text in the cell with new value
                            # Find all <a:r> elements and replace them with a single new one
                            if ($oldCell -match '<a:r>') {
                                # Get the paragraph part before first <a:r>
                                $beforeRuns = $oldCell -replace '(<a:r>.*$)', ''
                                # Get the paragraph part after last </a:r>
                                $afterRuns = $oldCell -replace '(^.*</a:r>)', ''
                                # Create new cell with single text run
                                $newCell = $beforeRuns + "<a:r><a:rPr/><a:t>$escapedCell</a:t></a:r>" + $afterRuns
                            } elseif ($oldCell -match '<a:p>') {
                                # Cell has paragraph but no text runs, add one
                                $newCell = $oldCell -replace '(<a:p[^>]*>)', "`$1<a:r><a:rPr/><a:t>$escapedCell</a:t></a:r>"
                            } else {
                                # Shouldn't happen, but keep original
                                $newCell = $oldCell
                            }
                            
                            # Find and replace in the newRow using index to handle multiple identical cells
                            $cellIndex = $newRow.IndexOf($oldCell, $offset)
                            if ($cellIndex -ge 0) {
                                $newRow = $newRow.Remove($cellIndex, $oldCell.Length).Insert($cellIndex, $newCell)
                                $offset = $cellIndex + $newCell.Length
                            }
                        }
                        $newRows += $newRow
                    }
                    
                    $content = $content.Replace($templateRow, ($newRows -join "`n"))
                }
                continue
            }
            
            # For simple text replacement - find and replace split tokens
            # Find all paragraphs and check which one contains the token
            $paragraphPattern = '(?s)<a:p[^>]*>.*?</a:p>'
            $allParagraphs = [regex]::Matches($content, $paragraphPattern)
            
            $foundParagraph = $null
            foreach ($para in $allParagraphs) {
                # Extract text from this paragraph and check if it contains the token
                $paraTextMatches = [regex]::Matches($para.Value, '<a:t>([^<]*)</a:t>')
                $paraText = ($paraTextMatches | ForEach-Object { $_.Groups[1].Value }) -join ''
                
                if ($paraText -match [regex]::Escape($key)) {
                    $foundParagraph = $para.Value
                    break
                }
            }
            
            if ($foundParagraph) {
                # Extract text from all <a:t> elements in the paragraph
                $textMatches = [regex]::Matches($foundParagraph, '<a:t>([^<]*)</a:t>')
                $paragraphText = ($textMatches | ForEach-Object { $_.Groups[1].Value }) -join ''
                
                # Replace the token in the concatenated text
                $newText = $paragraphText -replace [regex]::Escape($key), [System.Security.SecurityElement]::Escape($value)
                
                # Get the paragraph part before first <a:r>
                $beforeRuns = $foundParagraph -replace '(<a:r>.*$)', ''
                # Get the paragraph part after last </a:r>
                $afterRuns = $foundParagraph -replace '(^.*</a:r>)', ''
                # Create new paragraph with single text run
                $newParagraph = $beforeRuns + "<a:r><a:rPr/><a:t>$newText</a:t></a:r>" + $afterRuns
                
                $content = $content.Replace($foundParagraph, $newParagraph)
            }
        }
        
        if ($content -ne $originalContent) {
            Set-Content -LiteralPath $file.FullName -Value $content -Encoding UTF8
        }
    }

    $newPptx = [System.IO.Path]::ChangeExtension($pptxPath, ".out.pptx")
    if (Test-Path $newPptx) { Remove-Item $newPptx -Force }
    [System.IO.Compression.ZipFile]::CreateFromDirectory($tempFolder, $newPptx)
    Remove-Item $tempFolder -Recurse -Force
    return $newPptx
}

# Fetch data from project and build token map from SharePoint lists
function Get-TokenMap {
    param($projectUrl, $tokens)

    Connect-SharePoint -Url $projectUrl
    $map = @{}

    foreach ($token in $tokens) {
        # Parse token format: {{List:ListName;Fields:Field1,Field2,Field3}}
        if ($token -match '\{\{List:([^;]+);Fields:([^}]+)\}\}') {
            $listName = $matches[1]
            $fields = $matches[2] -split ','
            
            # Fetch data from SharePoint list
            $rows = Get-PnPListItem -List $listName -Fields $fields
            $lines = @()
            
            foreach ($r in $rows) {
                $cellValues = @()
                foreach ($field in $fields) {
                    $value = $r.FieldValues[$field]
                    
                    $extractedValue = ""
                    if ($null -eq $value -or $value -eq "") {
                        $extractedValue = ""
                    } elseif ($value -is [Microsoft.SharePoint.Client.FieldLookupValue]) {
                        # Single lookup value
                        $extractedValue = $value.LookupValue
                    } elseif ($value -is [Array] -and $value.Count -gt 0 -and $value[0] -is [Microsoft.SharePoint.Client.FieldLookupValue]) {
                        # Array of lookup values - join them with comma
                        $extractedValue = ($value | ForEach-Object { $_.LookupValue }) -join ", "
                    } else {
                        $extractedValue = "$value"
                    }
                    
                    $cellValues += $extractedValue
                }
                
                # If only one field, just use the value; otherwise tab-separate
                if ($fields.Count -eq 1) {
                    $lines += $cellValues[0]
                } else {
                    $lineText = ($cellValues -join "`t")
                    $lines += $lineText
                }
            }
            
            # If only one field, join with newlines (plain text list); otherwise create table format
            if ($fields.Count -eq 1) {
                $map[$token] = ($lines -join "`n")
            } else {
                $tableText = ($lines -join "`n")
                $map[$token] = $tableText
            }
        } else {
            $map[$token] = ""
        }
    }

    return $map
}

# Find all tokens in the template
$tokensFound = Find-TokensInPptx -pptxPath $localPath
$tokenMap = Get-TokenMap -projectUrl $projectUrl -tokens $tokensFound

$newPptx = Replace-TokensInPptx -pptxPath $localPath -tokenMap $tokenMap

# Upload the generated PPTX back to the project's document library
Connect-SharePoint -Url $projectUrl

$targetFolder = "Delte dokumenter/Styringsdokumenter"
$fileName = ("{0}_{1:yyMMdd}.pptx" -f (Split-Path $templatePath -LeafBase), (Get-Date))
Add-PnPFile -Path $newPptx -Folder $targetFolder -NewFileName $fileName
Write-Output "Lastet opp $fileName til $targetFolder"
