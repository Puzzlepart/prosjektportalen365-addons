param($OpenAISettings, $Url, $SiteTitle, $ListTitle, $PromptMaxElements, $UsersEmails, $AdditionalPrompt, $ContentTypeName) 

. .\CommonPPAI.ps1

Connect-SharePoint -Url $Url

$Library = Get-PnPList -Identity $ListTitle -ErrorAction SilentlyContinue
if ($null -eq $Library) {
    Write-Output "`tDocument library '$ListTitle' not found on site. Skipping..."
    return
}

Write-Output "`tProcessing document library '$ListTitle'. Generating prompt based on library configuration..."

# Resolve the Document Set content type from the library
if ($null -eq $ContentTypeName -or "" -eq $ContentTypeName) {
    $LibraryContentTypes = Get-PnPContentType -List $ListTitle
    $DocSetContentType = $LibraryContentTypes | Where-Object { $_.Id.StringValue.StartsWith("0x0120D520") } | Select-Object -First 1
    if ($null -eq $DocSetContentType) {
        Write-Output "`tNo Document Set content type found in library '$ListTitle'. Skipping..."
        return
    }
    $ContentTypeName = $DocSetContentType.Name
    Write-Output "`tDiscovered Document Set content type: '$ContentTypeName'"
}
else {
    Write-Output "`tUsing specified Document Set content type: '$ContentTypeName'"
}

$FieldPrompt = Get-FieldPromptForList -ListTitle $ListTitle -UsersEmails $UsersEmails

$Prompt = "Gi meg $PromptMaxElements ulike eksempler på dokumentsett i dokumentbiblioteket '$ListTitle' for et prosjekt som heter '$SiteTitle'. $AdditionalPrompt VIKTIG: Returner elementene som en ren JSON array - outputen din skal starte med '[' og avsluttes med ']'. Ikke ta med markdown formatering eller annen formatering. Feltene er følgende: $FieldPrompt. Verdien i tittel-feltet skal være unikt, det skal si noe om hva dokumentsettet handler om, og skal ikke være det samme som prosjektnavnet. Bruk internnavnene på feltene i JSON-objektet nøyaktig - ikke legg på for eksempel Id på slutten av et internt feltnavn. I tillegg skal hvert objekt ha egenskapen 'Files' som er en liste med 1-3 realistiske filnavn (inkluder filendelse, f.eks. .pdf, .docx eller .xlsx) som passer innholdet i dokumentsettet. Ikke generer innhold til filene, kun filnavn. "
    
Write-Output "`tPrompt ready. Asking for suggestions from $($OpenAISettings.model_name)..."

$GeneratedItems = Get-OpenAIResults -Prompt $Prompt -ForceArray -openai $OpenAISettings

$count = 0
$GeneratedItems.items | ForEach-Object {
    $DocSetTitle = Get-SafeFileName -Name $_.Title
    if ($null -eq $DocSetTitle -or "" -eq $DocSetTitle) {
        $DocSetTitle = ($ListTitle + " " + ++$count)
    }
    Write-Output "`t`tCreating document set '$DocSetTitle' in library '$ListTitle'"

    # 'Files' is an extra AI-provided property (not a list field) - capture it before it is dropped
    $DemoFiles = $_.Files
    $HashtableValues = ConvertPSObjectToHashtable -InputObject $_
    # Remove Title (used as the document set folder name) and Files (not a list field)
    $HashtableValues.Remove("Title")
    $HashtableValues.Remove("Files")
    @($HashtableValues.keys) | ForEach-Object {
        if (-not $HashtableValues[$_]) { $HashtableValues.Remove($_) }
    }

    try {
        # Create the document set in the library
        $DocSetFolder = Add-PnPDocumentSet -List $ListTitle -Name $DocSetTitle -ContentType $ContentTypeName

        # Look up the created document set item (used for field values and as the target folder for files)
        # Escape the title for safe inclusion in the CAML query (e.g. a legal '&' in the name)
        $DocSetTitleXml = [System.Security.SecurityElement]::Escape($DocSetTitle)
        $DocSetItem = Get-PnPListItem -List $ListTitle -Query "<View><Query><Where><Eq><FieldRef Name='FileLeafRef'/><Value Type='Text'>$DocSetTitleXml</Value></Eq></Where></Query></View>"
        if ($DocSetItem -is [array]) { $DocSetItem = $DocSetItem[0] }

        # Set field values on the created document set
        if ($null -ne $DocSetItem -and $HashtableValues.Count -gt 0) {
            Set-PnPListItem -List $ListTitle -Identity $DocSetItem.Id -Values $HashtableValues | Out-Null
            Write-Output "`t`t`tField values set on document set '$DocSetTitle'"
        }

        # Create 1-3 placeholder files (no real content) with realistic names/types in the document set
        $TargetFolder = if ($null -ne $DocSetItem) { $DocSetItem.FieldValues["FileRef"] } else { $DocSetFolder }
        $DemoFiles = @($DemoFiles | ForEach-Object { "$_".Trim() } | Where-Object { $_ } | Select-Object -First 3)
        if ($DemoFiles.Count -lt 1) { $DemoFiles = @("$DocSetTitle.pdf") }
        foreach ($DemoFile in $DemoFiles) {
            $FileName = Get-SafeFileName -Name $DemoFile
            if ([string]::IsNullOrWhiteSpace($FileName)) { continue }
            if ($FileName -notmatch '\.[A-Za-z0-9]{1,5}$') { $FileName = "$FileName.pdf" }
            try {
                Add-PnPFile -Folder $TargetFolder -FileName $FileName -Content " " | Out-Null
                Write-Output "`t`t`tCreated file '$FileName' in document set '$DocSetTitle'"
            }
            catch {
                Write-Output "`t`t`tFailed to create file '$FileName' in document set '$DocSetTitle'"
                Write-Output $_.Exception.Message
            }
        }
    }
    catch {
        Write-Output "Failed to create document set '$DocSetTitle' in library '$ListTitle'"
        Write-Output $_.Exception.Message
        Write-Output "Using the following prompt: $Prompt"
        Write-Output "Using the following values as input:"
        $HashtableValues
    }
}
