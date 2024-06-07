param($OpenAISettings, $Url, $SiteTitle, $ListTitle, $PromptMaxElements, $UsersEmails) 

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
        $openai
    )
    # Craft message chain to send to the model

    $forceArrayPrompt = 'Provide JSON format as follows, where items is an array of the elements, and each item is an object with keys as specified in the user prompt:
    {
        "items": [
            {
                "Title": "..."
                # internal column names
            }
        ]
    }'

    $messages = @(
        @{
            role    = 'system'
            content = "You are a helpful assistant responding only with JSON. Do not use markdown formatting or any other formatting. Respond with raw JSON. The JSON response will be sent to SharePoint to create list items using Add-PnPListItem from PnP.PowerShell."
        },
        @{
            role    = 'user'
            content = $InputMessage
        }
    )
    if ($ForceArray.IsPresent) {
        $messages += @{
            role    = 'system'
            content = $forceArrayPrompt
        }
    }

    # Header for authentication
    $headers = [ordered]@{
        'api-key' = $openai.api_key
    }

    # Adjust these values to fine-tune completions
    $body = [ordered]@{
        response_format = @{type = 'json_object'}
        messages    = $messages
        temperature = 0.1
    } | ConvertTo-Json

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
        $openai
    )

    try {
        $AIResults = Invoke-OpenAI -InputMessage $Prompt -ForceArray:$ForceArray.IsPresent -openai $openai
        $ProcessedResults = $AIResults.choices[0].message.content
        return ConvertFrom-Json $ProcessedResults
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

