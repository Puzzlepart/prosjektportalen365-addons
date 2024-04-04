Param(
    [Parameter(Mandatory = $false)]
    [string]$Url,
    [Parameter(Mandatory = $true)]
    [string]$api_key,
    [Parameter(Mandatory = $true)]
    [string]$api_base,
    [Parameter(Mandatory = $false)]
    [string]$model_name,
    [Parameter(Mandatory = $false)]
    [string]$api_version = "2023-07-01-preview"
)

# Azure OpenAI metadata variables
$openai = @{
    api_key     = $api_key
    api_base    = $api_base # your endpoint should look like the following https://YOUR_RESOURCE_NAME.openai.azure.com/
    api_version = $api_version # this may change in the future
    name        = $model_name #This will correspond to the custom name you chose for your deployment when you deployed a model.
}

function Invoke-OpenAI {
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]
        $InputMessage        
    )
    # Craft message chain to send to the model
    $messages = @(
        @{
            role    = 'system'
            content = "You are responding only with JSON. Thhe JSON response will be sent to SharePoint to create list items using Add-PnPListItem from PnP.PowerShell."
        },
        @{
            role    = 'user'
            content = $InputMessage
        }
    )

    # Header for authentication
    $headers = [ordered]@{
        'api-key' = $openai.api_key
    }

    # Adjust these values to fine-tune completions
    $body = [ordered]@{
        messages        = $messages
        # response_format = @{type = 'json_object'}
        temperature     = 0.1
    } | ConvertTo-Json

    # Send a request to generate an answer
    $url = "$($openai.api_base)/openai/deployments/$($openai.name)/chat/completions?api-version=$($openai.api_version)"
    $response = Invoke-RestMethod -Uri $url -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -Method Post -ContentType 'application/json'
    return $response
}

function Get-OpenAIResults {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Prompt
    )

    try {
        $AIResults = Invoke-OpenAI -InputMessage $Prompt
        $ProcessedResults = $AIResults.choices[0].message.content.TrimStart("````json").TrimEnd("``````").Trim()
        return ConvertFrom-Json $ProcessedResults
    }
    catch {
        Write-Host "*******************ERROR*********************"
        Write-Host $_ -ForegroundColor Red
        Write-Host "*******************PROMPT*********************"
        Write-Host $Prompt
        Write-Host "*******************Results*********************"
        Write-Host $ProcessedResults
        exit 0
    }
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
if ($null -eq (Get-Command Set-PnPTraceLog -ErrorAction SilentlyContinue)) {
    Write-Host "You have to load the PnP.PowerShell module before running this script!" -ForegroundColor Red
    exit 0
}

$ErrorActionPreference = "Stop"
Set-PnPTraceLog -Off

Connect-PnPOnline -Url $Url -Interactive

$Web = Get-PnPWeb
$SiteTitle = $Web.Title

$ctx = Get-PnPContext
$ctx.Load($ctx.Web.CurrentUser)
$ctx.ExecuteQuery()
$CurrentUserEmail = $ctx.Web.CurrentUser.Email

$TargetLists = @(
    @{Name = "Interessentregister"; Max = 10 },
    @{Name = "Prosjektleveranser"; Max = 5 },
    @{Name = "Kommunikasjonsplan"; Max = 6 },
    @{Name = "Prosjektlogg"; Max = 10 },
    @{Name = "Usikkerhet"; Max = 6 },
    @{Name = "Endringsanalyse"; Max = 3 },
    @{Name = "Gevinstanalyse og gevinstrealiseringsplan"; Max = 5 },
    @{Name = "Måleindikatorer"; Max = 6 },
    @{Name = "Gevinstoppfølging"; Max = 20 }
)

Write-Host "Script ready to generate demo content with AI in site '$SiteTitle'"

$TargetLists | ForEach-Object {
    $ListTitle = $_["Name"]
    $PromptMaxElements = $_["Max"]
    
    Write-Host "Processing list '$ListTitle'. Generating prompt based on list configuration..."

    $Fields = Get-PnPField -List $ListTitle | Where-Object { $_.InternalName -eq "Title" -or $_.InternalName.StartsWith("Gt") }

    $FieldPrompt = ""
    $Fields | ForEach-Object { 
        $FieldPromptValue = "'$($_.Title)' (Internt navn '$($_.InternalName)'"
        if ($_.Description) {
            $FieldPromptValue += ", beskrivelse av input: '$($_.Description)'"
        }

        if ($_.TypeAsString -eq "DateTime") {
            $FieldPromptValue += ", datoformat: yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fffffff"
        }
        elseif ($_.TypeAsString -eq "Number") {
            $FieldPromptValue += ", verdien skal være et heltall"
        }
        elseif ($_.TypeAsString -eq "User" -or $_.TypeAsString -eq "UserMulti") {
            $FieldPromptValue += ", verdi skal være '$CurrentUserEmail'"
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
                Write-Host $_.Exception.Message -ForegroundColor Red
                Write-Host "Failed to get termset for field '$($_.Title)' in list '$ListTitle'.. Continuing with next list.."
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

    $Prompt = "Gi meg $PromptMaxElements ulike eksempler på $ListTitle for et prosjekt som heter '$SiteTitle'. VIKTIG: Returner elementene som en ren JSON array. Feltene er følgende: $FieldPrompt. Verdien i tittel-feltet skal være unikt, det skal si noe om hva oppføringen handler om, og skal ikke være det samme som prosjektnavnet. Bruk internnavnene på feltene i JSON-objektet nøyaktig - ikke legg på for eksempel Id på slutten av et internt feltnavn."
    
    Write-Host "Prompt ready. Asking for suggestions from $model_name..."

    $GeneratedItems = Get-OpenAIResults -Prompt $Prompt

    $GeneratedItems | ForEach-Object {
        Write-Host "`tCreating list item '$($_.Title)' for list '$ListTitle'"
        $HashtableValues = ConvertPSObjectToHashtable -InputObject $_
        @($HashtableValues.keys) | ForEach-Object { 
            if (-not $HashtableValues[$_]) { $HashtableValues.Remove($_) } 
        }
        try {
            $ItemResult = Add-PnPListItem -List $ListTitle -Values $HashtableValues
        }
        catch {
            Write-Host "Failed to create list item for list '$ListTitle'" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            Write-Host "Using the following prompt: $Prompt"
            Write-Host "Using the following values as input:"
            $HashtableValues
        }
    }
}