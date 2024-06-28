param($OpenAISettings, $SiteTitle, $SiteId, $HubSiteUrl)

. .\CommonPPAI.ps1

try {    
    Write-Output "`tProcessing project timeline items in hub site. Generating prompt based on list configuration..."
    Connect-SharePoint -Url $HubSiteUrl

    $MatchingProjectInHub = Get-PnPListItem -List "Prosjekter" -Query "<View><Query><Where><Eq><FieldRef Name='GtSiteId' /><Value Type='Text'>$SiteId</Value></Eq></Where></Query></View>"
    if ($null -eq $MatchingProjectInHub) {
        Write-Output "`tProject not found in hub site. Skipping project timeline items generation."
        return
    }

    $FieldPrompt = Get-FieldPromptForList -ListTitle "Tidslinjeinnhold" -SkipFields @("GtSiteIdLookup")
        
    $StartDate = $MatchingProjectInHub.FieldValues["GtStartDate"]
    $EndDate = $MatchingProjectInHub.FieldValues["GtEndDate"]
        
    $Prompt = "Gi meg et eksempel på tidslinjeelementer (totalt mellom 10 og 20) for et prosjekt som heter '$SiteTitle'. Prosjektets startdato er $StartDate og sluttdato er $EndDate.  VIKTIG: Returner elementene som et JSON objekt. Ikke ta med markdown formatering eller annen formatering. Feltene er følgende: $FieldPrompt. Verdien i tittel-feltet skal beskrive tidslinjeelementet. Bruk internnavnene på feltene i JSON-objektet nøyaktig - ikke legg på for eksempel Id på slutten av et internt feltnavn."
        
    Write-Output "`tPrompt ready. Asking for suggestions from $($OpenAISettings.model_name)..."
    
    $GeneratedItems = Get-OpenAIResults -Prompt $Prompt -ForceArray -openai $OpenAISettings
    
    $GeneratedItems.items | ForEach-Object {
        Write-Output "`t`tCreating list item '$($_.Title)' for list 'Tidslinjeinnhold'"
        $HashtableValues = ConvertPSObjectToHashtable -InputObject $_
        @($HashtableValues.keys) | ForEach-Object { 
            if (-not $HashtableValues[$_]) { $HashtableValues.Remove($_) } 
        }
        
        $HashtableValues["GtSiteIdLookup"] = $MatchingProjectInHub.Id

        try {
            $ItemResult = Add-PnPListItem -List "Tidslinjeinnhold" -Values $HashtableValues
        }
        catch {
            Write-Output "Failed to create list item for list 'Tidslinjeinnhold'"
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