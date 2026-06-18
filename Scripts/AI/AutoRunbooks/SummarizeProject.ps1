Param(
    [Parameter(Mandatory = $false)]
    [string]$Url,
    [Parameter(Mandatory = $false)]
    [string]$api_credentialname = "openai_api",
    [Parameter(Mandatory = $false)]
    [string]$model_name = "gpt-4-1106-preview",
    [Parameter(Mandatory = $false)]
    [string]$api_images_credentialname = "openai_img_api",
    [Parameter(Mandatory = $false)]
    [string]$model_name_images = "dall-e",
    [Parameter(Mandatory = $false)]
    [string]$api_version = "2023-07-01-preview",
    [Parameter(Mandatory = $false)]
    [string]$api_version_images = "2024-02-15-preview",
    [Parameter(Mandatory = $false)]
    [string]$ClientId = "da6c31a6-b557-4ac3-9994-7315da06ea3a"
)

$global:__ClientId = $ClientId

# Azure OpenAI metadata variables
$OpenAISettings = @{
    credential_name        = $api_credentialname
    api_version            = $api_version
    model_name             = $model_name
    credential_name_images = $api_images_credentialname
    api_version_images     = $api_version_images
    model_name_images      = $model_name_images
}

if ($null -eq (Get-Command Set-PnPTraceLog -ErrorAction SilentlyContinue)) {
    Write-Output "You have to load the PnP.PowerShell module before running this script!"
    exit 0
}

function Connect-SharePoint($Url) {
    $pnpParams = @{ 
        Url = $Url
    }
    if ($null -ne $PSPrivateMetadata) {
        #azure runbook context
        $pnpParams.Add("ManagedIdentity", $true)
    }
    else {
        $pnpParams.Add("ClientId", $global:__ClientId)
    }

    Connect-PnPOnline @pnpParams
}

function Get-OpenAIKeyBase($CredentialName = "openai_api") {
    if ($null -ne $PSPrivateMetadata) {
        $Credential = Get-AutomationPSCredential -Name $CredentialName
    }
    else {
        $Credential = Get-PnPStoredCredential -Name $CredentialName
    }
    if ($null -eq $Credential) {
        Write-Output "Credential '$CredentialName' not found. You need to add this to credential mngr/Automation keys."    
    }
    return $Credential
}

