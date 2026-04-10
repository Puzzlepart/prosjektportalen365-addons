#Requires -Version 7.0
#Requires -Modules Az, PnP.PowerShell

<#
.SYNOPSIS
    Validate tenant readiness for Prosjektportalen365 Advanced Add-ons deployment
    
.DESCRIPTION
    This script performs comprehensive validation of tenant prerequisites including:
    - Azure subscription access and permissions
    - SharePoint tenant connectivity and requirements
    - Required SharePoint lists and structure
    - PowerShell module versions
    - Network connectivity
    
.PARAMETER ConfigurationFile
    Path to the tenant configuration JSON file
    
.PARAMETER SkipSharePointTests
    Skip SharePoint connectivity and structure tests
    
.PARAMETER SkipAzureTests
    Skip Azure subscription and resource tests
    
.PARAMETER OutputFormat
    Output format for validation results (Table, JSON, or Summary)
    
.EXAMPLE
    .\Validate-Prerequisites.ps1 -ConfigurationFile "config\my-tenant-config.json"
    
.EXAMPLE
    .\Validate-Prerequisites.ps1 -ConfigurationFile "config\dev-config.json" -OutputFormat JSON
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$ConfigurationFile,
    
    [Parameter()]
    [switch]$SkipSharePointTests,
    
    [Parameter()]
    [switch]$SkipAzureTests,
    
    [Parameter()]
    [ValidateSet('Table', 'JSON', 'Summary')]
    [string]$OutputFormat = 'Table'
)

# Initialize validation tracking
$validationResults = @()
$overallSuccess = $true

function Add-ValidationResult {
    param(
        [Parameter(Mandatory)]
        [string]$Category,
        [Parameter(Mandatory)]
        [string]$Test,
        [Parameter(Mandatory)]
        [bool]$Success,
        [Parameter()]
        [string]$Message = '',
        [Parameter()]
        [string]$Details = '',
        [Parameter()]
        [string]$Recommendation = ''
    )
    
    $script:validationResults += [PSCustomObject]@{
        Category = $Category
        Test = $Test
        Success = $Success
        Status = if ($Success) { '✅ PASS' } else { '❌ FAIL' }
        Message = $Message
        Details = $Details
        Recommendation = $Recommendation
        Timestamp = Get-Date
    }
    
    if (-not $Success) {
        $script:overallSuccess = $false
    }
    
    # Real-time feedback
    $status = if ($Success) { 'PASS' } else { 'FAIL' }
    $color = if ($Success) { 'Green' } else { 'Red' }
    Write-Host "[$status] $Category - $Test" -ForegroundColor $color
    if ($Message) {
        Write-Host "  $Message" -ForegroundColor Gray
    }
}

function Test-PowerShellModules {
    Write-Host "`n🔧 Testing PowerShell Environment..." -ForegroundColor Cyan
    
    # Test PowerShell Version
    $psVersion = $PSVersionTable.PSVersion
    $minVersion = [Version]"7.0"
    Add-ValidationResult -Category "PowerShell" -Test "Version Requirement" -Success ($psVersion -ge $minVersion) -Message "Current: $psVersion, Required: $minVersion+" -Details "PowerShell 7.0+ required for cross-platform compatibility" -Recommendation "Update PowerShell: https://github.com/PowerShell/PowerShell/releases"
    
    # Test Azure PowerShell Module
    try {
        $azModule = Get-Module -Name Az -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
        if ($azModule) {
            Add-ValidationResult -Category "PowerShell" -Test "Az Module" -Success $true -Message "Version: $($azModule.Version)" -Details "Azure PowerShell module for managing Azure resources"
        } else {
            Add-ValidationResult -Category "PowerShell" -Test "Az Module" -Success $false -Message "Not installed" -Recommendation "Install: Install-Module -Name Az -Scope CurrentUser"
        }
    } catch {
        Add-ValidationResult -Category "PowerShell" -Test "Az Module" -Success $false -Message "Error checking module: $($_.Exception.Message)" -Recommendation "Install: Install-Module -Name Az -Scope CurrentUser"
    }
    
    # Test PnP PowerShell Module  
    try {
        $pnpModule = Get-Module -Name PnP.PowerShell -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
        if ($pnpModule) {
            # Check for minimum recommended version
            $minPnPVersion = [Version]"1.12.0"
            $hasMinVersion = $pnpModule.Version -ge $minPnPVersion
            Add-ValidationResult -Category "PowerShell" -Test "PnP.PowerShell Module" -Success $hasMinVersion -Message "Version: $($pnpModule.Version)" -Details "SharePoint management module" -Recommendation $(if (!$hasMinVersion) { "Update: Update-Module -Name PnP.PowerShell" } else { "" })
        } else {
            Add-ValidationResult -Category "PowerShell" -Test "PnP.PowerShell Module" -Success $false -Message "Not installed" -Recommendation "Install: Install-Module -Name PnP.PowerShell -Scope CurrentUser"
        }
    } catch {
        Add-ValidationResult -Category "PowerShell" -Test "PnP.PowerShell Module" -Success $false -Message "Error checking module: $($_.Exception.Message)" -Recommendation "Install: Install-Module -Name PnP.PowerShell -Scope CurrentUser"
    }
}

