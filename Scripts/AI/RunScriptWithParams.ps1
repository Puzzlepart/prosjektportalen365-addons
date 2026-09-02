param(
    [Parameter(Mandatory = $true)][string]$ScriptName,
    [Parameter(Mandatory = $true)][string]$Url,
    [string]$AdditionalPrompt
)

$params = @{
    Url = $Url
    api_credentialname = "openai_api"
    model_name = "gpt-5.6-sol"
    model_name_images = "gpt-image-2"
    AdditionalPrompt = $AdditionalPrompt
}

# Properly handle script path to avoid colon issues
$scriptPath = Join-Path $PSScriptRoot $ScriptName
& $scriptPath @params