param(
    [string]$SubscriptionName = "Azure CSP",
    [string]$ResourceGroupName = "Prosjektportalen-Premium",
    [string]$AutomationAccountName = "PP-Premium-Automation"
)

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

Write-Host "Copying runbooks with included common functions to AutoRunbooks folder..."
$Runbooks | Where-Object { $AutoRunbooks.Contains($_.Name) } | ForEach-Object {
    $RunbookName = $_.Name
    $RunbookContent = Get-Content -Path $_.FullName -Raw

    # Referencing other ps1 files in runbooks are not supported in Azure Automation
    # Therefore we are replacing the common functions reference with the actual functions
    $UpdatedRunbookContent = $RunbookContent.Replace(". .\CommonPPAI.ps1", $CommonPPAI)

    Out-File -FilePath "$PSScriptRoot\AutoRunbooks\$RunbookName" -InputObject $UpdatedRunbookContent
}

# Script is using Azure Az module anno april 2024, e.g. >= 12.0.0
# However, login via WAM is disabled using Update-AzConfig -EnableLoginByWam $false
Write-Host "Importing AutoRunbooks to Azure Automation account..."

$context = Get-AzContext    
if (!$context) {
    Connect-AzAccount
}

$Subscription = Get-AzSubscription -SubscriptionName $SubscriptionName -ErrorAction Stop

$SelectedSub = Select-AzSubscription -SubscriptionObject $Subscription -ErrorAction Stop

$AutomationAccount = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName -ErrorAction Stop

Get-Item -Path $PSScriptRoot\AutoRunbooks\*.ps1 | ForEach-Object {
    $RunbookName = $_.Name.Replace(".ps1", "")
    Write-Host "Importing runbook $RunbookName..."
    $ImportResult = Import-AzAutomationRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $RunbookName -Type PowerShell72 -Published -Path $_.FullName -Force
}

Write-Host "Runbooks imported successfully. Happy automation!"