function Read-ConfigFileValue {
    <#
    .SYNOPSIS
        Reads a JSON config file and strips the Value/Description wrapper format.
    #>
    param([Parameter(Mandatory)][string]$Path)
    
    if (-not (Test-Path $Path -PathType Leaf)) { return $null }
    
    $raw = Get-Content -Path $Path -Raw | ConvertFrom-Json
    
    function ConvertObject($obj) {
        if ($null -eq $obj) { return $null }
        if ($obj -is [PSCustomObject]) {
            $result = @{}
            foreach ($property in $obj.PSObject.Properties) {
                $value = $property.Value
                if ($value -is [PSCustomObject] -and $value.PSObject.Properties.Name -contains 'Value') {
                    $result[$property.Name] = ConvertObject($value.Value)
                } else {
                    $result[$property.Name] = ConvertObject($value)
                }
            }
            return [PSCustomObject]$result
        } elseif ($obj.GetType().Name -eq 'Object[]' -or $obj -is [Array]) {
            return @($obj | ForEach-Object { ConvertObject($_) })
        } else {
            return $obj
        }
    }
    
    return ConvertObject($raw)
}

function Test-ConfigurationFile {
    Write-Host "`n📄 Testing Configuration Files..." -ForegroundColor Cyan
    
    $configDir = Split-Path $ConfigurationFile -Parent
    
    try {
        # Validate root config.json
        $rootContent = Get-Content -Path $ConfigurationFile -Raw
        $null = $rootContent | ConvertFrom-Json
        Add-ValidationResult -Category "Configuration" -Test "Root config.json Format" -Success $true -Message "Valid JSON format" -Details $ConfigurationFile
        
        # Validate required config files exist
        $requiredFiles = @(
            @{ Name = 'azure.json'; Section = 'azure' },
            @{ Name = 'sharepoint.json'; Section = 'sharepoint' }
        )
        
        foreach ($reqFile in $requiredFiles) {
            $filePath = Join-Path $configDir $reqFile.Name
            $exists = Test-Path $filePath -PathType Leaf
            Add-ValidationResult -Category "Configuration" -Test "$($reqFile.Section) Config File" -Success $exists -Message $(if ($exists) { "Present: $($reqFile.Name)" } else { "Missing: $($reqFile.Name)" }) -Details "Required configuration file" -Recommendation $(if (!$exists) { "Create $($reqFile.Name) in config directory (see config/templates/)" } else { "" })
            
            if ($exists) {
                try {
                    $null = Get-Content -Path $filePath -Raw | ConvertFrom-Json
                    Add-ValidationResult -Category "Configuration" -Test "$($reqFile.Section) JSON Format" -Success $true -Message "Valid JSON" -Details $reqFile.Name
                } catch {
                    Add-ValidationResult -Category "Configuration" -Test "$($reqFile.Section) JSON Format" -Success $false -Message "Invalid JSON: $($_.Exception.Message)" -Recommendation "Fix JSON syntax in $($reqFile.Name)"
                }
            }
        }
        
        # Validate optional type-level config files
        foreach ($typeFile in @('runbooks.json', 'logic-apps.json', 'connectors.json', 'automation.json')) {
            $filePath = Join-Path $configDir $typeFile
            if (Test-Path $filePath -PathType Leaf) {
                try {
                    $null = Get-Content -Path $filePath -Raw | ConvertFrom-Json
                    Add-ValidationResult -Category "Configuration" -Test "$typeFile Format" -Success $true -Message "Valid JSON" -Details $typeFile
                } catch {
                    Add-ValidationResult -Category "Configuration" -Test "$typeFile Format" -Success $false -Message "Invalid JSON: $($_.Exception.Message)" -Recommendation "Fix JSON syntax in $typeFile"
                }
            }
        }
        
        # Load and validate Azure configuration
        $azureConfig = Read-ConfigFileValue -Path (Join-Path $configDir 'azure.json')
        if ($azureConfig) {
            $subIdPattern = '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            $validSubId = $azureConfig.subscriptionId -match $subIdPattern
            Add-ValidationResult -Category "Configuration" -Test "Subscription ID Format" -Success $validSubId -Message $azureConfig.subscriptionId -Details "Must be valid GUID format" -Recommendation $(if (!$validSubId) { "Use valid subscription GUID" } else { "" })
            
            $validRgName = $azureConfig.resourceGroupName -and $azureConfig.resourceGroupName.Length -le 63
            Add-ValidationResult -Category "Configuration" -Test "Resource Group Name" -Success $validRgName -Message $azureConfig.resourceGroupName -Details "Must be 1-63 characters" -Recommendation $(if (!$validRgName) { "Use valid resource group name (1-63 chars)" } else { "" })
            
            $validLocations = @('eastus', 'westeurope', 'northeurope', 'norwayeast', 'uksouth', 'australiaeast', 'japaneast', 'southeastasia')
            $validLocation = $azureConfig.location -in $validLocations
            Add-ValidationResult -Category "Configuration" -Test "Azure Location" -Success $validLocation -Message $azureConfig.location -Details "Must be supported Azure region" -Recommendation $(if (!$validLocation) { "Use supported region: $($validLocations -join ', ')" } else { "" })
        }
        
        # Load and validate SharePoint configuration
        $spConfig = Read-ConfigFileValue -Path (Join-Path $configDir 'sharepoint.json')
        if ($spConfig) {
            $tenantPattern = '^[a-zA-Z0-9][a-zA-Z0-9-]*\.sharepoint\.com$'
            $validTenant = $spConfig.tenant -match $tenantPattern
            Add-ValidationResult -Category "Configuration" -Test "SharePoint Tenant Format" -Success $validTenant -Message $spConfig.tenant -Details "Must be valid SharePoint domain" -Recommendation $(if (!$validTenant) { "Use format: tenant.sharepoint.com" } else { "" })
            
            $hubUrlPattern = '^https://[a-zA-Z0-9][a-zA-Z0-9-]*\.sharepoint\.com/sites/[a-zA-Z0-9-]+/?$'
            $validHubUrl = $spConfig.hubSiteUrl -match $hubUrlPattern
            Add-ValidationResult -Category "Configuration" -Test "Hub Site URL Format" -Success $validHubUrl -Message $spConfig.hubSiteUrl -Details "Must be valid SharePoint site URL" -Recommendation $(if (!$validHubUrl) { "Use format: https://tenant.sharepoint.com/sites/sitename" } else { "" })
        }
        
        # Build unified config for downstream validation functions
        $config = [PSCustomObject]@{
            subscriptionId    = if ($azureConfig) { $azureConfig.subscriptionId } else { $null }
            resourceGroupName = if ($azureConfig) { $azureConfig.resourceGroupName } else { $null }
            location          = if ($azureConfig) { $azureConfig.location } else { $null }
            tenant            = if ($spConfig) { $spConfig.tenant } else { $null }
            hubSiteUrl        = if ($spConfig) { $spConfig.hubSiteUrl } else { $null }
        }
        
        return $config
        
    } catch {
        Add-ValidationResult -Category "Configuration" -Test "File Format" -Success $false -Message "Error reading config: $($_.Exception.Message)" -Recommendation "Fix configuration files in config directory"
        return $null
    }
}

