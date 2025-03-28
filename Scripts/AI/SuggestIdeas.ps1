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
    [string]$ClientId = "da6c31a6-b557-4ac3-9994-7315da06ea3a",
    [Parameter(Mandatory = $false)]
    [int]$IdeaReference
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

function Add-GeneratedItemsToList($ListTitle, $GeneratedItems) {    
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
        }
    }
}

. .\CommonPPAI.ps1

$ErrorActionPreference = "Stop"
Set-PnPTraceLog -Off

Connect-SharePoint -Url $Url

$Web = Get-PnPWeb
$SiteTitle = $Web.Title
$UsersEmails = Get-SiteUsersEmails -Url $Url

Write-Output "Script ready to generate demo content with AI in site '$SiteTitle'"

$ListTitle = "Idéregistrering"
Write-Output "`tProcessing list '$ListTitle'. Generating prompt based on list configuration..."
$FieldPrompt = Get-FieldPromptForList -ListTitle $ListTitle -UsersEmails $UsersEmails

$Prompt = "Gi meg 5 ulike prosjektideer/prosjektforslag som skal registreres i en liste $ListTitle. Hold deg innenfor prosjekter som kan være aktuelle i offentlig sektor. VIKTIG: Returner elementene som en ren JSON array - outputen din skal starte med '[' og avsluttes med ']'. Ikke ta med markdown formatering eller annen formatering. Feltene er følgende: $FieldPrompt. Verdien i tittel-feltet skal være unikt, det skal si noe om hva oppføringen handler om, og skal ikke være det samme som prosjektnavnet. Bruk internnavnene på feltene i JSON-objektet nøyaktig - ikke legg på for eksempel Id på slutten av et internt feltnavn. "
    
Write-Output "`tPrompt ready. Asking for suggestions from $($OpenAISettings.model_name)..."
$GeneratedItems = Get-OpenAIResults -Prompt $Prompt -ForceArray -openai $OpenAISettings
Add-GeneratedItemsToList -ListTitle $ListTitle -GeneratedItems $GeneratedItems


$ListTitle = "Idébehandling"
Write-Output "`tProcessing list '$ListTitle'. Generating prompt based on list configuration..."
$FieldPrompt = Get-FieldPromptForList -ListTitle $ListTitle -UsersEmails $UsersEmails

$Prompt = "Gi meg 5 oppfølginger av ideer i en liste $ListTitle. Hvert element må ha en kobling til en unik eksisterende registrert idé. VIKTIG: Returner elementene som en ren JSON array - outputen din skal starte med '[' og avsluttes med ']'. Ikke ta med markdown formatering eller annen formatering. Feltene er følgende: $FieldPrompt. Verdien i tittel-feltet skal være unikt, det skal si noe om hva oppføringen handler om, og skal ikke være det samme som prosjektnavnet. Bruk internnavnene på feltene i JSON-objektet nøyaktig - ikke legg på for eksempel Id på slutten av et internt feltnavn. "
    
Write-Output "`tPrompt ready. Asking for suggestions from $($OpenAISettings.model_name)..."

$GeneratedItems = Get-OpenAIResults -Prompt $Prompt -ForceArray -openai $OpenAISettings

Add-GeneratedItemsToList -ListTitle $ListTitle -GeneratedItems $GeneratedItems
