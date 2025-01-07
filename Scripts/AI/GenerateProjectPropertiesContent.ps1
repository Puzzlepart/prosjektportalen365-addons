param($OpenAISettings, $Url, $SiteTitle, $SiteId, $GroupId, $UsersEmails, $HubSiteUrl, $AdditionalPrompt)

. .\CommonPPAI.ps1

Connect-SharePoint -Url $Url
    
$ProjectProperties = Get-PnPListItem -List "Prosjektegenskaper" -Id 1 -ErrorAction SilentlyContinue
if ($null -eq $ProjectProperties) {
    Write-Output "`tProject properties not found. Please create a project properties list item in the Prosjektegenskaper list before running this script."
}
else {
    Write-Output "`tProject properties found. Starting to generate content for project '$SiteTitle'..."
    $FieldPrompt = Get-FieldPromptForList -ListTitle "Prosjektegenskaper" -UsersEmails $UsersEmails
        
    $Prompt = "Gi meg eksempler på Prosjektegenskaper for et prosjekt som heter '$SiteTitle'. $AdditionalPrompt VIKTIG: Returner elementene som et JSON objekt. Ikke ta med markdown formatering eller annen formatering. Feltene er følgende: $FieldPrompt. Verdien i tittel-feltet skal være '$SiteTitle'. Bruk internnavnene på feltene i JSON-objektet nøyaktig - ikke legg på for eksempel Id på slutten av et internt feltnavn."
        
    Write-Output "`tPrompt ready. Asking for suggestions from $($OpenAISettings.model_name)..."

    $GeneratedItems = Get-OpenAIResults -Prompt $Prompt -openai $OpenAISettings

    $GeneratedItems | ForEach-Object {
        Write-Output "`t`tUpdating list item '$($_.Title)' for list 'Prosjektegenskaper'"
        $HashtableValues = ConvertPSObjectToHashtable -InputObject $_
        @($HashtableValues.keys) | ForEach-Object { 
            if (-not $HashtableValues[$_]) { $HashtableValues.Remove($_) } 
        }
        try {
            $ItemResult = Set-PnPListItem -List "Prosjektegenskaper" -Identity 1 -Values $HashtableValues
        }
        catch {
            Write-Output "Failed to update list item 'Prosjektegenskaper'"
            Write-Output $_.Exception.Message
            Write-Output "Using the following prompt: $Prompt"
            Write-Output "Using the following values as input:"
            $HashtableValues
        }
    }

    Write-Output "`tUpdating project properties at hub level"

    $HashtableValues["Title"] = $SiteTitle
    $HashtableValues["GtSiteUrl"] = $Url
    $HashtableValues["GtSiteId"] = $SiteId
    $HashtableValues["GtGroupId"] = $GroupId

    Connect-SharePoint -Url $HubSiteUrl
    $MatchingProjectInHub = Get-PnPListItem -List "Prosjekter" -Query "<View><Query><Where><Eq><FieldRef Name='GtSiteUrl' /><Value Type='Text'>$Url</Value></Eq></Where></Query></View>" -ErrorAction SilentlyContinue
        
    if ($null -ne $MatchingProjectInHub) {
        Write-Output "`t`tUpdating existing project item"
        $HubProject = Set-PnPListItem -List "Prosjekter" -Identity $MatchingProjectInHub -Values $HashtableValues
    }
    else {
        Write-Output "`t`tAdding new project item"
        $HubProject = Add-PnPListItem -List "Prosjekter" -Values $HashtableValues
    }
}