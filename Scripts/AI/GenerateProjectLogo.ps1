param($OpenAISettings, $Url, $SiteTitle, $GroupId)

. .\CommonPPAI.ps1

$LogoFileName = "$GroupId.png"
$LogoPath = "$env:TEMP\$LogoFileName"
Write-Output "`tGenerating project logo with $($OpenAISettings.model_name_images)..."

$Prompt = "Lag en logo for et prosjekt som heter '$SiteTitle'. Bruk enkel stil som egner seg digitalt, subtil gradient. Ikke bruk tekst."

$GeneratedImageData = Invoke-ImageOpenAI -InputMessage $Prompt -openai $OpenAISettings

if ($GeneratedImageData.Url -eq $null) {
    $ImageBytes = [convert]::FromBase64String($GeneratedImageData[0].b64_json)
    $ImageFile = [System.IO.File]::WriteAllBytes($LogoPath, $ImageBytes)
}
else {
    $GeneratedImageUrl = $GeneratedImageData[0].url
    Invoke-WebRequest -Uri $GeneratedImageUrl -OutFile $LogoPath
}

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