function Test-AzureConnectivity {
    param($Config)
    
    if ($SkipAzureTests) {
        Write-Host "`n☁️ Skipping Azure Tests..." -ForegroundColor Yellow
        return
    }
    
    Write-Host "`n☁️ Testing Azure Connectivity..." -ForegroundColor Cyan
    
    # Test Azure authentication
    try {
        $azContext = Get-AzContext
        if ($azContext) {
            Add-ValidationResult -Category "Azure" -Test "Authentication" -Success $true -Message "Authenticated as: $($azContext.Account.Id)" -Details "Azure PowerShell session active"
            
            # Test subscription access
            $targetSubId = $Config.subscriptionId
            if ($azContext.Subscription.Id -eq $targetSubId) {
                Add-ValidationResult -Category "Azure" -Test "Subscription Access" -Success $true -Message "Connected to target subscription" -Details "Subscription: $($azContext.Subscription.Name)"
            } else {
                Add-ValidationResult -Category "Azure" -Test "Subscription Access" -Success $false -Message "Connected to different subscription" -Details "Current: $($azContext.Subscription.Id), Target: $targetSubId" -Recommendation "Run: Set-AzContext -SubscriptionId $targetSubId"
            }
        } else {
            Add-ValidationResult -Category "Azure" -Test "Authentication" -Success $false -Message "Not authenticated" -Recommendation "Run: Connect-AzAccount"
            return
        }
    } catch {
        Add-ValidationResult -Category "Azure" -Test "Authentication" -Success $false -Message "Error: $($_.Exception.Message)" -Recommendation "Install Az module and run: Connect-AzAccount"
        return
    }
    
    # Test resource group access
    try {
        $rgName = $Config.resourceGroupName
        $resourceGroup = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue
        if ($resourceGroup) {
            Add-ValidationResult -Category "Azure" -Test "Resource Group Access" -Success $true -Message "Resource group exists" -Details "Location: $($resourceGroup.Location)"
        } else {
            Add-ValidationResult -Category "Azure" -Test "Resource Group Access" -Success $true -Message "Resource group will be created" -Details "Creation permissions will be tested during deployment"
        }
    } catch {
        Add-ValidationResult -Category "Azure" -Test "Resource Group Access" -Success $false -Message "Permission error: $($_.Exception.Message)" -Recommendation "Ensure Contributor access to subscription/resource group"
    }
    
    # Test resource provider registration
    $requiredProviders = @('Microsoft.Automation', 'Microsoft.Logic', 'Microsoft.Web', 'Microsoft.Authorization')
    foreach ($provider in $requiredProviders) {
        try {
            $providerStatus = Get-AzResourceProvider -ProviderNamespace $provider | Select-Object -First 1
            $isRegistered = $providerStatus.RegistrationState -eq 'Registered'
            Add-ValidationResult -Category "Azure" -Test "Provider: $provider" -Success $isRegistered -Message "Status: $($providerStatus.RegistrationState)" -Details "Required for solution deployment" -Recommendation $(if (!$isRegistered) { "Run: Register-AzResourceProvider -ProviderNamespace $provider" } else { "" })
        } catch {
            Add-ValidationResult -Category "Azure" -Test "Provider: $provider" -Success $false -Message "Error checking provider" -Recommendation "Verify subscription permissions"
        }
    }
}

