param($OpenAISettings, [string]$SiteTitle, [string]$SiteId, [string]$HubSiteUrl, [string]$AdditionalPrompt, [string]$ProjectStatusContentTypeId)

. .\CommonPPAI.ps1

try {
    Write-Output "`tProcessing project status report in hub site. Generating prompt based on list configuration..."
    Connect-SharePoint -Url $HubSiteUrl

    $FieldPrompt = Get-FieldPromptForList -ListTitle "Prosjektstatus" -ContentTypeId $ProjectStatusContentTypeId
        
    $Prompt = "Gi meg et eksempel på rapportering av Prosjektstatus for et prosjekt som heter '$SiteTitle'. $AdditionalPrompt VIKTIG: Returner elementene som et JSON objekt. Ikke ta med markdown formatering eller annen formatering. Feltene er følgende: $FieldPrompt. Verdien i tittel-feltet skal være 'Ny statusrapport for $SiteTitle'. Bruk internnavnene på feltene i JSON-objektet nøyaktig - ikke legg på for eksempel Id på slutten av et internt feltnavn."
        
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
            Write-Output "`t`tList item created successfully with ID: $($ItemResult.Id)"
        }
        catch {
            Write-Output "Failed to create list item for list 'Prosjektstatus'"
            Write-Output $_.Exception.Message
            Write-Output "Using the following prompt: $Prompt"
            Write-Output "Using the following values as input:"
            $HashtableValues.GetEnumerator() | Sort-Object Name | ForEach-Object {
                Write-Output "`t$($_.Key): $($_.Value) (Type: $($_.Value.GetType().Name))"
            }
        }
    }
    
}
catch {
    Write-Output "Failed to process project status report in hub site."
    Write-Output $_.Exception.Message
}
