$AutoRunbooks = @(
    "GenerateProjectListContent.ps1",
    "GenerateProjectLogo.ps1",
    "GenerateProjectPropertiesContent.ps1",
    "GenerateProjectTimelineContent.ps1",
    "GenerateProjectStatusReportContent.ps1",
    "GetSiteInformation.ps1",
    "SetSiteBanner.ps1"
)

$Runbooks = Get-Item -Path $PSScriptRoot\*.ps1

$CommonPPAI = Get-Content -Path $PSScriptRoot\CommonPPAI.ps1 -Raw

$Runbooks | Where-Object {$AutoRunbooks.Contains($_.Name)} | ForEach-Object {
    $RunbookName = $_.Name
    $RunbookContent = Get-Content -Path $_.FullName -Raw

    # Referencing other ps1 files in runbooks are not supported in Azure Automation
    # Therefore we are replacing the common functions reference with the actual functions
    $UpdatedRunbookContent = $RunbookContent.Replace(". .\CommonPPAI.ps1", $CommonPPAI)

    Out-File -FilePath "$PSScriptRoot\AutoRunbooks\$RunbookName" -InputObject $UpdatedRunbookContent
}