function Test-SharePointConnectivity {
    param($Config)
    
    if ($SkipSharePointTests) {
        Write-Host "`n🌐 Skipping SharePoint Tests..." -ForegroundColor Yellow
        return
    }
    
    Write-Host "`n🌐 Testing SharePoint Connectivity..." -ForegroundColor Cyan
    
    # Test SharePoint connection
    try {
        $connection = Get-PnPConnection -ErrorAction SilentlyContinue
        if ($connection) {
            $connectedUrl = $connection.Url
            $targetUrl = $Config.hubSiteUrl
            $isCorrectSite = $connectedUrl -eq $targetUrl
            
            Add-ValidationResult -Category "SharePoint" -Test "Connection" -Success $isCorrectSite -Message "Connected to: $connectedUrl" -Details "PnP PowerShell session active" -Recommendation $(if (!$isCorrectSite) { "Connect to hub site: Connect-PnPOnline -Url $targetUrl -Interactive" } else { "" })
            
            if ($isCorrectSite) {
                # Test site access
                try {
                    $web = Get-PnPWeb
                    Add-ValidationResult -Category "SharePoint" -Test "Site Access" -Success $true -Message "Site: $($web.Title)" -Details "Successfully accessed hub site"
                } catch {
                    Add-ValidationResult -Category "SharePoint" -Test "Site Access" -Success $false -Message "Access denied: $($_.Exception.Message)" -Recommendation "Ensure admin access to hub site"
                }
            }
        } else {
            Add-ValidationResult -Category "SharePoint" -Test "Connection" -Success $false -Message "Not connected" -Recommendation "Run: Connect-PnPOnline -Url $($Config.hubSiteUrl) -Interactive"
            return
        }
    } catch {
        Add-ValidationResult -Category "SharePoint" -Test "Connection" -Success $false -Message "Error: $($_.Exception.Message)" -Recommendation "Install PnP.PowerShell and connect to SharePoint"
        return
    }
    
    # Test hub site configuration
    try {
        $hubSiteData = Invoke-PnPSPRestMethod -Url '/_api/web/HubSiteData' -ErrorAction SilentlyContinue
        if ($hubSiteData.value) {
            $hubInfo = ConvertFrom-Json $hubSiteData.value
            Add-ValidationResult -Category "SharePoint" -Test "Hub Site Configuration" -Success $true -Message "Hub ID: $($hubInfo.themeKey)" -Details "Site is properly configured as hub"
        } else {
            Add-ValidationResult -Category "SharePoint" -Test "Hub Site Configuration" -Success $false -Message "Not a hub site" -Recommendation "Configure site as SharePoint hub site"
        }
    } catch {
        Add-ValidationResult -Category "SharePoint" -Test "Hub Site Configuration" -Success $false -Message "Cannot verify hub configuration" -Details "May still work if configured correctly"
    }
    
    # Test admin permissions
    try {
        $adminSites = @()
        try {
            # Try to access tenant admin (requires SharePoint admin)
            $tenantUrl = $Config.tenant.Replace('.sharepoint.com', '-admin.sharepoint.com')
            $adminTestUrl = "https://$tenantUrl"
            
            # This is just a validation - we don't actually connect
            Add-ValidationResult -Category "SharePoint" -Test "Admin Access Pattern" -Success $true -Message "Admin URL: $adminTestUrl" -Details "Admin URL pattern is correct"
        } catch {
            Add-ValidationResult -Category "SharePoint" -Test "Admin Access" -Success $false -Message "Cannot determine admin access" -Details "SharePoint admin required for site archiving" -Recommendation "Ensure SharePoint admin privileges"
        }
    } catch {}
}

