# Validation script for Prosjektportalen365 Advanced Add-ons solution

Write-Host "=== Solution Validation Report ===" -ForegroundColor Cyan

# Check file structure
$filesExpected = @{
    "main.bicep" = "Main Bicep orchestration template"
    "Deploy-Solution.ps1" = "Deployment script"
    "config/config.json" = "Root configuration (deployment orchestration)"
    "config/azure.json" = "Azure configuration (subscription, resource group)"
    "config/sharepoint.json" = "SharePoint configuration (tenant, hub site)"
    "config/automation.json" = "Automation configuration (language, log level)"
    "config/runbooks.json" = "Runbook settings (all runbooks)"
    "config/logic-apps.json" = "Logic app settings (all logic apps)"
    "config/connectors.json" = "Connector settings (all connectors)"
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
    $rootConfig = Get-Content "config/config.json" -Raw | ConvertFrom-Json
    Write-Host "  ✓ Root config.json is valid JSON" -ForegroundColor Green
    
    # Check for component selection settings
    if ($rootConfig.components) {
        Write-Host "  ✓ Component selection settings found" -ForegroundColor Green
        $components = $rootConfig.components.Value
        if ($null -eq $components) { $components = $rootConfig.components }
        Write-Host "    - Runbooks: $($components.runbooks -join ', ')" -ForegroundColor White
        Write-Host "    - Logic Apps: $($components.logicApps -join ', ')" -ForegroundColor White
        if ($components.connectors) {
            Write-Host "    - SharePoint Connector: $($components.connectors.SharePointOnline)" -ForegroundColor White
            Write-Host "    - Automation Connector: $($components.connectors.Automation)" -ForegroundColor White
        }
    } else {
        Write-Host "  ✗ Component selection settings missing from config.json" -ForegroundColor Red
    }
    
    # Validate type-level config files
    foreach ($typeFile in @('azure.json', 'sharepoint.json', 'automation.json', 'runbooks.json', 'logic-apps.json', 'connectors.json')) {
        $typePath = "config/$typeFile"
        if (Test-Path $typePath) {
            try {
                $null = Get-Content $typePath -Raw | ConvertFrom-Json
                Write-Host "  ✓ $typeFile is valid JSON" -ForegroundColor Green
            } catch {
                Write-Host "  ✗ $typeFile has invalid JSON: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
} catch {
    Write-Host "  ✗ Root config.json is invalid: $($_.Exception.Message)" -ForegroundColor Red
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
    
    # Check for hierarchical config loading
    if ($deployContent -match 'Read-HierarchicalConfig') {
        Write-Host "  ✓ Hierarchical config loading function found" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Hierarchical config loading function missing" -ForegroundColor Red
    }
    
    if ($deployContent -match 'Read-ConfigFile') {
        Write-Host "  ✓ Config file reader function found" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Config file reader function missing" -ForegroundColor Red
    }
    
    # Check for bicep parameter mapping
    if ($deployContent -match 'runbooksToDeploy.*=.*deploymentSettings\.runbooksToDeploy') {
        Write-Host "  ✓ Runbooks parameter mapping found" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Runbooks parameter mapping missing" -ForegroundColor Red
    }
    
    if ($deployContent -match 'logicAppsToDeploy.*=.*deploymentSettings\.logicAppsToDeploy') {
        Write-Host "  ✓ Logic Apps parameter mapping found" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Logic Apps parameter mapping missing" -ForegroundColor Red
    }
    
} catch {
    Write-Host "  ✗ Error checking Deploy-Solution.ps1: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Validation Complete ===" -ForegroundColor Cyan
Write-Host "`nTo set up a new tenant:" -ForegroundColor Yellow
Write-Host "1. Copy files from config/templates/ to config/" -ForegroundColor White
Write-Host "2. Update azure.json with your subscription and resource group" -ForegroundColor White
Write-Host "3. Update sharepoint.json with your tenant and hub site URL" -ForegroundColor White
Write-Host "4. Edit config.json to select which components to deploy" -ForegroundColor White
Write-Host "5. Run: .\Deploy-Solution.ps1 -ConfigurationFile config\config.json -ValidateOnly" -ForegroundColor White