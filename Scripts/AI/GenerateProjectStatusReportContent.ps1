param($OpenAISettings, $SiteTitle, $SiteId, $HubSiteUrl)

. .\CommonPPAI.ps1

try {
    Write-Output "`tProcessing project status report in hub site. Generating prompt based on list configuration..."
    Connect-SharePoint -Url $HubSiteUrl

    $FieldPrompt = Get-FieldPromptForList -ListTitle "Prosjektstatus"
        
    $Prompt = "Gi meg et eksempel på rapportering av Prosjektstatus for et prosjekt som heter '$SiteTitle'. VIKTIG: Returner elementene som et JSON objekt. Ikke ta med markdown formatering eller annen formatering. Feltene er følgende: $FieldPrompt. Verdien i tittel-feltet skal være 'Ny statusrapport for $SiteTitle'. Bruk internnavnene på feltene i JSON-objektet nøyaktig - ikke legg på for eksempel Id på slutten av et internt feltnavn."
        
    Write-Output "`tPrompt ready. Asking for suggestions from $($OpenAISettings.model_name)..."
    
    $GeneratedItems = Get-OpenAIResults -Prompt $Prompt -openai $OpenAISettings
    
    $GeneratedItems | ForEach-Object {
        Write-Output "`t`tCreating list item '$($_.Title)' for list 'Prosjektstatus'"
        $HashtableValues = ConvertPSObjectToHashtable -InputObject $_
        @($HashtableValues.keys) | ForEach-Object { 
            if (-not $HashtableValues[$_]) { $HashtableValues.Remove($_) } 
        }
        
        $HashtableValues["Title"] = "Ny statusrapport for $SiteTitle"
        $HashtableValues["GtSiteId"] = $SiteId
        $HashtableValues["GtModerationStatus"] = "Publisert"
        $HashtableValues["GtLastReportDate"] = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffffff")

        try {
            $ItemResult = Add-PnPListItem -List "Prosjektstatus" -Values $HashtableValues
        }
        catch {
            Write-Output "Failed to create list item for list 'Prosjektstatus'"
            Write-Output $_.Exception.Message
            Write-Output "Using the following prompt: $Prompt"
            Write-Output "Using the following values as input:"
            $HashtableValues
        }
    }
    
}
catch {
    Write-Output "Failed to process project status report in hub site."
    Write-Output $_.Exception.Message
}
