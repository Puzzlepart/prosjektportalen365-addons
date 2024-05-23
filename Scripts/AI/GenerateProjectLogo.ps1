param($OpenAISettings, $Url, $SiteTitle, $GroupId)

. .\CommonPPAI.ps1

$LogoPath = "$env:TEMP\$GroupId.png"
Write-Output "`tGenerating project logo with $($OpenAISettings.model_name_images)..."

$Prompt = "Generate an image for a project named $SiteTitle."

$GeneratedImageUrl = Invoke-ImageOpenAI -InputMessage $Prompt -openai $OpenAISettings
Invoke-WebRequest -Uri $GeneratedImageUrl -OutFile $LogoPath

Connect-SharePoint -Url $Url
Set-PnPMicrosoft365Group -Identity $GroupId -GroupLogoPath $LogoPath

Write-Output "`tProject logo generated and set for project '$SiteTitle'. This will take some minutes to propagate."