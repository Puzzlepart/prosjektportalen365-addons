# Validation script for Prosjektportalen365 Advanced Add-ons solution

Write-Host "=== Solution Validation Report ===" -ForegroundColor Cyan

# Check file structure
$filesExpected = @{
    "main.bicep" = "Main Bicep orchestration template"
    "Deploy-Solution.ps1" = "Deployment script"
    "config/config.template.json" = "Configuration template"
    "createentraidapp.ps1" = "Managed identity script"
    "Examples-Selective-Deployment.ps1" = "Deployment examples"
}

Write-Host "`n1. File Structure Check:" -ForegroundColor Yellow
foreach ($file in $filesExpected.Keys) {
    if (Test-Path $file) {
        Write-Host "  ✓ $file - $($filesExpected[$file])" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $file - MISSING" -ForegroundColor Red
    }
}

# Check bicep modules
Write-Host "`n2. Bicep Module Check:" -ForegroundColor Yellow
$bicepFiles = Get-ChildItem -Path "." -Filter "*.bicep" -Recurse
Write-Host "  Found $($bicepFiles.Count) bicep files:" -ForegroundColor Green
$bicepFiles | ForEach-Object { 
    Write-Host "    - $($_.FullName.Substring($PWD.Path.Length + 1))" -ForegroundColor White 
}

# Check configuration schema
Write-Host "`n3. Configuration Schema Check:" -ForegroundColor Yellow
try {
    $configContent = Get-Content "config/config.template.json" -Raw | ConvertFrom-Json
    Write-Host "  ✓ Configuration JSON is valid" -ForegroundColor Green
    
    # Check for new selective deployment settings
    if ($configContent.deploymentSettings) {
        Write-Host "  ✓ Selective deployment settings found" -ForegroundColor Green
        $deploySettings = $configContent.deploymentSettings.Value
        Write-Host "    - Project Prefix: $($deploySettings.projectPrefix)" -ForegroundColor White
        Write-Host "    - Environment: $($deploySettings.environment)" -ForegroundColor White
        Write-Host "    - Runbooks to Deploy: $($deploySettings.runbooksToDeploy -join ', ')" -ForegroundColor White
        Write-Host "    - Logic Apps to Deploy: $($deploySettings.logicAppsToDeploy -join ', ')" -ForegroundColor White
        Write-Host "    - SharePoint Connector: $($deploySettings.deploySharePointConnector)" -ForegroundColor White
        Write-Host "    - Automation Connector: $($deploySettings.deployAutomationConnector)" -ForegroundColor White
    } else {
        Write-Host "  ✗ Selective deployment settings missing" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Configuration JSON is invalid: $($_.Exception.Message)" -ForegroundColor Red
}

# Test main.bicep parameters
Write-Host "`n4. Bicep Template Check:" -ForegroundColor Yellow
try {
    $bicepContent = Get-Content "main.bicep" -Raw
    
    # Check for selective deployment parameters
    $requiredParams = @(
        'runbooksToDeploy',
        'logicAppsToDeploy', 
        'deploySharePointConnector',
        'deployAutomationConnector'
    )
    
    $foundParams = @()
    foreach ($param in $requiredParams) {
        if ($bicepContent -match "param $param") {
            $foundParams += $param
            Write-Host "  ✓ Parameter '$param' found" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Parameter '$param' missing" -ForegroundColor Red
        }
    }
    
    # Check for conditional deployments
    if ($bicepContent -match "if \(contains\(runbooksToDeploy") {
        Write-Host "  ✓ Conditional runbook deployment logic found" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Conditional runbook deployment logic missing" -ForegroundColor Red
    }
    
    if ($bicepContent -match "if \(contains\(logicAppsToDeploy") {
        Write-Host "  ✓ Conditional logic app deployment logic found" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Conditional logic app deployment logic missing" -ForegroundColor Red
    }
    
} catch {
    Write-Host "  ✗ Error checking bicep template: $($_.Exception.Message)" -ForegroundColor Red
}

# Check PowerShell script capability
Write-Host "`n5. Deploy-Solution.ps1 Check:" -ForegroundColor Yellow
try {
    $deployContent = Get-Content "Deploy-Solution.ps1" -Raw
    
    # Check for correct file path
    if ($deployContent -match 'Join-Path \$PSScriptRoot "main\.bicep"') {
        Write-Host "  ✓ Correct main.bicep path reference found" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Incorrect main.bicep path reference" -ForegroundColor Red
    }
    
    # Check for bicep parameter mapping
    if ($deployContent -match 'runbooksToDeploy.*=.*\$deploymentSettings\.runbooksToDeploy') {
        Write-Host "  ✓ Runbooks parameter mapping found" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Runbooks parameter mapping missing" -ForegroundColor Red
    }
    
    if ($deployContent -match 'logicAppsToDeploy.*=.*\$deploymentSettings\.logicAppsToDeploy') {
        Write-Host "  ✓ Logic Apps parameter mapping found" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Logic Apps parameter mapping missing" -ForegroundColor Red
    }
    
} catch {
    Write-Host "  ✗ Error checking Deploy-Solution.ps1: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Validation Complete ===" -ForegroundColor Cyan
Write-Host "`nTo test selective deployment:" -ForegroundColor Yellow
Write-Host "1. Copy config/config.template.json to config/tenant-config.json" -ForegroundColor White
Write-Host "2. Update the configuration with your tenant details" -ForegroundColor White  
Write-Host "3. Modify 'deploymentSettings' to specify which components to deploy" -ForegroundColor White
Write-Host "4. Run: .\Deploy-Solution.ps1 -ConfigurationFile config\tenant-config.json -ValidateOnly" -ForegroundColor White
Write-Host "5. For examples, see Examples-Selective-Deployment.ps1" -ForegroundColor White