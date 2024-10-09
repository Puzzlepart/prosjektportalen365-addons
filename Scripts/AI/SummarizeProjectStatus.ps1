param($OpenAISettings, $SiteTitle, $SiteId, $HubSiteUrl)

. .\CommonPPAI.ps1

function SummarizeProject($SiteId, $HubSiteUrl) {
    Connect-SharePoint -Url $HubSiteUrl
    $Fields = Get-PnPField -List "Prosjekter"
    $Project = Get-PnPListItem -List "Prosjekter" -Query "<View><Query><Where><Eq><FieldRef Name='GtSiteId' /><Value Type='Text'>$SiteId</Value></Eq></Where><OrderBy><FieldRef Name='ID' /></OrderBy></Query></View>" | Select-Object -First 1

    $Prompt = "Prosjektinformasjon for prosjektet er følgende: "
    $Project.FieldValues.Keys | Where-Object { $_.Contains("Gt") -and $_ -ne "GtSiteId" -and $_ -ne "GtGroupId" -and $_ -ne "GtIsProgram" -and $_ -ne "GtIsParentProject" -and $_ -ne "GtChildProjects" -and $_ -ne "GtProjectAdminRoles" -and $_ -ne "GtInstalledVersion" -and $_ -ne "GtCurrentVersion" -and $_ -ne "GtLastSyncTime" -and $_ -ne "GtSiteUrl" -and $_ -ne "GtBudgetTotal" -and $_ -ne "GtCostsTotal" -and $_ -ne "GtProjectForecast" -and $_ -ne "GtBudgetLastReportDate" -and $_ -ne "GtBAProjectPoliticalLink" -and $_ -ne "GtParentProjects" } | ForEach-Object {
        $InternalName = $_
        if ($Project.FieldValues[$InternalName]) {
            $FieldValue = $Project.FieldValues[$InternalName]
            $Field = $Fields | Where-Object { $_.InternalName -eq $InternalName }
            if ($Field.TypeAsString -eq "User") {                
                $Prompt += "Feltet '$($Field.Title)' har verdien '$($FieldValue.LookupValue)'. "
            }
            elseif ($Field.TypeAsString -eq "UserMulti") {  
                $UsersValue = $FieldValue | ForEach-Object { $_.LookupValue }
                $Prompt += "Feltet '$($Field.Title)' har verdien '$(($UsersValue -join ", ").TrimEnd(", "))'. "
            }
            elseif ($Field.TypeAsString -ne "TaxonomyFieldType" -and $Field.TypeAsString -ne "TaxonomyFieldTypeMulti") {
                $Prompt += "Feltet '$($Field.Title)' har verdien '$($FieldValue)'. "
            }            
        }
    }
    return $Prompt
}

function SummarizeProjectStatus($SiteId, $HubSiteUrl, [switch]$PreviousReport) {

    Connect-SharePoint -Url $HubSiteUrl
    $Fields = Get-PnPField -List "Prosjektstatus"
    $Reports = Get-PnPListItem -List "Prosjektstatus" -Query "<View><Query><Where><And><Eq><FieldRef Name='GtModerationStatus' /><Value Type='Text'>Publisert</Value></Eq><Eq><FieldRef Name='GtSiteId' /><Value Type='Text'>$SiteId</Value></Eq></And></Where></Query></View>" | Sort-Object Id -Descending

    if ($Reports.Count -eq 0) {
        return $null
    }

    if ($PreviousReport.IsPresent) {
        if ($Reports.Count -gt 1) {
            $Report = $Reports | Select-Object -Skip 1 | Select-Object -First 1
        }
        else {
            return $null
        }
    }
    else {
        $Report = $Reports | Select-Object -First 1
    }

    $StatusPrompt = "Verdiene i statusrapporten er følgende: "
    $Report.FieldValues.Keys | Where-Object { $_.Contains("Gt") -and ($_ -ne "GtSiteId" -and $_ -ne "GtModerationStatus" -and $_ -ne "GtLastReportDate" -and -not $_.Contains("GtAi")) } | ForEach-Object {
        $InternalName = $_
        if ($Report.FieldValues[$InternalName]) {
            $Field = $Fields | Where-Object { $_.InternalName -eq $InternalName }
            $StatusPrompt += "Feltet '$($Field.Title)' har verdien '$($Report.FieldValues[$InternalName])'. "
        }
    }
    return @{"Id" = $Report.Id
        "Prompt"  = $StatusPrompt
    }
}


