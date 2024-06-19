param($OpenAISettings, $Url, $SiteTitle, $GroupId)

. .\CommonPPAI.ps1

$LogoFileName = "$GroupId.png"
$LogoPath = "$env:TEMP\$LogoFileName"
Write-Output "`tGenerating project logo with $($OpenAISettings.model_name_images)..."

$Prompt = "Lag en logo for et prosjekt som heter '$SiteTitle' i enkel stil som egner seg digitalt, subtil gradient. Ikke bruk tekst i logo."

$GeneratedImageUrl = Invoke-ImageOpenAI -InputMessage $Prompt -openai $OpenAISettings
Invoke-WebRequest -Uri $GeneratedImageUrl -OutFile $LogoPath

Write-Output "`tProject logo generated: $GeneratedImageUrl"

Connect-SharePoint -Url $Url
Set-PnPMicrosoft365Group -Identity $GroupId -GroupLogoPath $LogoPath

$Web = Get-PnPWeb
$SiteAssets = Get-PnPList -Identity "SiteAssets" -ErrorAction SilentlyContinue
if ($null -eq $SiteAssets) {
    $Web.Lists.EnsureSiteAssetsLibrary()
    Invoke-PnPQuery -ErrorAction SilentlyContinue
}

$UploadedFile = Add-PnPFile -Path $LogoPath -Folder "SiteAssets" -ErrorAction SilentlyContinue

$SiteAssetsLogoPath = "$($Web.ServerRelativeUrl)/SiteAssets/$($LogoFileName)"

$WebOutput = Set-PnPWebHeader -SiteLogoUrl $SiteAssetsLogoPath -SiteThumbnailUrl $SiteAssetsLogoPath -ErrorAction SilentlyContinue

Write-Output "`tProject logo set for project '$SiteTitle'. This will take some minutes to propagate."