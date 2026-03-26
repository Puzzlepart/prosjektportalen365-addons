# Build script for document generation runbooks
# Combines Common.ps1 into each runbook script to create self-contained files
# for Azure Automation (which does not support referencing other ps1 files)

$Common = Get-Content -Path $PSScriptRoot\Common.ps1 -Raw

$Runbooks = @("run-pptx.ps1", "run-docx.ps1")

$OutputDir = Join-Path $PSScriptRoot "AutoRunbooks"
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

foreach ($RunbookName in $Runbooks) {
    $Content = Get-Content -Path "$PSScriptRoot\$RunbookName" -Raw
    $Combined = $Content.Replace(". .\Common.ps1", $Common)
    Out-File -FilePath "$OutputDir\$RunbookName" -InputObject $Combined
    Write-Host "Built AutoRunbooks\$RunbookName"
}

Write-Host "Build complete. Ready for Azure Automation import."
