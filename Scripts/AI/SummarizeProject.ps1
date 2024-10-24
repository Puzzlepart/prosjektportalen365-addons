Param(
    [Parameter(Mandatory = $false)]
    [string]$Url,
    [Parameter(Mandatory = $true)]
    [string]$api_key,
    [Parameter(Mandatory = $false)]
    [string]$api_base = "https://pzl-testing-oaiservice-swedencentral.openai.azure.com/",
    [Parameter(Mandatory = $false)]
    [string]$model_name = "gpt-4-1106-preview",
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
    api_key            = $api_key
    api_base           = $api_base
    api_version        = $api_version
    model_name         = $model_name
    api_version_images = $api_version_images
    model_name_images  = $model_name_images
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
$SiteId = Get-PnPProperty -ClientObject $Site -Property "Id"
$HubSiteDataRaw = Invoke-PnPSPRestMethod -Url '/_api/web/HubSiteData'
$HubSiteData = ConvertFrom-Json $HubSiteDataRaw.value
$HubSiteUrl = $HubSiteData.url

$Web = Get-PnPWeb
$SiteTitle = $Web.Title

Write-Output "Script ready to sumarize project '$SiteTitle'"

. .\SummarizeProjectStatus.ps1 -OpenAISettings $OpenAISettings -SiteTitle $SiteTitle -SiteId $SiteId -HubSiteUrl $HubSiteUrl