function Ensure-ProjectStatusSummaryColumns($HubSiteUrl) {
    
    Connect-SharePoint -Url $HubSiteUrl

    $AIFields = @(
        @{Name = "GtAiStatusComments"; FieldXml = '<Field Type="Note" DisplayName="Prosjektstatus oppsummert (KI)" Hidden="FALSE" ShowInEditForm="FALSE" ShowInNewForm="FALSE" ShowInDispForm="TRUE" ID="{b4f13c2a-897b-4f68-8854-6da3eb2bf184}" StaticName="GtAiStatusComments" Name="GtAiStatusComments" />' },
        @{Name = "GtAiRecommendations"; FieldXml = '<Field Type="Note" DisplayName="Anbefalinger (KI)" Hidden="FALSE" ShowInEditForm="FALSE" ShowInNewForm="FALSE" ShowInDispForm="TRUE" ID="{3cb8e63c-bd94-4793-af08-efa8b2dcdaaf}" StaticName="GtAiRecommendations" Name="GtAiRecommendations" />' },
        @{Name = "GtAiChangesSincePrev"; FieldXml = '<Field Type="Note" DisplayName="Endringer siden forrige (KI)" Hidden="FALSE" ShowInEditForm="FALSE" ShowInNewForm="FALSE" ShowInDispForm="TRUE" ID="{1cbd1af8-295b-4040-bd7c-426151e0609a}" StaticName="GtAiChangesSincePrev" Name="GtAiChangesSincePrev" />' },
        @{Name = "GtAiStatusScoreNumber"; FieldXml = '<Field Type="Number" DisplayName="Prosjektstatusscore (KI)" Hidden="FALSE" ShowInEditForm="FALSE" ShowInNewForm="FALSE" ShowInDispForm="TRUE" ID="{7453259d-7960-41f2-944f-fbea5830356d}" StaticName="GtAiStatusScoreNumber" Name="GtAiStatusScoreNumber" />' },
        @{Name = "GtAiStatusPosted"; FieldXml = '<Field Type="Choice" DisplayName="Prosjektstatus gjennomgått (KI)" Hidden="FALSE" ShowInEditForm="FALSE" ShowInNewForm="FALSE" ID="{32477351-23be-4b57-9e4a-94f957d3fe8f}" StaticName="GtAiStatusPosted" Name="GtAiStatusPosted" ><CHOICES><CHOICE>Ja</CHOICE><CHOICE>Nei</CHOICE></CHOICES><Default>Nei</Default></Field>' },
        @{Name = "GtAiStatus"; FieldXml = '<Field Type="Choice" DisplayName="Prosjektstatus vurdert (KI)" Hidden="FALSE" ShowInEditForm="FALSE" ShowInNewForm="FALSE" ShowInDispForm="TRUE" ID="{9c90a42d-fc01-4e41-a5ae-5bb8a4433d39}" StaticName="GtAiStatus" Name="GtAiStatus" ><CHOICES><CHOICE>Svak</CHOICE><CHOICE>Tilfredsstillende</CHOICE><CHOICE>God</CHOICE><CHOICE>Prisverdig</CHOICE></CHOICES></Field>' }
    )

    $ProjectStatusList = Get-PnPList -Identity "Prosjektstatus" -ErrorAction SilentlyContinue
    $AIFields | ForEach-Object {
        $AIField = Get-PnPField -Identity $_.Name -ErrorAction SilentlyContinue
        if ($null -eq $AIField) {
            $AIField = Add-PnPFieldFromXml -FieldXml $_.FieldXml
        }
        $AIFieldList = Get-PnPField -List $ProjectStatusList -Identity $_.Name -ErrorAction SilentlyContinue
        if ($null -eq $AIFieldList) {
            $AIFieldList = Add-PnPField -List $ProjectStatusList -Field $_.Name -ErrorAction SilentlyContinue
        }
    }  
}

