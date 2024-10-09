param($OpenAISettings, $SiteTitle, $SiteId, $HubSiteUrl)

function Connect-SharePoint($Url) {
    $pnpParams = @{ 
        Url = $Url
    }
    if ($null -ne $PSPrivateMetadata) {
        #azure runbook context
        $pnpParams.Add("ManagedIdentity", $true)
    }
    else {
        $pnpParams.Add("Interactive", $true)
        $pnpParams.Add("ClientId", $global:__ClientId)
    }

    Connect-PnPOnline @pnpParams
}

function Invoke-ImageOpenAI {
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]
        $InputMessage,
        $openai
    )

    # Header for authentication
    $headers = [ordered]@{
        'api-key' = $openai.api_key
    }

    # Adjust these values to fine-tune completions
    $body = [ordered]@{
        prompt = $InputMessage
        size   = '1024x1024'
        style  = 'vivid'
        n      = 1
    } | ConvertTo-Json

    # Send a request to generate an answer
    $url = "$($openai.api_base)/openai/deployments/$($openai.model_name_images)/images/generations?api-version=$($openai.api_version_images)"
    $response = Invoke-RestMethod -Uri $url -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -Method Post -ContentType 'application/json' -ResponseHeadersVariable submissionHeaders
    return $response.data.url
}

function Invoke-OpenAI {
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]
        $InputMessage,
        [switch]$ForceArray,
        $openai,
        [ValidateSet('JSON', 'Text')]
        [string]$ResponseFormat = 'JSON'
    )
    
    $messages = @(
        @{
            role    = 'user'
            content = $InputMessage
        }
    )

    if ($ResponseFormat -eq 'Text') {
        $messages += @{
            role    = 'system'
            content = "Du er en hjelpsom assistent som svarer kun med tekst. Ikke bruk markdown-format eller annen formatering. Svar med ren tekst. Du er høflig, hjelpsom og du er god på prosjektledelse og prosjektgjennomføring."
        }
    }
    else {
        $messages += @{
            role    = 'system'
            content = "You are a helpful assistant responding only with JSON. Do not use markdown formatting or any other formatting. Respond with raw JSON. The JSON response will be sent to SharePoint to create list items using Add-PnPListItem from PnP.PowerShell."
        }

        if ($ForceArray.IsPresent) {
            $forceArrayPrompt = 'Provide JSON format as follows, where items is an array of the elements, and each item is an object with keys as specified in the user prompt:
    {
        "items": [
            {
                "Title": "..."
                # internal column names
            }
        ]
    }'
            $messages += @{
                role    = 'system'
                content = $forceArrayPrompt
            }
        }
    }

    # Header for authentication
    $headers = [ordered]@{
        'api-key' = $openai.api_key
    }

    if ($ResponseFormat -eq 'Text') {
        # Adjust these values to fine-tune completions
        $body = [ordered]@{
            messages    = $messages
            temperature = 0.1
        } | ConvertTo-Json
    }
    else {
        # Adjust these values to fine-tune completions
        $body = [ordered]@{
            response_format = @{type = 'json_object' }
            messages        = $messages
            temperature     = 0.1
        } | ConvertTo-Json

    }
    # Send a request to generate an answer
    $url = "$($openai.api_base)/openai/deployments/$($openai.model_name)/chat/completions?api-version=$($openai.api_version)"
    $response = Invoke-RestMethod -Uri $url -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -Method Post -ContentType 'application/json'
    return $response
}

function Get-OpenAIResults {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Prompt,
        [switch]$ForceArray,
        $openai,
        [ValidateSet('JSON', 'Text')]
        [string]$ResponseFormat = 'JSON'
    )

    try {
        $AIResults = Invoke-OpenAI -InputMessage $Prompt -ForceArray:$ForceArray.IsPresent -openai $openai -ResponseFormat $ResponseFormat
        $ProcessedResults = $AIResults.choices[0].message.content
        if ($ResponseFormat -eq 'JSON') {
            return ConvertFrom-Json $ProcessedResults
        }
        return $ProcessedResults
    }
    catch {
        Write-Output $_.Exception.Message
        Write-Output "Using the following prompt: $Prompt"
        Write-Output "Yielded the following results:"
        Write-Output $ProcessedResults
        exit 0
    }
}

function Get-SiteUsersEmails($Url) {
    Connect-SharePoint -Url $Url
    $GroupId = Get-PnPProperty -ClientObject (Get-PnPSite) -Property "GroupId"

    $UserFieldOptions = @()

    Get-PnPMicrosoft365GroupMember -Identity $GroupId | Where-Object UserType -eq "member" | ForEach-Object {
        $UserFieldOptions += $_.UserPrincipalName
    }

    return $UserFieldOptions
}

