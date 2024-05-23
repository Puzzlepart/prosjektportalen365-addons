param($OpenAISettings, $Url, $SiteTitle, $ListTitle, $PromptMaxElements, $UsersEmails) 

. .\CommonPPAI.ps1

Connect-SharePoint -Url $Url

Write-Output "`tProcessing list '$ListTitle'. Generating prompt based on list configuration..."
$FieldPrompt = Get-FieldPromptForList -ListTitle $ListTitle -UsersEmails $UsersEmails

$Prompt = "Gi meg $PromptMaxElements ulike eksempler på $ListTitle for et prosjekt som heter '$SiteTitle'. VIKTIG: Returner elementene som en ren JSON array - outputen din skal starte med '[' og avsluttes med ']'. Ikke ta med markdown formatering eller annen formatering. Feltene er følgende: $FieldPrompt. Verdien i tittel-feltet skal være unikt, det skal si noe om hva oppføringen handler om, og skal ikke være det samme som prosjektnavnet. Bruk internnavnene på feltene i JSON-objektet nøyaktig - ikke legg på for eksempel Id på slutten av et internt feltnavn. "
    
Write-Output "`tPrompt ready. Asking for suggestions from $($OpenAISettings.model_name)..."

$GeneratedItems = Get-OpenAIResults -Prompt $Prompt -ForceArray -openai $OpenAISettings

$count = 0
$GeneratedItems.items | ForEach-Object {
    $ListItemTitle = $_.Title
    if ($null -eq $ListItemTitle -or "" -eq $ListItemTitle) {
        $ListItemTitle = ($ListTitle + " " + ++$count)
    }
    Write-Output "`t`tCreating list item '$ListItemTitle' for list '$ListTitle'"
    $HashtableValues = ConvertPSObjectToHashtable -InputObject $_
    @($HashtableValues.keys) | ForEach-Object { 
        if (-not $HashtableValues[$_]) { $HashtableValues.Remove($_) } 
    }
    try {
        $ItemResult = Add-PnPListItem -List $ListTitle -Values $HashtableValues
    }
    catch {
        Write-Output "Failed to create list item for list '$ListTitle'"
        Write-Output $_.Exception.Message
        Write-Output "Using the following prompt: $Prompt"
        Write-Output "Using the following values as input:"
        $HashtableValues
    }
}
