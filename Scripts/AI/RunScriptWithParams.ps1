param(
    [Parameter(Mandatory = $true)][string]$ScriptName,
    [Parameter(Mandatory = $true)][string]$Url,
    [string]$AdditionalPrompt
)

$params = @{
    Url = $Url
    api_credentialname = "openai_api"
    model_name = "gpt-5.2-codex"
    api_version = "2025-04-01-preview"
    model_name_images = "gpt-image-1"
    api_version_images = "2025-04-01-preview"
    AdditionalPrompt = $AdditionalPrompt
}

# Properly handle script path to avoid colon issues
$scriptPath = Join-Path $PSScriptRoot $ScriptName
& $scriptPath @params