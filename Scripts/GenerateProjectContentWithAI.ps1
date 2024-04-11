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
    [string]$model_name_images = "dall-e",
    [Parameter(Mandatory = $false)]
    [string]$api_version = "2023-07-01-preview",
    [Parameter(Mandatory = $false)]
    [string]$api_version_images = "2024-02-15-preview"
)

# Azure OpenAI metadata variables
$openai = @{
    api_key     = $api_key
    api_base    = $api_base
    api_version = $api_version
    api_version_images = $api_version_images
    model_name_images =  $model_name_images
    model_name        = $model_name #This will correspond to the custom name you chose for your deployment when you deployed a model.
}

function Invoke-ImageOpenAI {
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]
        $InputMessage        
    )

    # Header for authentication
    $headers = [ordered]@{
        'api-key' = $openai.api_key
    }

    # Adjust these values to fine-tune completions
    $body = [ordered]@{
        prompt    = $InputMessage
        size   = '1024x1024'
        style = 'vivid'
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
        messages    = $messages
        # response_format = @{type = 'json_object'}
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
        [string]$Prompt
    )

    try {
        $AIResults = Invoke-OpenAI -InputMessage $Prompt
        $ProcessedResults = $AIResults.choices[0].message.content.TrimStart("````json").TrimEnd("``````").Trim()
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

function Get-FieldPromptForList($ListTitle) {
    $Fields = Get-PnPField -List $ListTitle | Where-Object { $_.Hidden -eq $false -and -not $_.SchemaXml.Contains('ShowInNewForm="FALSE"') -and -not $_.SchemaXml.Contains('ShowInEditForm="FALSE"') -and ($_.InternalName -eq "Title" -or $_.InternalName.StartsWith("Gt") -and $_.InternalName -ne "GtProjectAdminRoles" -and $_.InternalName -ne "GtProjectLifecycleStatus") }

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
                Write-Output $_.Exception.Message -ForegroundColor Red
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
if ($null -eq (Get-Command Set-PnPTraceLog -ErrorAction SilentlyContinue)) {
    Write-Output "You have to load the PnP.PowerShell module before running this script!" -ForegroundColor Red
    exit 0
}

$ErrorActionPreference = "Stop"
Set-PnPTraceLog -Off

$pnpParams = @{ 
    Url = $Url
}
if($null -ne $PSPrivateMetadata){ #azure runbook context
    $pnpParams.Add("ManagedIdentity",$true)
} else {
    $pnpParams.Add("Interactive",$true)
}

Connect-PnPOnline @pnpParams

$Site = Get-PnPSite
$GroupId = Get-PnPProperty -ClientObject $Site -Property "GroupId"
$ProjectSiteId = Get-PnPProperty -ClientObject $Site -Property "Id"
$HubSiteDataRaw = Invoke-PnPSPRestMethod -Url '/_api/web/HubSiteData'
$HubSiteData = ConvertFrom-Json $HubSiteDataRaw.value
$HubSiteUrl = $HubSiteData.url

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

Write-Output "Script ready to generate demo content with AI in site '$SiteTitle'"

Write-Output "Generating project logo with $model_name_images..."

$Prompt = "Generate an image for a project named $SiteTitle."

#TODO: FIX LOGO PATH!
$LogoPath = "C:\temp\logo.png"
$GeneratedImageUrl = Invoke-ImageOpenAI -InputMessage $Prompt
Invoke-WebRequest -Uri $GeneratedImageUrl -OutFile $LogoPath
Set-PnPMicrosoft365Group -Identity $GroupId.Guid -GroupLogoPath $LogoPath

Write-Output "Project logo generated and set for project '$SiteTitle'. This will take some minutes to propagate."

$ProjectProperties = Get-PnPListItem -List "Prosjektegenskaper" -Id 1 -ErrorAction SilentlyContinue
if ($null -eq $ProjectProperties) {
    Write-Output "`tProject properties not found. Please create a project properties list item in the Prosjektegenskaper list before running this script." -ForegroundColor Red
}
else {
    Write-Output "`tProject properties found. Starting to generate content for project '$SiteTitle'..."
    $FieldPrompt = Get-FieldPromptForList -ListTitle "Prosjektegenskaper"
    
    $Prompt = "Gi meg eksempler på $ListTitle for et prosjekt som heter '$SiteTitle'. VIKTIG: Returner elementene som et JSON objekt. Feltene er følgende: $FieldPrompt. Verdien i tittel-feltet skal være '$SiteTitle'. Bruk internnavnene på feltene i JSON-objektet nøyaktig - ikke legg på for eksempel Id på slutten av et internt feltnavn."
    
    Write-Output "`tPrompt ready. Asking for suggestions from $model_name..."

    $GeneratedItems = Get-OpenAIResults -Prompt $Prompt

    $GeneratedItems | ForEach-Object {
        Write-Output "`t`tCreating list item '$($_.Title)' for list 'Prosjektegenskaper'"
        $HashtableValues = ConvertPSObjectToHashtable -InputObject $_
        @($HashtableValues.keys) | ForEach-Object { 
            if (-not $HashtableValues[$_]) { $HashtableValues.Remove($_) } 
        }
        try {
            $ItemResult = Set-PnPListItem -List "Prosjektegenskaper" -Identity 1 -Values $HashtableValues
        }
        catch {
            Write-Output "Failed to create list item for list 'Prosjektegenskaper'" -ForegroundColor Red
            Write-Output $_.Exception.Message -ForegroundColor Red
            Write-Output "Using the following prompt: $Prompt"
            Write-Output "Using the following values as input:"
            $HashtableValues
        }
    }
}

$TargetLists | ForEach-Object {
    $ListTitle = $_["Name"]
    $PromptMaxElements = $_["Max"]
    
    Write-Output "`tProcessing list '$ListTitle'. Generating prompt based on list configuration..."
    $FieldPrompt = Get-FieldPromptForList -ListTitle $ListTitle

    $Prompt = "Gi meg $PromptMaxElements ulike eksempler på $ListTitle for et prosjekt som heter '$SiteTitle'. VIKTIG: Returner elementene som en ren JSON array. Feltene er følgende: $FieldPrompt. Verdien i tittel-feltet skal være unikt, det skal si noe om hva oppføringen handler om, og skal ikke være det samme som prosjektnavnet. Bruk internnavnene på feltene i JSON-objektet nøyaktig - ikke legg på for eksempel Id på slutten av et internt feltnavn."
    
    Write-Output "`tPrompt ready. Asking for suggestions from $model_name..."

    $GeneratedItems = Get-OpenAIResults -Prompt $Prompt

    $GeneratedItems | ForEach-Object {
        Write-Output "`t`tCreating list item '$($_.Title)' for list '$ListTitle'"
        $HashtableValues = ConvertPSObjectToHashtable -InputObject $_
        @($HashtableValues.keys) | ForEach-Object { 
            if (-not $HashtableValues[$_]) { $HashtableValues.Remove($_) } 
        }
        try {
            $ItemResult = Add-PnPListItem -List $ListTitle -Values $HashtableValues
        }
        catch {
            Write-Output "Failed to create list item for list '$ListTitle'" -ForegroundColor Red
            Write-Output $_.Exception.Message -ForegroundColor Red
            Write-Output "Using the following prompt: $Prompt"
            Write-Output "Using the following values as input:"
            $HashtableValues
        }
    }
}

try {
    Write-Output "`tProcessing project status report in hub site. Generating prompt based on list configuration..."
    $pnpParams.Url = $HubSiteUrl
    Connect-PnPOnline @pnpParams

    $FieldPrompt = Get-FieldPromptForList -ListTitle "Prosjektstatus"
        
    $Prompt = "Gi meg eksempler på $ListTitle for et prosjekt som heter '$SiteTitle'. VIKTIG: Returner elementene som et JSON objekt. Feltene er følgende: $FieldPrompt. Verdien i tittel-feltet skal være 'Ny statusrapport for $SiteTitle'. Bruk internnavnene på feltene i JSON-objektet nøyaktig - ikke legg på for eksempel Id på slutten av et internt feltnavn."
        
    Write-Output "`tPrompt ready. Asking for suggestions from $model_name..."
    
    $GeneratedItems = Get-OpenAIResults -Prompt $Prompt
    
    $GeneratedItems | ForEach-Object {
        Write-Output "`t`tCreating list item '$($_.Title)' for list 'Prosjektstatus'"
        $HashtableValues = ConvertPSObjectToHashtable -InputObject $_
        @($HashtableValues.keys) | ForEach-Object { 
            if (-not $HashtableValues[$_]) { $HashtableValues.Remove($_) } 
        }
        
        $HashtableValues["Title"] = "Ny statusrapport for $SiteTitle"
        $HashtableValues["GtSiteId"] = $ProjectSiteId
        $HashtableValues["GtModerationStatus"] = "Publisert"
        $HashtableValues["GtLastReportDate"] = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffffff")

        try {
            $ItemResult = Add-PnPListItem -List "Prosjektstatus" -Values $HashtableValues
        }
        catch {
            Write-Output "Failed to create list item for list 'Prosjektstatus'" -ForegroundColor Red
            Write-Output $_.Exception.Message -ForegroundColor Red
            Write-Output "Using the following prompt: $Prompt"
            Write-Output "Using the following values as input:"
            $HashtableValues
        }
    }
    
}
catch {
    Write-Output "Failed to process project status report in hub site." -ForegroundColor Red
    Write-Output $_.Exception.Message -ForegroundColor Red
}