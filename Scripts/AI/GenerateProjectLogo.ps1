param($OpenAISettings, $Url, $SiteTitle, $GroupId)

. .\CommonPPAI.ps1

$LogoPath = "$env:TEMP\$GroupId.png"
Write-Output "`tGenerating project logo with $($OpenAISettings.model_name_images)..."

$Prompt = "Generate a logo for a project named '$SiteTitle', rounded edges square mobile app logo design, subtle gradient, minimal single color background. No text. Icon should use full width and height."

$GeneratedImageUrl = Invoke-ImageOpenAI -InputMessage $Prompt -openai $OpenAISettings
Invoke-WebRequest -Uri $GeneratedImageUrl -OutFile $LogoPath

Write-Output "`tProject logo generated: $GeneratedImageUrl"

Connect-SharePoint -Url $Url
Set-PnPMicrosoft365Group -Identity $GroupId -GroupLogoPath $LogoPath

Write-Output "`tProject logo set for project '$SiteTitle'. This will take some minutes to propagate."