function Add-StatusSummaryToStatusReport($HubSiteUrl, $ProjectStatusId, $Summary, $Recommendations, $ScoreInput, $DiffStatus) {
    Ensure-ProjectStatusSummaryColumns -HubSiteUrl $HubSiteUrl

    Connect-SharePoint -Url $HubSiteUrl
    $StatusReport = Get-PnPListItem -List "Prosjektstatus" -Id $ProjectStatusId

    $Values = @{
        GtAiStatusComments = $Summary
        GtAiRecommendations = $Recommendations
        GtAiStatusPosted = "Ja"
    }
    if ($null -ne $ScoreInput) {
        try {
            $ScoreVal = [int]$ScoreInput
            if ($ScoreVal -gt 0 -and $ScoreVal -lt 5) {
                $Score = "Svak"
            } elseif ($ScoreVal -gt 4 -and $ScoreVal -lt 8) {
                $Score = "Tilfredsstillende"
            } elseif ($ScoreVal -gt 7 -and $ScoreVal -lt 10) {
                $Score = "God"
            } elseif ($ScoreVal -eq 10) {
                $Score = "Prisverdig"
            } else {
                $Score = "Rødt"                    
            }
            $Values["GtAiStatus"] = $Score
            $Values["GtAiStatusScoreNumber"] =  $ScoreVal
        } catch {
            Write-Output "Failed to convert score to integer. Using default value."
        }
    }
    if ($null -ne $DiffStatus) {
        $Values["GtAiChangesSincePrev"] = $DiffStatus
    }
    $ProjectStatusUpdated = Set-PnPListItem -List "Prosjektstatus" -Identity $StatusReport -Values $Values
}

try {
    Write-Output "`tProcessing project status report in hub site. Generating prompt based on list configuration..."

    $ProjectSummaryPrompt = SummarizeProject -SiteId $SiteId -HubSiteUrl $HubSiteUrl
    
    $StatusInfo = SummarizeProjectStatus -SiteId $SiteId -HubSiteUrl $HubSiteUrl
    if ($null -eq $StatusInfo) {
        Write-Output "`tNo status reports found for project. Skipping processing."
        return
    }
    $StatusPrompt = $StatusInfo.Prompt    

    Write-Output "`tPrompt ready. Asking for suggestions from $($OpenAISettings.model_name)..."

    $SummaryPrompt = "Kan du gi meg en kort oppsummering av statusrapporten for prosjektet '$SiteTitle'. Fokuser på de viktigste elementene eller der det er avvik. $ProjectSummaryPrompt $StatusPrompt"
    
    $Summary = Get-OpenAIResults -Prompt $SummaryPrompt -openai $OpenAISettings -ResponseFormat "Text"
    $RecommendationsPrompt = "Kan du foreslå viktige tiltak eller aktiviteter for å lykkes i prosjektet '$SiteTitle'? Prosjektet har rapportert status. $StatusPrompt"
    
    $Recommendations = Get-OpenAIResults -Prompt $RecommendationsPrompt -openai $OpenAISettings -ResponseFormat "Text"

    $ScorePrompt = "Du skal gi meg en score for å vurdere en statusrapport. Scoren skal være et helttall mellom 1 og 10. Score på 1 indikerer en meget svak rapport med vensentlige mangler. En score på 10 indikerer en meget sterk statusrapport som utfyllende svarer på prosjektets status og virker som en realistisk indikasjon av prosjektets status. Svar KUN med ett tall. Prosjektet heter '$SiteTitle'. $ProjectSummaryPrompt $StatusPrompt"

    $StatusLevel = Get-OpenAIResults -Prompt $ScorePrompt -openai $OpenAISettings -ResponseFormat "Text"
    
    $PreviousStatusInfo = SummarizeProjectStatus -SiteId $SiteId -HubSiteUrl $HubSiteUrl -PreviousReport
    if ($null -ne $PreviousStatusInfo) {
        $PreviousStatusPrompt = $PreviousStatusInfo.Prompt

        $DiffStatusPrompt = "Du skal sammenligne to statusrapporter. Kan du gi meg en kort oppsummering av hva som har endret seg mellom den nyeste og den forrige statusrapporten? Du trenger ikke detaljere alle endringene. $ProjectSummaryPrompt Nyeste rapport: $StatusPrompt Forrige rapport: $PreviousStatusPrompt"

        $DiffStatus = Get-OpenAIResults -Prompt $DiffStatusPrompt -openai $OpenAISettings -ResponseFormat "Text"
    }

    Add-StatusSummaryToStatusReport -HubSiteUrl $HubSiteUrl -ProjectStatusId $StatusInfo.Id -Summary $Summary -Recommendations $Recommendations -ScoreInput $StatusLevel -DiffStatus $DiffStatus

    Write-Output "`tProcessing project status report in hub site completed."
}
catch {
    Write-Output "Failed to process project status report in hub site."
    Write-Output $_.Exception.Message
}
