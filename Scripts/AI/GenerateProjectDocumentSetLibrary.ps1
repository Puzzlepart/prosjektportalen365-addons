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

$Prompt = "Gi meg $PromptMaxElements ulike eksempler på dokumentsett i dokumentbiblioteket '$ListTitle' for et prosjekt som heter '$SiteTitle'. $AdditionalPrompt VIKTIG: Returner elementene som en ren JSON array - outputen din skal starte med '[' og avsluttes med ']'. Ikke ta med markdown formatering eller annen formatering. Feltene er følgende: $FieldPrompt. Verdien i tittel-feltet skal være unikt, det skal si noe om hva dokumentsettet handler om, og skal ikke være det samme som prosjektnavnet. Bruk internnavnene på feltene i JSON-objektet nøyaktig - ikke legg på for eksempel Id på slutten av et internt feltnavn. "
    
Write-Output "`tPrompt ready. Asking for suggestions from $($OpenAISettings.model_name)..."

$GeneratedItems = Get-OpenAIResults -Prompt $Prompt -ForceArray -openai $OpenAISettings

$count = 0
$GeneratedItems.items | ForEach-Object {
    $DocSetTitle = $_.Title
    if ($null -eq $DocSetTitle -or "" -eq $DocSetTitle) {
        $DocSetTitle = ($ListTitle + " " + ++$count)
    }
    Write-Output "`t`tCreating document set '$DocSetTitle' in library '$ListTitle'"

    $HashtableValues = ConvertPSObjectToHashtable -InputObject $_
    # Remove Title since it is used as the document set folder name
    $HashtableValues.Remove("Title")
    @($HashtableValues.keys) | ForEach-Object { 
        if (-not $HashtableValues[$_]) { $HashtableValues.Remove($_) } 
    }

    try {
        # Create the document set in the library
        $DocSetFolder = Add-PnPDocumentSet -List $ListTitle -Name $DocSetTitle -ContentType $ContentTypeName

        # Set field values on the created document set
        if ($HashtableValues.Count -gt 0) {
            $DocSetItem = Get-PnPListItem -List $ListTitle -Query "<View><Query><Where><Eq><FieldRef Name='FileLeafRef'/><Value Type='Text'>$DocSetTitle</Value></Eq></Where></Query></View>"
            if ($null -ne $DocSetItem) {
                $ItemId = if ($DocSetItem -is [array]) { $DocSetItem[0].Id } else { $DocSetItem.Id }
                Set-PnPListItem -List $ListTitle -Identity $ItemId -Values $HashtableValues | Out-Null
                Write-Output "`t`t`tField values set on document set '$DocSetTitle'"
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