function Get-FieldPromptForList($ListTitle, $UsersEmails, $SkipFields = @()) {
    $Fields = Get-PnPField -List $ListTitle | Where-Object { $_.Hidden -eq $false -and -not $_.SchemaXml.Contains('ShowInNewForm="FALSE"') -and -not $_.SchemaXml.Contains('ShowInEditForm="FALSE"') -and ($_.InternalName -eq "Title" -or $_.InternalName.StartsWith("Gt") -and $_.InternalName -ne "GtProjectAdminRoles" -and $_.InternalName -ne "GtProjectLifecycleStatus") }

    $FieldPrompt = ""
    $Fields | ForEach-Object {
        if ($SkipFields -contains $_.InternalName) {
            return
        }
        $FieldPromptValue = "'$($_.Title)' (Internt navn '$($_.InternalName)'"
        if ($_.Description) {
            $FieldPromptValue += ", beskrivelse av input: '$($_.Description)'"
        }

        if ($_.TypeAsString -eq "DateTime") {
            $FieldPromptValue += ", datoformat: yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fffffff"
        }
        elseif ($_.TypeAsString -eq "Number") {
            if ($_.ShowAsPercentage) {
                $FieldPromptValue += ", verdien skal være et desimaltall mellom 0 og 1 som indikerer prosent, der 1 er 100%"
            }
            else {
                $FieldPromptValue += ", verdien skal være et heltall"
            }
        }
        elseif ($_.TypeAsString -eq "User" -or $_.TypeAsString -eq "UserMulti") {
            $FieldPromptValue += ", verdi skal være en av følgende e-postadresser: $($UsersEmails -join ", ")'"
        }
        elseif ($_.TypeAsString -eq "Choice" -or $_.TypeAsString -eq "MultiChoice") {
            if ($_.Choices) {
                $FieldPromptValue += ", valg: '$($_.Choices -join ", ")'"
            }
        }
        elseif (($_.TypeAsString -eq "Lookup" -or $_.TypeAsString -eq "LookupMulti")) {
            if ($_.InternalName.Contains("_")) {
                return
            }
            [array]$LookupChoicesListItems = Get-PnPListItem -List $_.LookupList
            if ($LookupChoicesListItems.Count -lt 1) {
                return
            }
            if ($_.TypeAsString -eq "LookupMulti") {
                $LookupChoices = ", valg (velg ID-verdien til en eller flere av følgende (ID kommaseparert, f.eks. 1,23,30). Kun ID-verdien skal være med i JSON): "
            }
            else {
                $LookupChoices = ", valg (velg ID-verdien til en av følgende. Kun ID-verdien skal være med i JSON): "
            }
            $LookupChoicesListItems | ForEach-Object {
                $LookupChoices += "$($_.FieldValues.Title) (ID: $($_.FieldValues.ID)), "
            }
            $LookupChoices = $LookupChoices.TrimEnd(", ")
            $FieldPromptValue += $LookupChoices
        }
        elseif ($_.TypeAsString -eq "TaxonomyFieldType" -or $_.TypeAsString -eq "TaxonomyFieldTypeMulti") {
            try {                
                $termGroup = Get-PnPTermGroup -Identity "Prosjektportalen"
                if ($null -ne $termGroup) {
                    $termSet = Get-PnPTermSet -Identity $_.TermSetId.Guid -TermGroup $termGroup.Id.Guid
                    $terms = Get-PnPTerm -TermSet $termSet -TermGroup $termGroup.Id.Guid

                    $LookupChoices = ", valg (bruk KUN ID-verdien til en av følgende): "
                
                    $terms | ForEach-Object {
                        $LookupChoices += "$($_.Name) (ID: $($_.Id)), "
                    }
                    $LookupChoices = $LookupChoices.TrimEnd(", ")
                    $FieldPromptValue += $LookupChoices
                }
            }
            catch {
                Write-Output $_.Exception.Message
                Write-Output "Failed to get termset for field '$($_.Title)' in list '$ListTitle'.. Continuing with next list.."
            }
        }
        elseif ($_.TypeAsString -eq "Calculated") {
            return
        }
        elseif ($_.TypeAsString -eq "Boolean") {
            return
        }

        $FieldPromptValue += "), "
        $FieldPrompt += $FieldPromptValue
    }
    $FieldPrompt = $FieldPrompt.TrimEnd(", ")
    return $FieldPrompt
}

function ConvertPSObjectToHashtable {
    param (
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    process {
        if ($null -eq $InputObject) { return $null }

        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $collection = @(
                foreach ($object in $InputObject) { ConvertPSObjectToHashtable $object }
            )

            Write-Output -NoEnumerate $collection
        }
        elseif ($InputObject -is [psobject]) {
            $hash = @{}

            foreach ($property in $InputObject.PSObject.Properties) {
                $hash[$property.Name] = ConvertPSObjectToHashtable $property.Value
            }

            $hash
        }
        else {
            $InputObject
        }
    }
}

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