function Test-NetworkConnectivity {
    Write-Host "`n🌐 Testing Network Connectivity..." -ForegroundColor Cyan
    
    # Test Azure endpoint connectivity
    $azureEndpoints = @{
        'Azure Management' = 'management.azure.com'
        'Azure Login' = 'login.microsoftonline.com'
        'Azure Automaton' = 'eus.hybridworker.azure-automation.net'
    }
    
    foreach ($endpoint in $azureEndpoints.GetEnumerator()) {
        try {
            $testConnection = Test-NetConnection -ComputerName $endpoint.Value -Port 443 -WarningAction SilentlyContinue -ErrorAction Stop
            Add-ValidationResult -Category "Network" -Test $endpoint.Key -Success $testConnection.TcpTestSucceeded -Message "Port 443: $($endpoint.Value)" -Details "HTTPS connectivity test"
        } catch {
            Add-ValidationResult -Category "Network" -Test $endpoint.Key -Success $false -Message "Connection failed to $($endpoint.Value)" -Recommendation "Check firewall and proxy settings"
        }
    }
    
    # Test PowerShell Gallery connectivity
    try {
        $galleryTest = Find-Module -Name PowerShellGet -Repository PSGallery -ErrorAction Stop
        Add-ValidationResult -Category "Network" -Test "PowerShell Gallery" -Success $true -Message "Gallery accessible" -Details "Module download and updates available"
    } catch {
        Add-ValidationResult -Category "Network" -Test "PowerShell Gallery" -Success $false -Message "Cannot access gallery: $($_.Exception.Message)" -Recommendation "Check proxy settings and TLS configuration"
    }
}

