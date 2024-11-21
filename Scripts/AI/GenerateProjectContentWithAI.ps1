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

. .\CommonPPAI.ps1

$ErrorActionPreference = "Stop"
Set-PnPTraceLog -Off

Connect-SharePoint -Url $Url

$Site = Get-PnPSite
$GroupId = Get-PnPProperty -ClientObject $Site -Property "GroupId"
$SiteId = Get-PnPProperty -ClientObject $Site -Property "Id"
$HubSiteDataRaw = Invoke-PnPSPRestMethod -Url '/_api/web/HubSiteData'
$HubSiteData = ConvertFrom-Json $HubSiteDataRaw.value
$HubSiteUrl = $HubSiteData.url

$Web = Get-PnPWeb
$SiteTitle = $Web.Title

$UsersEmails = Get-SiteUsersEmails -Url $HubSiteUrl

if ($IdeaReference -gt 0) {
    $IdeaPrompt = Get-IdeaPrompt -Url $HubSiteUrl -ID $IdeaReference
}

$TargetLists = @(
    @{Name = "Interessentregister"; Max = 8 },
    @{Name = "Prosjektleveranser"; Max = 5 },
    @{Name = "Kommunikasjonsplan"; Max = 6 },
    @{Name = "Prosjektlogg"; Max = 10 },
    @{Name = "Usikkerhet"; Max = 8 },
    @{Name = "Endringsanalyse"; Max = 3 },
    @{Name = "Gevinstanalyse og gevinstrealiseringsplan"; Max = 5 },
    @{Name = "Måleindikatorer"; Max = 6 },
    @{Name = "Gevinstoppfølging"; Max = 20 }
    @{Name = "Ressursallokering"; Max = 7 }
)

Write-Output "Script ready to generate demo content with AI in site '$SiteTitle'"

. .\GenerateProjectLogo.ps1 -OpenAISettings $OpenAISettings -Url $Url -SiteTitle $SiteTitle -GroupId $GroupId.Guid

. .\GenerateProjectPropertiesContent.ps1 -OpenAISettings $OpenAISettings -SiteTitle $SiteTitle -Url $Url -SiteId $SiteId -GroupId $GroupId -HubSiteUrl $HubSiteUrl -UsersEmails $UsersEmails -IdeaPrompt $IdeaPrompt

$TargetLists | ForEach-Object {
    $ListTitle = $_["Name"]
    $PromptMaxElements = $_["Max"]
    . .\GenerateProjectListContent.ps1 -OpenAISettings $OpenAISettings -Url $Url -SiteTitle $SiteTitle -ListTitle $ListTitle -PromptMaxElements $PromptMaxElements -UsersEmails $UsersEmails -IdeaPrompt $IdeaPrompt
}

. .\GenerateProjectTimelineContent.ps1 -OpenAISettings $OpenAISettings -SiteTitle $SiteTitle -SiteId $SiteId -HubSiteUrl $HubSiteUrl -IdeaPrompt $IdeaPrompt

. .\GenerateProjectStatusReportContent.ps1 -OpenAISettings $OpenAISettings -SiteTitle $SiteTitle -SiteId $SiteId -HubSiteUrl $HubSiteUrl -IdeaPrompt $IdeaPrompt