function Invoke-ImageOpenAI {
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]
        $InputMessage,
        $openai
    )

    $openaicreds = Get-OpenAIKeyBase -CredentialName $openai.credential_name_images
    $openaiapibase = $openaicreds.UserName
    $openaiapikey = $openaicreds.GetNetworkCredential().Password

    # Header for authentication
    $headers = [ordered]@{
        'api-key' = $openaiapikey
    }

    # Adjust these values to fine-tune completions
    $body = [ordered]@{
        prompt = $InputMessage
        size   = '1024x1024'
        quality = 'medium'
        output_compression = 100
        output_format = 'png'
        n = 1
    } | ConvertTo-Json

    # Send a request to generate an answer
    $url = "$($openaiapibase)/openai/deployments/$($openai.model_name_images)/images/generations?api-version=$($openai.api_version_images)"
    $response = Invoke-RestMethod -Uri $url -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -Method Post -ContentType 'application/json' -ResponseHeadersVariable submissionHeaders
    return $response.data
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

    if ($global:__OutputPrompt) {
        Write-Host $InputMessage
    }
    
    $messages = @(
        @{
            role    = 'user'
            content = $InputMessage
        }
    )

    if ($ResponseFormat -eq 'Text') {
        $messages += @{
            role    = 'system'
            content = "Du er en hjelpsom prosjektleder-assistent som svarer kun med tekst. Du er høflig, hjelpsom og du er god på prosjektledelse og prosjektgjennomføring. Ikke bruk markdown-format eller annen formatering. Svar med ren tekst."
        }
    }
    else {
        $messages += @{
            role    = 'system'
            content = "You are a helpful project manager assistant responding only with JSON. You are an expert on project management and project execution. Your job is to help the user execution projects in a profession and efficient way. Do not use markdown formatting or any other formatting. Respond with raw JSON. The JSON response will be sent to SharePoint to create list items using Add-PnPListItem from PnP.PowerShell."
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

    $openaicreds = Get-OpenAIKeyBase -CredentialName $openai.credential_name
    $openaiapibase = $openaicreds.UserName
    $openaiapikey = $openaicreds.GetNetworkCredential().Password

    # Header for authentication
    $headers = [ordered]@{
        'api-key' = $openaiapikey
    }

    # Build input array for Responses API
    $input = @()
    foreach ($msg in $messages) {
        $input += @{
            role    = $msg.role
            content = $msg.content
        }
    }

    if ($ResponseFormat -eq 'Text') {
        # Adjust these values to fine-tune completions
        $body = [ordered]@{
            model = $openai.model_name
            input = $input
        } | ConvertTo-Json -Depth 10
    }
    else {
        # Adjust these values to fine-tune completions
        $body = [ordered]@{
            model = $openai.model_name
            input = $input
            text = @{
                format = @{
                    type = 'json_object'
                }
            }
            max_output_tokens = 16384
        } | ConvertTo-Json -Depth 10

    }
    # Send a request to generate an answer
    $url = "$($openaiapibase)/openai/responses?api-version=$($openai.api_version)"
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
        $MessageOutput = $AIResults.output | Where-Object { $_.type -eq 'message' }
        $ProcessedResults = $MessageOutput.content[0].text
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

function Get-IdeaPrompt($Url, $Id) {
    Connect-SharePoint -Url $Url
    $Idea = Get-PnPListItem -List "Idéregistrering" -Id $Id -ErrorAction SilentlyContinue
    $Fields = Get-PnPField -List "Idéregistrering"

    if ($null -eq $Idea) {
        return $null
    }
    else {
        $IdeaPrompt = "Prosjektet er basert på et prosjektforslag med følgende data (semikolonseparert): "
        $Idea.FieldValues.Keys | Where-Object { $_.Contains("Gt") -and -not $_.Contains("GtAi") -and ($_ -ne "GtIdeaUrl" -and $_ -ne "GtIdeaReporter") } | ForEach-Object {
            $InternalName = $_
            if ($Idea.FieldValues[$InternalName]) {
                $Field = $Fields | Where-Object { $_.InternalName -eq $InternalName }
                $FieldValue = $Idea.FieldValues[$InternalName]
                if ($Field.TypeAsString -eq "User") {
                    $FieldValue = $Idea.FieldValues[$InternalName].LookupValue
                } 
                $IdeaPrompt += "$($Field.Title):'$FieldValue'; "
                            
            }
        }
    }
    return $IdeaPrompt
}

function Get-FieldPromptForList($ListTitle, [array]$UsersEmails, [string]$ContentTypeId, $SkipFields = @()) {    
    if ($UsersEmails.Count -lt 1) {
        $Connection = Get-PnPConnection
        $UsersEmails = Get-SiteUsersEmails -Url $Connection.Url
    }
    
    $Fields = Get-PnPField -List $ListTitle | Where-Object { $_.Hidden -eq $false -and -not $_.SchemaXml.Contains('ShowInNewForm="FALSE"') -and -not $_.SchemaXml.Contains('ShowInEditForm="FALSE"') -and ($_.InternalName -eq "Title" -or $_.InternalName -eq "DocumentSetDescription" -or $_.InternalName.StartsWith("Gt") -and $_.InternalName -ne "GtProjectAdminRoles" -and $_.InternalName -ne "GtProjectLifecycleStatus" -and -not $_.InternalName.StartsWith("GtAi")) }

    # Filter fields based on ContentTypeId if provided
    if ($null -ne $ContentTypeId -and $ContentTypeId -ne "") {
        $ContentType = Get-PnPContentType -List $ListTitle -Includes "FieldLinks", "Parent", "Fields" -ErrorAction SilentlyContinue | Where-Object {$_.Parent.Id.StringValue -eq $ContentTypeId}
        if ($null -ne $ContentType) {
            $Fields = $Fields | Where-Object { $_.Id -in $ContentType.Fields.Id }
        }
    }

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
        elseif ($_.TypeAsString -eq "Currency") {
            $FieldPromptValue += ", verdien skal være et tall uten valutasymbol, mellomrom eller tusenskille (f.eks. 2500000). Dette er eksempelinnhold - finn på et realistisk beløp dersom det ikke fremgår av kildene. Ikke la feltet stå tomt og ikke skriv tekst som 'ukjent' eller 'ikke oppgitt'"
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

function Get-SafeFileName($Name) {
    # SharePoint file/folder names (a document set is a folder) cannot contain " * : < > ? / \ |
    # and must not have leading/trailing spaces, dots or hyphens. A '/' in particular makes
    # SharePoint treat the name as a path, which fails with "operation can only be performed on a file".
    if ($null -eq $Name) { return $Name }
    $Safe = [regex]::Replace($Name, '["*:<>?/\\|]', '-')
    $Safe = [regex]::Replace($Safe, '\s+', ' ')
    $Safe = $Safe.Trim(' ', '.', '-')
    return $Safe
}

function ConvertTo-NumericFieldValue($Value) {
    # Returns the value as a number for Currency/Number fields, or $null when it is not a clean
    # number (e.g. the AI wrote "Ikke oppgitt i kildene" in a currency field). Non-numeric values
    # are dropped so the rest of the item still saves instead of failing on "Ugyldig valutaverdi".
    if ($null -eq $Value) { return $null }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) {
        return $Value
    }
    $Text = "$Value".Trim()
    $Text = $Text -replace '[\s ]', ''       # spaces / non-breaking spaces (thousand separators)
    $Text = $Text -replace '(?i)(nok|kroner|kr)', ''
    $Text = $Text -replace ',-$', ''
    if ($Text -match '\p{L}') { return $null }     # leftover letters => not a clean number
    $Text = $Text -replace '[^\d,.\-]', ''         # strip currency symbols etc.
    if ($Text -eq '' -or $Text -eq '-') { return $null }
    if ($Text.Contains('.') -and $Text.Contains(',')) {
        $Text = ($Text -replace '\.', '') -replace ',', '.'   # '.' thousands, ',' decimal
    }
    elseif ($Text.Contains(',')) {
        $Text = $Text -replace ',', '.'
    }
    $Parsed = 0.0
    if ([double]::TryParse($Text, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$Parsed)) {
        return $Parsed
    }
    return $null
}

function Get-ListFieldMetadata($ListTitle) {
    # Returns metadata used to normalize AI-generated values before writing them:
    #   InternalNames     - set of valid internal field names
    #   DisplayToInternal - display title -> internal name (the AI sometimes returns display
    #                       names like 'Tittel'/'Interessentgrupper' instead of internal names)
    #   TaxonomyFields    - internal name -> $true when the field is multi-value taxonomy.
    #                       Taxonomy fields cannot be set through Add/Set-PnPListItem -Values and
    #                       must be written separately with Set-PnPTaxonomyFieldValue.
    #   NumericFields     - internal name -> $true for Currency/Number fields, whose values are
    #                       coerced to a number (non-numeric text is dropped).
    $Fields = Get-PnPField -List $ListTitle
    $Metadata = @{
        InternalNames     = @{}
        DisplayToInternal = @{}
        TaxonomyFields    = @{}
        NumericFields     = @{}
    }
    foreach ($Field in $Fields) {
        $Metadata.InternalNames[$Field.InternalName] = $true
        if (-not $Metadata.DisplayToInternal.ContainsKey($Field.Title)) {
            $Metadata.DisplayToInternal[$Field.Title] = $Field.InternalName
        }
        if ($Field.TypeAsString -eq "TaxonomyFieldType" -or $Field.TypeAsString -eq "TaxonomyFieldTypeMulti") {
            $Metadata.TaxonomyFields[$Field.InternalName] = ($Field.TypeAsString -eq "TaxonomyFieldTypeMulti")
        }
        if ($Field.TypeAsString -eq "Currency" -or $Field.TypeAsString -eq "Number") {
            $Metadata.NumericFields[$Field.InternalName] = $true
        }
    }
    return $Metadata
}

function Set-ProjectListItem($ListTitle, $Values, $Identity, $FieldMetadata) {
    # Creates (when $Identity is omitted) or updates a list item from an AI-generated value set,
    # remapping display names to internal names and writing taxonomy fields via Set-PnPTaxonomyFieldValue.
    if ($null -eq $FieldMetadata) {
        $FieldMetadata = Get-ListFieldMetadata -ListTitle $ListTitle
    }

    # Remap display names to internal names; drop empty and unknown fields; coerce numeric fields
    $CleanValues = @{}
    foreach ($Key in @($Values.Keys)) {
        if (-not $Values[$Key]) { continue }
        if ($FieldMetadata.InternalNames.ContainsKey($Key)) { $InternalName = $Key }
        elseif ($FieldMetadata.DisplayToInternal.ContainsKey($Key)) { $InternalName = $FieldMetadata.DisplayToInternal[$Key] }
        else { continue }

        $FieldValue = $Values[$Key]
        if ($FieldMetadata.NumericFields.ContainsKey($InternalName)) {
            $FieldValue = ConvertTo-NumericFieldValue -Value $FieldValue
            if ($null -eq $FieldValue) { continue }
        }
        $CleanValues[$InternalName] = $FieldValue
    }

    # Pull taxonomy fields out - they are written after the item exists
    $TaxonomyValues = @{}
    foreach ($TaxName in @($FieldMetadata.TaxonomyFields.Keys)) {
        if ($CleanValues.ContainsKey($TaxName)) {
            $TaxonomyValues[$TaxName] = $CleanValues[$TaxName]
            $CleanValues.Remove($TaxName)
        }
    }

    if ($null -ne $Identity) {
        $Item = Set-PnPListItem -List $ListTitle -Identity $Identity -Values $CleanValues
    }
    else {
        $Item = Add-PnPListItem -List $ListTitle -Values $CleanValues
    }

    foreach ($TaxName in $TaxonomyValues.Keys) {
        $RawTax = $TaxonomyValues[$TaxName]
        if ($RawTax -is [array]) { $TermIds = $RawTax }
        else { $TermIds = ($RawTax -split '[;,]') }
        # @() keeps this an array - a single GUID would otherwise collapse to a string,
        # making $TermIds[0] index the first character instead of the term id.
        $TermIds = @($TermIds | ForEach-Object { "$_".Trim() } | Where-Object { $_ })

        if ($FieldMetadata.TaxonomyFields[$TaxName]) {
            # Multi-value: Set-PnPTaxonomyFieldValue -Terms expects @{ termId = label }
            $Terms = @{}
            foreach ($TermId in $TermIds) {
                $Term = Get-PnPTerm -Identity $TermId -ErrorAction SilentlyContinue
                if ($null -ne $Term) { $Terms[$TermId] = $Term.Name }
            }
            if ($Terms.Count -gt 0) {
                Set-PnPTaxonomyFieldValue -ListItem $Item -InternalFieldName $TaxName -Terms $Terms
            }
        }
        elseif ($TermIds.Count -gt 0) {
            Set-PnPTaxonomyFieldValue -ListItem $Item -InternalFieldName $TaxName -TermId $TermIds[0]
        }
    }

    return $Item
}

$ErrorActionPreference = "Stop"
Set-PnPTraceLog -Off

Connect-SharePoint -Url $Url

$Site = Get-PnPSite
$SiteId = Get-PnPProperty -ClientObject $Site -Property "Id"
$HubSiteDataRaw = Invoke-PnPSPRestMethod -Url '/_api/web/HubSiteData'
$HubSiteData = ConvertFrom-Json $HubSiteDataRaw.value
$HubSiteUrl = $HubSiteData.url

$Web = Get-PnPWeb
$SiteTitle = $Web.Title

Write-Output "Script ready to sumarize project '$SiteTitle'"

. .\SummarizeProjectStatus.ps1 -OpenAISettings $OpenAISettings -SiteTitle $SiteTitle -SiteId $SiteId -HubSiteUrl $HubSiteUrl