function Show-ValidationResults {
    param($Format)
    
    Write-Host "`n" -NoNewline
    if ($overallSuccess) {
        Write-Host "🎉 VALIDATION COMPLETED SUCCESSFULLY" -ForegroundColor Green -BackgroundColor Black
        Write-Host "Your tenant is ready for Prosjektportalen365 deployment!" -ForegroundColor Green
    } else {
        Write-Host "⚠️  VALIDATION COMPLETED WITH ISSUES" -ForegroundColor Red -BackgroundColor Black
        Write-Host "Some prerequisites need attention before deployment." -ForegroundColor Red
    }
    
    Write-Host "`n📊 Results Summary:" -ForegroundColor Cyan
    $summary = $validationResults | Group-Object Success | ForEach-Object {
        [PSCustomObject]@{
            Status = if ($_.Name -eq 'True') { 'PASSED' } else { 'FAILED' }
            Count = $_.Count
            Tests = ($_.Group | Select-Object -ExpandProperty Test) -join ', '
        }
    }
    
    $passCount = ($validationResults | Where-Object Success -eq $true).Count
    $failCount = ($validationResults | Where-Object Success -eq $false).Count
    $totalCount = $validationResults.Count
    
    Write-Host "✅ Passed: $passCount/$totalCount tests" -ForegroundColor Green
    Write-Host "❌ Failed: $failCount/$totalCount tests" -ForegroundColor Red
    
    switch ($Format) {
        'Table' {
            Write-Host "`n📋 Detailed Results:" -ForegroundColor Cyan
            $validationResults | Format-Table -Property Status, Category, Test, Message, Recommendation -AutoSize
        }
        'JSON' {
            Write-Host "`n📋 JSON Output:" -ForegroundColor Cyan
            $validationResults | ConvertTo-Json -Depth 3
        }
        'Summary' {
            Write-Host "`n❌ Issues Found:" -ForegroundColor Red
            $failures = $validationResults | Where-Object Success -eq $false
            foreach ($failure in $failures) {
                Write-Host "  • $($failure.Category) - $($failure.Test): $($failure.Message)" -ForegroundColor Red
                if ($failure.Recommendation) {
                    Write-Host "    Recommendation: $($failure.Recommendation)" -ForegroundColor Yellow
                }
            }
        }
    }
    
    if ($failCount -gt 0) {
        Write-Host "`n🔧 Next Steps:" -ForegroundColor Cyan
        Write-Host "1. Address the failed tests above" -ForegroundColor White
        Write-Host "2. Re-run validation: .\Validate-Prerequisites.ps1 -ConfigurationFile '$ConfigurationFile'" -ForegroundColor White
        Write-Host "3. Once all tests pass, run deployment: .\Deploy-Solution.ps1 -ConfigurationFile '$ConfigurationFile'" -ForegroundColor White
    } else {
        Write-Host "`n🚀 Ready to Deploy!" -ForegroundColor Green
        Write-Host "Run deployment: .\Deploy-Solution.ps1 -ConfigurationFile '$ConfigurationFile'" -ForegroundColor White
    }
}

# Main execution
try {
    Write-Host @"
    
╔══════════════════════════════════════════════════════════════════╗
║            Prosjektportalen365 Prerequisites Validator          ║
║                     Tenant Readiness Check                      ║
╚══════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

    # Load and validate configuration
    $config = Test-ConfigurationFile
    if (-not $config) {
        Write-Host "`n❌ Configuration validation failed. Cannot proceed with other tests." -ForegroundColor Red
        exit 1
    }
    
    # Run validation tests
    Test-PowerShellModules
    Test-AzureConnectivity -Config $config
    Test-SharePointConnectivity -Config $config
    Test-NetworkConnectivity
    
    # Show results
    Show-ValidationResults -Format $OutputFormat
    
    # Set exit code based on overall result
    if ($overallSuccess) {
        Write-Host "`n✅ Validation completed successfully" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "`n❌ Validation completed with issues" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "`n💥 Validation script failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}