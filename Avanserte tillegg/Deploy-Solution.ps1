#Requires -Version 7.0

[CmdletBinding(DefaultParameterSetName = 'Interactive')]
param(
    # ============================================================================
    # DEPLOYMENT MODES
    # ============================================================================
    
    [Parameter(ParameterSetName = 'ConfigFile')]
    [string]$ConfigurationFile,
    
    [Parameter(ParameterSetName = 'Preset')]
    [ValidateSet('Minimal', 'Full', 'Testing', 'ArchiveOnly', 'UpdateOnly', 'LogicAppsOnly')]
    [string]$Preset,
    
    # ============================================================================
    # CORE DEPLOYMENT PARAMETERS
    # ============================================================================
    
    [Parameter(ParameterSetName = 'Interactive', Mandatory)]
    [Parameter(ParameterSetName = 'ConfigFile')]
    [Parameter(ParameterSetName = 'Preset', Mandatory)]
    [string]$SubscriptionId,
    
    [Parameter(ParameterSetName = 'Interactive')]
    [Parameter(ParameterSetName = 'ConfigFile')]
    [Parameter(ParameterSetName = 'Preset')]
    [ValidateLength(1, 63)]
    [string]$ResourceGroupName = 'RG-Prosjektportalen365',
    
    [Parameter(ParameterSetName = 'Interactive')]
    [Parameter(ParameterSetName = 'ConfigFile')]
    [Parameter(ParameterSetName = 'Preset')]
    [ValidateSet('eastus', 'westeurope', 'northeurope', 'norwayeast', 'uksouth', 'australiaeast', 'japaneast', 'southeastasia')]
    [string]$Location = 'norwayeast',
    
    [Parameter(ParameterSetName = 'Interactive', Mandatory)]
    [Parameter(ParameterSetName = 'ConfigFile')]
    [Parameter(ParameterSetName = 'Preset', Mandatory)]
    [string]$SharePointTenant,
    
    [Parameter(ParameterSetName = 'Interactive', Mandatory)]
    [Parameter(ParameterSetName = 'ConfigFile')]
    [Parameter(ParameterSetName = 'Preset', Mandatory)]
    [string]$HubSiteUrl,
    
    [Parameter(ParameterSetName = 'Interactive', Mandatory)]
    [Parameter(ParameterSetName = 'ConfigFile')]
    [Parameter(ParameterSetName = 'Preset', Mandatory)]
    [string]$SharePointConnectionEmail,
    
    [Parameter(ParameterSetName = 'Interactive')]
    [Parameter(ParameterSetName = 'ConfigFile')]
    [Parameter(ParameterSetName = 'Preset')]
    [ValidateLength(2, 10)]
    [string]$ProjectPrefix = 'PP365',
    
    [Parameter(ParameterSetName = 'Interactive')]
    [Parameter(ParameterSetName = 'ConfigFile')]
    [Parameter(ParameterSetName = 'Preset')]
    [ValidateLength(2, 5)]
    [string]$Environment = 'prod',
    
    # ============================================================================
    # SELECTIVE DEPLOYMENT PARAMETERS
    # ============================================================================
    
    [Parameter(ParameterSetName = 'Interactive')]
    [Parameter(ParameterSetName = 'Preset')]
    [ValidateSet('ArchiveSite', 'GetSiteInformation', 'UpdateProjectDates', 'UpdateProjectManager')]
    [string[]]$RunbooksToDeploy,
    
    [Parameter(ParameterSetName = 'Interactive')]
    [Parameter(ParameterSetName = 'Preset')]
    [ValidateSet('ChangeArchiveState', 'PhaseChanged', 'ProjectInfoChanged', 'RequestProjectAccess')]
    [string[]]$LogicAppsToDeploy,
    
    [Parameter(ParameterSetName = 'Interactive')]
    [Parameter(ParameterSetName = 'Preset')]
    [switch]$SkipSharePointConnector,
    
    [Parameter(ParameterSetName = 'Interactive')]
    [Parameter(ParameterSetName = 'Preset')]
    [switch]$SkipAutomationConnector,
    
    # ============================================================================
    # SHAREPOINT CONFIGURATION
    # ============================================================================
    
    [Parameter(ParameterSetName = 'Interactive')]
    [Parameter(ParameterSetName = 'ConfigFile')]
    [Parameter(ParameterSetName = 'Preset')]
    [string]$ProjectListGuid,
    
    [Parameter(ParameterSetName = 'Interactive')]
    [Parameter(ParameterSetName = 'ConfigFile')]
    [Parameter(ParameterSetName = 'Preset')]
    [string]$ListViewGuid,
    
    [Parameter(ParameterSetName = 'Interactive')]
    [Parameter(ParameterSetName = 'ConfigFile')]
    [Parameter(ParameterSetName = 'Preset')]
    [string]$FinishedPhaseText = 'Ferdig',

    [Parameter(ParameterSetName = 'Interactive')]
    [Parameter(ParameterSetName = 'ConfigFile')]
    [Parameter(ParameterSetName = 'Preset')]
    [string]$PnPClientId,
    
    # ============================================================================
    # CONTROL PARAMETERS
    # ============================================================================
    
    [switch]$ValidateOnly,
    [switch]$Force,
    [switch]$ShowExamples,
    [switch]$WhatIf,
    
    # ============================================================================
    # MANAGED IDENTITY PARAMETERS
    # ============================================================================
    
    [switch]$CreateManagedIdentity,
    [switch]$CreateUserAssignedIdentity,
    [switch]$SkipManagedIdentity
)

# ============================================================================
# TAB COMPLETION OPTIMIZATION
# ============================================================================

# Register argument completers for better tab completion performance
Register-ArgumentCompleter -CommandName 'Deploy-Solution.ps1' -ParameterName 'ConfigurationFile' -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    Get-ChildItem -Path "$wordToComplete*.json" -File | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_.FullName, $_.Name, 'ParameterValue', $_.Name)
    }
}

Register-ArgumentCompleter -CommandName 'Deploy-Solution.ps1' -ParameterName 'SubscriptionId' -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    try {
        $subs = az account list --query "[].{id:id, name:name}" -o json 2>$null | ConvertFrom-Json
        if ($subs) {
            $subs | Where-Object { $_.id -like "$wordToComplete*" } | Select-Object -First 5 | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new(
                    $_.id,
                    "$($_.name) ($($_.id))",
                    'ParameterValue',
                    $_.name
                )
            }
        }
    }
    catch {
        # Silently fail and provide no completions if az CLI issues
    }
}

# Script configuration
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'
$InformationPreference = 'Continue'

# ============================================================================
# MODULE REQUIREMENTS AND PARAMETER VALIDATION
# ============================================================================

Write-Host "Checking PowerShell modules and parameters..." -ForegroundColor Cyan

# Check required tools
$missingTools = @()

# Check Azure CLI
try {
    $azVersion = az version 2>$null | ConvertFrom-Json
    if ($azVersion) {
        Write-Host "Found Azure CLI: $($azVersion.'azure-cli')" -ForegroundColor Green
    } else {
        $missingTools += 'Azure CLI (az)'
        Write-Host "Missing required tool: Azure CLI (az)" -ForegroundColor Red
    }
} catch {
    $missingTools += 'Azure CLI (az)'
    Write-Host "Missing required tool: Azure CLI (az)" -ForegroundColor Red
}

# Check PnP.PowerShell module
if (-not (Get-Module -Name 'PnP.PowerShell' -ListAvailable -ErrorAction SilentlyContinue)) {
    $missingTools += 'PnP.PowerShell'
    Write-Host "Missing required module: PnP.PowerShell" -ForegroundColor Red
} else {
    Write-Host "Found module: PnP.PowerShell" -ForegroundColor Green
}

if ($missingTools.Count -gt 0) {
    Write-Host "Missing required tools. Please install them:" -ForegroundColor Red
    foreach ($tool in $missingTools) {
        if ($tool -eq 'Azure CLI (az)') {
            Write-Host "  Azure CLI: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli" -ForegroundColor Yellow
        } else {
            Write-Host "  Install-Module -Name $tool -Force" -ForegroundColor Yellow
        }
    }
    throw "Missing required tools: $($missingTools -join ', ')"
}

# Validate parameters that were removed from attributes for performance
# Skip validation if using ConfigFile parameter set (values come from config file)
if ($PSCmdlet.ParameterSetName -ne 'ConfigFile') {
    if ($ConfigurationFile -and -not (Test-Path $ConfigurationFile -PathType Leaf)) {
        Write-Host "Configuration file not found: $ConfigurationFile" -ForegroundColor Red
        throw "Configuration file not found: $ConfigurationFile"
    }

    if ($SubscriptionId -and $SubscriptionId -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
        Write-Host "Invalid SubscriptionId format. Must be a valid GUID." -ForegroundColor Red
        throw "Invalid SubscriptionId format"
    }

    if ($SharePointTenant -and $SharePointTenant -notmatch '^[a-zA-Z0-9][a-zA-Z0-9-]*\.sharepoint\.com$') {
        Write-Host "Invalid SharePointTenant format. Must be like 'contoso.sharepoint.com'" -ForegroundColor Red
        throw "Invalid SharePointTenant format"
    }

    if ($HubSiteUrl -and $HubSiteUrl -notmatch '^https://[a-zA-Z0-9][a-zA-Z0-9-]*\.sharepoint\.com/sites/[a-zA-Z0-9-]+$') {
        Write-Host "Invalid HubSiteUrl format. Must be like 'https://contoso.sharepoint.com/sites/sitename'" -ForegroundColor Red
        throw "Invalid HubSiteUrl format"
    }

    if ($SharePointConnectionEmail -and $SharePointConnectionEmail -notmatch '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
        Write-Host "Invalid SharePointConnectionEmail format. Must be a valid email address." -ForegroundColor Red
        throw "Invalid SharePointConnectionEmail format"
    }

    if ($ProjectListGuid -and $ProjectListGuid -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
        Write-Host "Invalid ProjectListGuid format. Must be a valid GUID." -ForegroundColor Red
        throw "Invalid ProjectListGuid format"
    }

    if ($ListViewGuid -and $ListViewGuid -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
        Write-Host "Invalid ListViewGuid format. Must be a valid GUID." -ForegroundColor Red
        throw "Invalid ListViewGuid format"
    }
    
    Write-Host "Parameter validation completed successfully!" -ForegroundColor Green
} else {
    Write-Host "Using configuration file - parameter validation will occur after loading config." -ForegroundColor Cyan
}
Write-Host ""

# ============================================================================
# AZURE AUTHENTICATION
# ============================================================================

Write-Host "Checking Azure authentication..." -ForegroundColor Cyan

try {
    # Check if already logged in
    $currentAccount = az account show 2>$null | ConvertFrom-Json
    if (-not $currentAccount) {
        Write-Host "Not connected to Azure. Initiating login..." -ForegroundColor Yellow
        az login | Out-Null
        $currentAccount = az account show 2>$null | ConvertFrom-Json
        if (-not $currentAccount) {
            throw "Azure login failed"
        }
    }

    Write-Host "Connected to Azure as: $($currentAccount.user.name)" -ForegroundColor Green
    Write-Host "Current subscription: $($currentAccount.name) ($($currentAccount.id))" -ForegroundColor Green

    # Set subscription context if SubscriptionId is provided and different from current
    if ($SubscriptionId) {
        if ($currentAccount.id -ne $SubscriptionId) {
            Write-Host "Switching to subscription: $SubscriptionId" -ForegroundColor Yellow
            try {
                az account set --subscription $SubscriptionId 2>$null
                if ($LASTEXITCODE -ne 0) { throw "az account set failed" }
                $newAccount = az account show 2>$null | ConvertFrom-Json
                Write-Host "Successfully switched to subscription: $($newAccount.name)" -ForegroundColor Green
            }
            catch {
                Write-Host "Failed to switch to subscription $SubscriptionId. Error: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "Available subscriptions:" -ForegroundColor Yellow
                az account list --query "[].{Name:name, Id:id, State:state}" -o table
                throw "Invalid or inaccessible subscription ID: $SubscriptionId"
            }
        }
        else {
            Write-Host "Already using target subscription" -ForegroundColor Green
        }
    }

    # Verify subscription access and get details
    $subscription = az account show 2>$null | ConvertFrom-Json
    Write-Host "Subscription verified: $($subscription.name) (State: $($subscription.state))" -ForegroundColor Green

    # Check if subscription is active
    if ($subscription.state -ne 'Enabled') {
        throw "Subscription '$($subscription.name)' is not in an active state (Current state: $($subscription.state))"
    }

    Write-Host "Azure authentication successful!" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "Azure authentication failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please ensure you have:" -ForegroundColor Yellow
    Write-Host "1. Azure CLI installed (https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)" -ForegroundColor Yellow
    Write-Host "2. Proper access to the target Azure subscription" -ForegroundColor Yellow
    Write-Host "3. Valid Azure credentials" -ForegroundColor Yellow
    throw "Azure authentication failed: $($_.Exception.Message)"
}

# ============================================================================
# MANAGED IDENTITY FUNCTIONS
# ============================================================================

function Enable-AutomationAccountManagedIdentity {
    param(
        [string]$SubscriptionId,
        [string]$ResourceGroupName,
        [string]$AutomationAccountName,
        [switch]$WhatIf
    )

    Write-DeploymentLog "Enabling system-assigned managed identity on Automation Account: $AutomationAccountName"

    if ($WhatIf) {
        Write-DeploymentLog "[WHATIF] Would enable managed identity on $AutomationAccountName" -Level Warning
        return $null
    }

    try {
        # Check if Automation Account exists
        $automationAccount = az automation account show --resource-group $ResourceGroupName --name $AutomationAccountName 2>$null | ConvertFrom-Json
        if (-not $automationAccount) {
            Write-DeploymentLog "Automation Account '$AutomationAccountName' not found in resource group '$ResourceGroupName'" -Level Error
            throw "Automation Account not found"
        }

        # Enable managed identity using REST API
        $resourceUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Automation/automationAccounts/${AutomationAccountName}?api-version=2020-01-13-preview"

        # Get current automation account properties
        $currentAccountJson = az rest --method GET --url $resourceUrl 2>$null

        if ($currentAccountJson) {
            $accountData = $currentAccountJson | ConvertFrom-Json

            # Check if managed identity is already enabled
            if ($accountData.identity -and $accountData.identity.type -eq "SystemAssigned" -and $accountData.identity.principalId) {
                Write-DeploymentLog "Managed identity already enabled" -Level Warning
                return $accountData.identity.principalId
            }

            # Enable managed identity via PATCH
            $patchBody = @{ identity = @{ type = "SystemAssigned" } } | ConvertTo-Json -Depth 10 -Compress
            $resultJson = az rest --method PATCH --url $resourceUrl --body $patchBody 2>$null

            if ($resultJson) {
                $updatedAccount = $resultJson | ConvertFrom-Json
                Write-DeploymentLog "Successfully enabled managed identity" -Level Success
                return $updatedAccount.identity.principalId
            } else {
                Write-DeploymentLog "Failed to enable managed identity" -Level Error
                throw "Failed to enable managed identity"
            }
        } else {
            Write-DeploymentLog "Failed to get Automation Account details" -Level Error
            throw "Failed to get Automation Account"
        }
    }
    catch {
        Write-DeploymentLog "Error enabling managed identity: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Set-AzureRoleAssignments {
    param(
        [string]$PrincipalId,
        [string]$SubscriptionId,
        [string]$ResourceGroupName,
        [switch]$WhatIf
    )
    
    Write-DeploymentLog "Assigning Azure RBAC roles to managed identity"
    
    # Required roles for the managed identity
    $requiredRoles = @(
        @{
            RoleDefinitionName = "Contributor"
            Scope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName"
            Description = "Manage resources in the resource group"
        },
        @{
            RoleDefinitionName = "Logic App Contributor"
            Scope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName"
            Description = "Manage Logic Apps"
        }
    )
    
    foreach ($role in $requiredRoles) {
        Write-DeploymentLog "Assigning role: $($role.RoleDefinitionName) at scope: $($role.Scope)"

        if ($WhatIf) {
            Write-DeploymentLog "[WHATIF] Would assign role: $($role.RoleDefinitionName)" -Level Warning
            continue
        }

        try {
            # Check if role assignment already exists
            $existingAssignment = az role assignment list --assignee $PrincipalId --role $role.RoleDefinitionName --scope $role.Scope 2>$null | ConvertFrom-Json

            if ($existingAssignment -and $existingAssignment.Count -gt 0) {
                Write-DeploymentLog "Role assignment already exists: $($role.RoleDefinitionName)" -Level Warning
                continue
            }

            # Create role assignment
            az role assignment create --assignee-object-id $PrincipalId --assignee-principal-type ServicePrincipal --role $role.RoleDefinitionName --scope $role.Scope 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "az role assignment create failed" }
            Write-DeploymentLog "Successfully assigned role: $($role.RoleDefinitionName)" -Level Success
        }
        catch {
            Write-DeploymentLog "Error assigning role $($role.RoleDefinitionName): $($_.Exception.Message)" -Level Error
            # Don't throw - continue with other roles
        }
    }
}

function Initialize-ManagedIdentities {
    param(
        [object]$DeployConfig,
        [string]$AutomationAccountName,
        [switch]$CreateUserAssignedIdentity,
        [switch]$WhatIf
    )
    
    Write-DeploymentLog "Initializing managed identities for the solution" -Level Info
    
    try {
        # Enable system-assigned managed identity on Automation Account
        $systemAssignedPrincipalId = Enable-AutomationAccountManagedIdentity -SubscriptionId $DeployConfig.subscriptionId -ResourceGroupName $DeployConfig.resourceGroupName -AutomationAccountName $AutomationAccountName -WhatIf:$WhatIf
        
        if ($systemAssignedPrincipalId -and -not $WhatIf) {
            Write-DeploymentLog "System-assigned managed identity Principal ID: $systemAssignedPrincipalId" -Level Success
            
            # Wait a moment for the identity to propagate
            Write-DeploymentLog "Waiting for managed identity to propagate..."
            Start-Sleep -Seconds 30
            
            # Assign Azure RBAC roles
            Set-AzureRoleAssignments -PrincipalId $systemAssignedPrincipalId -SubscriptionId $DeployConfig.subscriptionId -ResourceGroupName $DeployConfig.resourceGroupName -WhatIf:$WhatIf
            
            # Grant SharePoint permissions to managed identity
            Grant-SharePointPermissionsToManagedIdentity -PrincipalId $systemAssignedPrincipalId -AutomationAccountName $AutomationAccountName -WhatIf:$WhatIf
            
            return @{
                SystemAssignedPrincipalId = $systemAssignedPrincipalId
                UserAssignedPrincipalId = $null
            }
        }
        
        # Create user-assigned managed identity if requested
        if ($CreateUserAssignedIdentity) {
            $identityName = "$AutomationAccountName-identity"
            $rgInfo = az group show --name $DeployConfig.resourceGroupName 2>$null | ConvertFrom-Json
            $location = $rgInfo.location

            Write-DeploymentLog "Creating user-assigned managed identity: $identityName"

            if ($WhatIf) {
                Write-DeploymentLog "[WHATIF] Would create user-assigned managed identity: $identityName" -Level Warning
            } else {
                try {
                    # Check if identity already exists
                    $existingIdentity = az identity show --resource-group $DeployConfig.resourceGroupName --name $identityName 2>$null | ConvertFrom-Json

                    if ($existingIdentity) {
                        Write-DeploymentLog "User-assigned managed identity '$identityName' already exists" -Level Warning
                        $userAssignedPrincipalId = $existingIdentity.principalId
                    } else {
                        # Create new user-assigned managed identity
                        $identity = az identity create --resource-group $DeployConfig.resourceGroupName --name $identityName --location $location 2>$null | ConvertFrom-Json
                        Write-DeploymentLog "Successfully created user-assigned managed identity" -Level Success
                        $userAssignedPrincipalId = $identity.principalId
                    }

                    if ($userAssignedPrincipalId) {
                        # Assign roles to user-assigned identity as well
                        Set-AzureRoleAssignments -PrincipalId $userAssignedPrincipalId -SubscriptionId $DeployConfig.subscriptionId -ResourceGroupName $DeployConfig.resourceGroupName -WhatIf:$WhatIf
                    }
                }
                catch {
                    Write-DeploymentLog "Error creating user-assigned managed identity: $($_.Exception.Message)" -Level Error
                }
            }
        }
        
        return @{
            SystemAssignedPrincipalId = $systemAssignedPrincipalId
            UserAssignedPrincipalId = $userAssignedPrincipalId
        }
    }
    catch {
        Write-DeploymentLog "Error during managed identity initialization: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Grant-SharePointPermissionsToManagedIdentity {
    param(
        [string]$PrincipalId,
        [string]$AutomationAccountName,
        [switch]$WhatIf
    )

    Write-DeploymentLog "Granting SharePoint permissions to managed identity ($PrincipalId)..." -Level Info

    if ($WhatIf) {
        Write-DeploymentLog "[WHATIF] Would grant SharePoint Sites.FullControl.All to principal $PrincipalId" -Level Warning
        return
    }

    try {
        # SharePoint Online resource app ID (constant across all tenants)
        $sharePointAppId = '00000003-0000-0ff1-ce00-000000000000'

        # Look up the SharePoint service principal to get the AppRoleId for Sites.FullControl.All
        $spResource = az ad sp show --id $sharePointAppId 2>$null | ConvertFrom-Json
        if (-not $spResource) {
            Write-DeploymentLog "Could not find SharePoint service principal" -Level Error
            return
        }
        $fullControlRole = $spResource.appRoles | Where-Object { $_.value -eq 'Sites.FullControl.All' }

        if (-not $fullControlRole) {
            Write-DeploymentLog "Could not find Sites.FullControl.All app role on SharePoint service principal" -Level Error
            return
        }

        # Check if assignment already exists using Microsoft Graph
        $graphUrl = "https://graph.microsoft.com/v1.0/servicePrincipals/$PrincipalId/appRoleAssignments"
        $existingAssignments = az rest --method GET --url $graphUrl 2>$null | ConvertFrom-Json
        $alreadyAssigned = $existingAssignments.value | Where-Object { $_.appRoleId -eq $fullControlRole.id -and $_.resourceId -eq $spResource.id }

        if ($alreadyAssigned) {
            Write-DeploymentLog "SharePoint Sites.FullControl.All already granted to $AutomationAccountName" -Level Info
            return
        }

        # Create app role assignment via Microsoft Graph
        $assignmentBody = @{
            principalId = $PrincipalId
            resourceId  = $spResource.id
            appRoleId   = $fullControlRole.id
        } | ConvertTo-Json -Compress
        az rest --method POST --url $graphUrl --body $assignmentBody --headers "Content-Type=application/json" 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Failed to create app role assignment" }

        Write-DeploymentLog "Granted SharePoint Sites.FullControl.All to $AutomationAccountName" -Level Success
    }
    catch {
        Write-DeploymentLog "Failed to grant SharePoint permissions: $($_.Exception.Message)" -Level Warning
        Write-DeploymentLog "You may need to grant permissions manually. Use the Azure Portal or run:" -Level Warning
        Write-DeploymentLog "  az rest --method POST --url 'https://graph.microsoft.com/v1.0/servicePrincipals/$PrincipalId/appRoleAssignments' --body '<body>'" -Level Warning
    }
}



# ============================================================================
# PRESET CONFIGURATIONS
# ============================================================================

function Get-PresetConfiguration {
    param([string]$PresetName)
    
    $presets = @{
        'Minimal' = @{
            runbooksToDeploy = @('GetSiteInformation')
            logicAppsToDeploy = @()
            deploySharePointConnector = $false
            deployAutomationConnector = $true
            createManagedIdentity = $true
            description = 'Minimal deployment for basic site information retrieval'
        }
        'Full' = @{
            runbooksToDeploy = @('ArchiveSite', 'GetSiteInformation', 'UpdateProjectDates', 'UpdateProjectManager')
            logicAppsToDeploy = @('ChangeArchiveState', 'PhaseChanged', 'ProjectInfoChanged', 'RequestProjectAccess')
            deploySharePointConnector = $true
            deployAutomationConnector = $true
            createManagedIdentity = $true
            description = 'Complete deployment with all components'
        }
        'Testing' = @{
            runbooksToDeploy = @('GetSiteInformation', 'UpdateProjectDates')
            logicAppsToDeploy = @('PhaseChanged')
            deploySharePointConnector = $true
            deployAutomationConnector = $true
            createManagedIdentity = $true
            description = 'Testing environment with core functionality only'
        }
        'ArchiveOnly' = @{
            runbooksToDeploy = @('ArchiveSite')
            logicAppsToDeploy = @('ChangeArchiveState')
            deploySharePointConnector = $false
            deployAutomationConnector = $true
            createManagedIdentity = $true
            description = 'Archive functionality only'
        }
        'UpdateOnly' = @{
            runbooksToDeploy = @('UpdateProjectDates', 'UpdateProjectManager')
            logicAppsToDeploy = @('PhaseChanged', 'ProjectInfoChanged', 'RequestProjectAccess')
            deploySharePointConnector = $true
            deployAutomationConnector = $true
            createManagedIdentity = $true
            description = 'Project update functionality only'
        }
        'LogicAppsOnly' = @{
            runbooksToDeploy = @()
            logicAppsToDeploy = @('ChangeArchiveState', 'PhaseChanged', 'ProjectInfoChanged', 'RequestProjectAccess')
            deploySharePointConnector = $true
            deployAutomationConnector = $true
            createManagedIdentity = $true
            description = 'Logic Apps workflow automation only'
        }
    }
    
    return $presets[$PresetName]
}

# ============================================================================
# EXAMPLES FUNCTIONS  
# ============================================================================

function Show-DeploymentExamples {
    Write-Host @"

╔══════════════════════════════════════════════════════════════════════════════════════╗
║                    PROSJEKTPORTALEN DEPLOYMENT EXAMPLES                             ║ 
╚══════════════════════════════════════════════════════════════════════════════════════╝

🎯 PRESET DEPLOYMENTS (Recommended for most scenarios):
   ────────────────────────────────────────────────────────────────────────────────

   # Full production deployment
   .\Deploy-Solution.ps1 -Preset Full -SubscriptionId "guid" -SharePointTenant "contoso.sharepoint.com" -HubSiteUrl "https://contoso.sharepoint.com/sites/projectportal" -SharePointConnectionEmail "admin@contoso.com"

   # Minimal testing deployment
   .\Deploy-Solution.ps1 -Preset Minimal -SubscriptionId "guid" -SharePointTenant "contoso.sharepoint.com" -HubSiteUrl "https://contoso.sharepoint.com/sites/projectportal" -SharePointConnectionEmail "admin@contoso.com" -Environment "test"

   # Archive functionality only
   .\Deploy-Solution.ps1 -Preset ArchiveOnly -SubscriptionId "guid" -SharePointTenant "contoso.sharepoint.com" -HubSiteUrl "https://contoso.sharepoint.com/sites/projectportal" -SharePointConnectionEmail "admin@contoso.com"

📋 CONFIGURATION FILE DEPLOYMENT:
   ────────────────────────────────────────────────────────────────────────────────

   # Deploy using hierarchical config directory
   .\Deploy-Solution.ps1 -ConfigurationFile "config\config.json"
   
   # Deploy with config file but override specific parameters
   .\Deploy-Solution.ps1 -ConfigurationFile "config\config.json" -Environment "test"

   # Validate configuration without deploying
   .\Deploy-Solution.ps1 -ConfigurationFile "config\config.json" -ValidateOnly
   
   📝 Hierarchical config directory:
     config.json          - Root: prefix, environment, component selection
     azure.json           - Azure: subscription, resource group, location
     sharepoint.json      - SharePoint: tenant, hub site, service account
     automation.json      - Automation: language, log level
     runbooks.json        - All runbook settings (grouped by name)
     logic-apps.json      - All logic app settings (grouped by name)
     connectors.json      - All connector settings (grouped by name)

🔧 CUSTOM SELECTIVE DEPLOYMENT:
   ────────────────────────────────────────────────────────────────────────────────────

   # Deploy only specific runbooks
   .\.\Deploy-Solution.ps1 -SubscriptionId "guid" -SharePointTenant "contoso.sharepoint.com" -HubSiteUrl "https://contoso.sharepoint.com/sites/projectportal" -SharePointConnectionEmail "admin@contoso.com" -RunbooksToDeploy "ArchiveSite","UpdateProjectManager"

   # Deploy specific logic apps without SharePoint connector
   .\Deploy-Solution.ps1 -SubscriptionId "guid" -SharePointTenant "contoso.sharepoint.com" -HubSiteUrl "https://contoso.sharepoint.com/sites/projectportal" -SharePointConnectionEmail "admin@contoso.com" -LogicAppsToDeploy "PhaseChanged" -SkipSharePointConnector

⚙️  AVAILABLE PRESETS:
   ────────────────────────────────────────────────────────────────────────────────────
   
   • Minimal      - Basic site information retrieval only
   • Full         - Complete deployment with all components
   • Testing      - Core functionality for testing environments  
   • ArchiveOnly  - Archive functionality only
   • UpdateOnly   - Project update functionality only
   • LogicAppsOnly- Logic Apps workflow automation only

📚 HELP:
   ────────────────────────────────────────────────────────────────────────────────────

   Get-Help .\Deploy-Solution.ps1 -Full

"@ -ForegroundColor Cyan
}

# Initialize logging
$LogPath = Join-Path $PSScriptRoot "logs\deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$null = New-Item -Path (Split-Path $LogPath) -ItemType Directory -Force

function Write-DeploymentLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    
    Add-Content -Path $LogPath -Value $logMessage
    
    switch ($Level) {
        'Error'   { Write-Host $Message -ForegroundColor Red }
        'Warning' { Write-Warning $Message }
        'Success' { Write-Host $Message -ForegroundColor Green }
        default   { Write-Information $Message }
    }
}

# Handle ShowExamples parameter
if ($ShowExamples) {
    Show-DeploymentExamples
    return
}

# ============================================================================
# CONFIGURATION PROCESSING
# ============================================================================

function Read-ConfigFile {
    <#
    .SYNOPSIS
        Reads a JSON config file and strips the Value/Description wrapper format.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path -PathType Leaf)) {
        return $null
    }
    
    $raw = Get-Content -Path $Path -Raw | ConvertFrom-Json
    
    function ConvertObject($obj) {
        if ($null -eq $obj) { return $null }
        
        if ($obj -is [PSCustomObject]) {
            $result = @{}
            foreach ($property in $obj.PSObject.Properties) {
                $value = $property.Value
                if ($value -is [PSCustomObject] -and 
                    $value.PSObject.Properties.Name -contains 'Value') {
                    $result[$property.Name] = ConvertObject($value.Value)
                } else {
                    $result[$property.Name] = ConvertObject($value)
                }
            }
            return [PSCustomObject]$result
        } elseif ($obj.GetType().Name -eq 'Object[]' -or $obj -is [Array]) {
            $result = @()
            foreach ($item in $obj) {
                $result += ConvertObject($item)
            }
            return $result
        } else {
            return $obj
        }
    }
    
    return ConvertObject($raw)
}

function Read-HierarchicalConfig {
    <#
    .SYNOPSIS
        Loads the hierarchical configuration directory.
    .DESCRIPTION
        Given a root config.json path, derives the config directory and loads:
        - config.json      (projectPrefix, environment, component selection)
        - azure.json       (subscriptionId, resourceGroupName, location, tags)
        - sharepoint.json  (tenant, hubSiteUrl, serviceAccountEmail, list GUIDs)
        - automation.json  (language, logLevel)
        - runbooks.json    (all runbook settings keyed by runbook name)
        - logic-apps.json  (all logic app settings keyed by logic app name)
        - connectors.json  (all connector settings keyed by connector name)
        Only settings for selected components are merged into the result.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$RootConfigPath
    )
    
    $configDir = Split-Path $RootConfigPath -Parent
    
    # Load root config
    $rootConfig = Read-ConfigFile -Path $RootConfigPath
    if (-not $rootConfig) {
        throw "Failed to read root configuration file: $RootConfigPath"
    }
    
    # Load area-level configs
    $azureConfig = Read-ConfigFile -Path (Join-Path $configDir 'azure.json')
    if (-not $azureConfig) {
        throw "Missing required config file: $(Join-Path $configDir 'azure.json')"
    }
    
    $spConfig = Read-ConfigFile -Path (Join-Path $configDir 'sharepoint.json')
    if (-not $spConfig) {
        throw "Missing required config file: $(Join-Path $configDir 'sharepoint.json')"
    }
    
    $autoConfig = Read-ConfigFile -Path (Join-Path $configDir 'automation.json')
    
    # Resolve component selection
    $components = $rootConfig.components
    $runbookNames = @($components.runbooks)
    $logicAppNames = @($components.logicApps)
    $deploySharePointConnector = $components.connectors.SharePointOnline -eq $true
    $deployAutomationConnector = $components.connectors.Automation -eq $true
    
    # Load type-level configs
    $runbooksConfig = Read-ConfigFile -Path (Join-Path $configDir 'runbooks.json')
    $logicAppsConfig = Read-ConfigFile -Path (Join-Path $configDir 'logic-apps.json')
    $connectorsConfig = Read-ConfigFile -Path (Join-Path $configDir 'connectors.json')
    
    # Merge settings from selected components only
    $componentSettings = @{}
    
    foreach ($runbook in $runbookNames) {
        if ($runbooksConfig -and $runbooksConfig.PSObject.Properties.Name -contains $runbook) {
            $rbSettings = $runbooksConfig.$runbook
            if ($rbSettings -is [PSCustomObject]) {
                foreach ($prop in $rbSettings.PSObject.Properties) {
                    $componentSettings[$prop.Name] = $prop.Value
                }
            }
        }
        Write-DeploymentLog "  Component: runbook/$runbook" -Level Info
    }
    
    foreach ($logicApp in $logicAppNames) {
        if ($logicAppsConfig -and $logicAppsConfig.PSObject.Properties.Name -contains $logicApp) {
            $laSettings = $logicAppsConfig.$logicApp
            if ($laSettings -is [PSCustomObject]) {
                foreach ($prop in $laSettings.PSObject.Properties) {
                    $componentSettings[$prop.Name] = $prop.Value
                }
            }
        }
        Write-DeploymentLog "  Component: logic-app/$logicApp" -Level Info
    }
    
    if ($deploySharePointConnector) {
        Write-DeploymentLog "  Component: connector/SharePointOnline" -Level Info
    }
    if ($deployAutomationConnector) {
        Write-DeploymentLog "  Component: connector/Automation" -Level Info
    }
    
    # Build unified deployment config
    $config = [PSCustomObject]@{
        # azure.json
        subscriptionId    = $azureConfig.subscriptionId
        resourceGroupName = $azureConfig.resourceGroupName
        location          = $azureConfig.location
        tags              = $azureConfig.tags
        # sharepoint.json
        tenant              = $spConfig.tenant
        hubSiteUrl          = $spConfig.hubSiteUrl
        serviceAccountEmail = $spConfig.serviceAccountEmail
        sharePointSettings  = [PSCustomObject]@{
            projectListGuid = $spConfig.projectListGuid
            listViewGuid    = $spConfig.listViewGuid
        }
        # automation.json
        language = if ($autoConfig) { $autoConfig.language } else { $null }
        logLevel = if ($autoConfig) { $autoConfig.logLevel } else { $null }
        # root config.json
        deploymentSettings = [PSCustomObject]@{
            projectPrefix             = $rootConfig.projectPrefix
            environment               = $rootConfig.environment
            runbooksToDeploy          = $runbookNames
            logicAppsToDeploy         = $logicAppNames
            deploySharePointConnector = $deploySharePointConnector
            deployAutomationConnector = $deployAutomationConnector
        }
        # Merged from runbooks.json / logic-apps.json (selected components only)
        completionPhaseName  = $componentSettings['completionPhaseName']
        finishedPhaseText    = $componentSettings['finishedPhaseText']
        archiveStatusName    = $componentSettings['archiveStatusName']
        archiveBannerText    = $componentSettings['archiveBannerText']
        defaultManagerRole   = $componentSettings['defaultManagerRole']
        folderStructure      = $componentSettings['folderStructure']
        dateCalculationRules = $componentSettings['dateCalculationRules']
    }
    
    return $config
}

function Get-DeploymentConfiguration {
    if ($PSCmdlet.ParameterSetName -eq 'ConfigFile') {
        Write-DeploymentLog "Loading hierarchical configuration from: $ConfigurationFile"
        
        $config = Read-HierarchicalConfig -RootConfigPath $ConfigurationFile
        
        # CLI parameter overrides
        if ($SubscriptionId) { $config.subscriptionId = $SubscriptionId }
        if ($ResourceGroupName -ne 'RG-Prosjektportalen365') { $config.resourceGroupName = $ResourceGroupName }
        if ($Location -ne 'norwayeast') { $config.location = $Location }
        if ($SharePointTenant) { $config.tenant = $SharePointTenant }
        if ($HubSiteUrl) { $config.hubSiteUrl = $HubSiteUrl }
        if ($ProjectPrefix -ne 'PP365') { $config.deploymentSettings.projectPrefix = $ProjectPrefix }
        if ($Environment -ne 'prod') { $config.deploymentSettings.environment = $Environment }
        
        # Validate required properties
        $requiredProperties = @(
            @{Name = 'subscriptionId'; DisplayName = 'Subscription ID (azure.json)'},
            @{Name = 'tenant'; DisplayName = 'SharePoint Tenant (sharepoint.json)'},
            @{Name = 'hubSiteUrl'; DisplayName = 'Hub Site URL (sharepoint.json)'},
            @{Name = 'serviceAccountEmail'; DisplayName = 'Service Account Email (sharepoint.json)'}
        )
        
        $missingProperties = @()
        foreach ($prop in $requiredProperties) {
            if (-not $config.($prop.Name)) {
                $missingProperties += $prop.DisplayName
            }
        }
        
        if ($missingProperties.Count -gt 0) {
            Write-Host "Configuration is missing required properties:" -ForegroundColor Red
            foreach ($missing in $missingProperties) {
                Write-Host "  - $missing" -ForegroundColor Red
            }
            throw "Configuration validation failed. Missing: $($missingProperties -join ', ')"
        }
        
        # Format validation
        if ($config.subscriptionId -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
            throw "Invalid subscriptionId in azure.json. Must be a valid GUID."
        }
        if ($config.tenant -notmatch '^[a-zA-Z0-9][a-zA-Z0-9-]*\.sharepoint\.com$') {
            throw "Invalid tenant in sharepoint.json. Must be like 'contoso.sharepoint.com'"
        }
        if ($config.hubSiteUrl -notmatch '^https://[a-zA-Z0-9][a-zA-Z0-9-]*\.sharepoint\.com/sites/[a-zA-Z0-9-]+$') {
            throw "Invalid hubSiteUrl in sharepoint.json. Must be like 'https://contoso.sharepoint.com/sites/sitename'"
        }
        if ($config.serviceAccountEmail -notmatch '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
            throw "Invalid serviceAccountEmail in sharepoint.json. Must be a valid email address."
        }
        
        Write-DeploymentLog "Hierarchical configuration loaded successfully" -Level Success
        return $config
        
    } elseif ($PSCmdlet.ParameterSetName -eq 'Preset') {
        Write-DeploymentLog "Using preset configuration: $Preset"
        $presetConfig = Get-PresetConfiguration -PresetName $Preset
        
        $config = @{
            subscriptionId = $SubscriptionId
            resourceGroupName = $ResourceGroupName
            location = $Location
            tenant = $SharePointTenant
            hubSiteUrl = $HubSiteUrl
            serviceAccountEmail = $SharePointConnectionEmail
            deploymentSettings = @{
                projectPrefix = $ProjectPrefix
                environment = $Environment
                runbooksToDeploy = $presetConfig.runbooksToDeploy
                logicAppsToDeploy = $presetConfig.logicAppsToDeploy
                deploySharePointConnector = $presetConfig.deploySharePointConnector
                deployAutomationConnector = $presetConfig.deployAutomationConnector
            }
        }
        
        if ($ProjectListGuid) {
            $config.sharePointSettings = @{ projectListGuid = $ProjectListGuid }
            if ($ListViewGuid) { $config.sharePointSettings.listViewGuid = $ListViewGuid }
        }
        
        # Load component settings from type-level config files if available
        $defaultConfigDir = Join-Path $PSScriptRoot 'config'
        if (Test-Path $defaultConfigDir) {
            $runbooksConfig = Read-ConfigFile -Path (Join-Path $defaultConfigDir 'runbooks.json')
            $logicAppsConfig = Read-ConfigFile -Path (Join-Path $defaultConfigDir 'logic-apps.json')
            $autoConfig = Read-ConfigFile -Path (Join-Path $defaultConfigDir 'automation.json')
            
            foreach ($runbook in @($presetConfig.runbooksToDeploy)) {
                if ($runbooksConfig -and $runbooksConfig.PSObject.Properties.Name -contains $runbook) {
                    $rbSettings = $runbooksConfig.$runbook
                    if ($rbSettings -is [PSCustomObject]) {
                        foreach ($prop in $rbSettings.PSObject.Properties) {
                            if (-not $config.ContainsKey($prop.Name)) { $config[$prop.Name] = $prop.Value }
                        }
                    }
                }
            }
            foreach ($logicApp in @($presetConfig.logicAppsToDeploy)) {
                if ($logicAppsConfig -and $logicAppsConfig.PSObject.Properties.Name -contains $logicApp) {
                    $laSettings = $logicAppsConfig.$logicApp
                    if ($laSettings -is [PSCustomObject]) {
                        foreach ($prop in $laSettings.PSObject.Properties) {
                            if (-not $config.ContainsKey($prop.Name)) { $config[$prop.Name] = $prop.Value }
                        }
                    }
                }
            }
            if ($autoConfig) {
                if ($autoConfig.language -and -not $config.ContainsKey('language')) { $config['language'] = $autoConfig.language }
                if ($autoConfig.logLevel -and -not $config.ContainsKey('logLevel')) { $config['logLevel'] = $autoConfig.logLevel }
            }
        }
        
        Write-DeploymentLog "Preset Description: $($presetConfig.description)" -Level Info
        return [PSCustomObject]$config
        
    } else {
        # Interactive parameter set
        Write-DeploymentLog "Using interactive parameter configuration"
        
        $runbooks = if ($RunbooksToDeploy) { $RunbooksToDeploy } else { @('ArchiveSite', 'GetSiteInformation', 'UpdateProjectDates', 'UpdateProjectManager') }
        $logicApps = if ($LogicAppsToDeploy) { $LogicAppsToDeploy } else { @('ChangeArchiveState', 'PhaseChanged', 'ProjectInfoChanged', 'RequestProjectAccess') }
        
        $config = @{
            subscriptionId = $SubscriptionId
            resourceGroupName = $ResourceGroupName
            location = $Location
            tenant = $SharePointTenant
            hubSiteUrl = $HubSiteUrl
            serviceAccountEmail = $SharePointConnectionEmail
            deploymentSettings = @{
                projectPrefix = $ProjectPrefix
                environment = $Environment
                runbooksToDeploy = $runbooks
                logicAppsToDeploy = $logicApps
                deploySharePointConnector = -not $SkipSharePointConnector.IsPresent
                deployAutomationConnector = -not $SkipAutomationConnector.IsPresent
            }
            completionPhaseName = $FinishedPhaseText
        }
        
        if ($ProjectListGuid) {
            $config.sharePointSettings = @{ projectListGuid = $ProjectListGuid }
            if ($ListViewGuid) { $config.sharePointSettings.listViewGuid = $ListViewGuid }
        }
        
        # Load component settings from type-level config files if available
        $defaultConfigDir = Join-Path $PSScriptRoot 'config'
        if (Test-Path $defaultConfigDir) {
            $runbooksConfig = Read-ConfigFile -Path (Join-Path $defaultConfigDir 'runbooks.json')
            $logicAppsConfig = Read-ConfigFile -Path (Join-Path $defaultConfigDir 'logic-apps.json')
            $autoConfig = Read-ConfigFile -Path (Join-Path $defaultConfigDir 'automation.json')
            
            foreach ($runbook in $runbooks) {
                if ($runbooksConfig -and $runbooksConfig.PSObject.Properties.Name -contains $runbook) {
                    $rbSettings = $runbooksConfig.$runbook
                    if ($rbSettings -is [PSCustomObject]) {
                        foreach ($prop in $rbSettings.PSObject.Properties) {
                            if (-not $config.ContainsKey($prop.Name)) { $config[$prop.Name] = $prop.Value }
                        }
                    }
                }
            }
            foreach ($logicApp in $logicApps) {
                if ($logicAppsConfig -and $logicAppsConfig.PSObject.Properties.Name -contains $logicApp) {
                    $laSettings = $logicAppsConfig.$logicApp
                    if ($laSettings -is [PSCustomObject]) {
                        foreach ($prop in $laSettings.PSObject.Properties) {
                            if (-not $config.ContainsKey($prop.Name)) { $config[$prop.Name] = $prop.Value }
                        }
                    }
                }
            }
            if ($autoConfig) {
                if ($autoConfig.language -and -not $config.ContainsKey('language')) { $config['language'] = $autoConfig.language }
                if ($autoConfig.logLevel -and -not $config.ContainsKey('logLevel')) { $config['logLevel'] = $autoConfig.logLevel }
            }
        }
        
        return [PSCustomObject]$config
    }
}

# Get configuration based on parameter set
$deployConfig = Get-DeploymentConfiguration

# Validate that configuration was loaded successfully
if (-not $deployConfig) {
    throw "Failed to load deployment configuration. Please check your parameters or configuration file."
}

# Show what will be deployed
Write-DeploymentLog "=== DEPLOYMENT CONFIGURATION ===" -Level Success
Write-DeploymentLog "Environment: $($deployConfig.deploymentSettings.environment)" -Level Info  
Write-DeploymentLog "Project Prefix: $($deployConfig.deploymentSettings.projectPrefix)" -Level Info
Write-DeploymentLog "Runbooks to deploy: $($deployConfig.deploymentSettings.runbooksToDeploy -join ', ')" -Level Info
Write-DeploymentLog "Logic Apps to deploy: $($deployConfig.deploymentSettings.logicAppsToDeploy -join ', ')" -Level Info
Write-DeploymentLog "SharePoint Connector: $($deployConfig.deploymentSettings.deploySharePointConnector)" -Level Info
Write-DeploymentLog "Automation Connector: $($deployConfig.deploymentSettings.deployAutomationConnector)" -Level Info

if ($WhatIf) {
    Write-DeploymentLog "WhatIf mode - showing configuration only, no deployment will occur" -Level Warning
    Write-DeploymentLog "Configuration validated successfully. Use without -WhatIf to deploy." -Level Success
    return
}

# ============================================================================
# PREREQUISITES AND VALIDATION
# ============================================================================

function Test-Prerequisites {
    param($Config)
    
    Write-DeploymentLog "Validating prerequisites..." -Level Info
    $issues = @()
    
    # Validate config object structure
    if (-not $Config) {
        $issues += "Configuration object is null or missing"
        return $issues
    }
    
    if (-not $Config.deploymentSettings) {
        $issues += "Configuration is missing deploymentSettings section"
        return $issues
    }
    
    # Test Azure CLI connection
    try {
        $azAccount = az account show 2>$null | ConvertFrom-Json
        if (-not $azAccount) {
            $issues += "Not connected to Azure. Please run 'az login'"
        } elseif ($Config.subscriptionId -and $azAccount.id -ne $Config.subscriptionId) {
            $issues += "Connected to wrong subscription. Expected: $($Config.subscriptionId), Current: $($azAccount.id)"
        }
    } catch {
        $issues += "Azure CLI not available or not connected: $($_.Exception.Message)"
    }
    
    # Test SharePoint connection (only if SharePoint connector will be deployed)
    if ($Config.deploymentSettings.deploySharePointConnector -eq $true) {
        try {
            $spConnection = Get-PnPConnection -ErrorAction SilentlyContinue
            if (-not $spConnection -or ($Config.tenant -and $spConnection.Url -notlike "*$($Config.tenant)*")) {
                if ($Config.tenant) {
                    $issues += "Not connected to SharePoint tenant: $($Config.tenant)"
                } else {
                    $issues += "SharePoint tenant not specified in configuration"
                }
            }
        } catch {
            $issues += "PnP PowerShell not available or not connected to SharePoint: $($_.Exception.Message)"
        }
    
        # Test if hub site exists
        if ($Config.hubSiteUrl) {
            try {
                $hubSite = Get-PnPTenantSite -Identity $Config.hubSiteUrl -ErrorAction SilentlyContinue
                if (-not $hubSite) {
                    $issues += "Hub site not found: $($Config.hubSiteUrl)"
                }
            } catch {
                $issues += "Cannot validate hub site existence: $($Config.hubSiteUrl). Error: $($_.Exception.Message)"
            }
        } else {
            $issues += "Hub site URL not specified in configuration"
        }
    }
    
    # Test if template file exists
    try {
        $templatePath = Join-Path $PSScriptRoot "Infrastructure\main.bicep"
        if (-not (Test-Path $templatePath)) {
            $issues += "Template file not found: $templatePath"
        }
    } catch {
        $issues += "Error checking template file: $($_.Exception.Message)"
    }
    
    return $issues
}

# Run prerequisites check
if (-not $deployConfig -or -not $deployConfig.deploymentSettings) {
    throw "Invalid deployment configuration. Missing required configuration structure."
}

# ============================================================================
# SHAREPOINT CONNECTION
# ============================================================================

if ($deployConfig.deploymentSettings.deploySharePointConnector -eq $true) {
    Write-Host "Checking SharePoint connection..." -ForegroundColor Cyan

    $tenantUrl = "https://$($deployConfig.tenant)"
    $hubUrl    = $deployConfig.hubSiteUrl

    # Resolve ClientId: parameter takes priority, then config file value
    $resolvedClientId = if ($PnPClientId) {
        $PnPClientId
    } elseif ($deployConfig.pnpClientId) {
        $deployConfig.pnpClientId
    } else {
        $null
    }

    if (-not $resolvedClientId) {
        throw "PnP ClientId is required for SharePoint connection. Provide -PnPClientId or add 'pnpClientId' to your config file."
    }

    $needsConnect = $true
    try {
        $existingConn = Get-PnPConnection -ErrorAction SilentlyContinue
        if ($existingConn -and $existingConn.Url -like "*$($deployConfig.tenant)*") {
            Write-Host "Already connected to SharePoint tenant: $($deployConfig.tenant)" -ForegroundColor Green
            $needsConnect = $false
        }
    } catch { }

    if ($needsConnect) {
        Write-Host "Connecting to SharePoint: $hubUrl" -ForegroundColor Yellow
        try {
            Connect-PnPOnline -Url $hubUrl -ClientId $resolvedClientId -Interactive -ErrorAction Stop
            Write-Host "SharePoint connection established successfully!" -ForegroundColor Green
        } catch {
            throw "Failed to connect to SharePoint ($hubUrl) with ClientId '$resolvedClientId': $($_.Exception.Message)"
        }
    }
    Write-Host ""
}

$issues = Test-Prerequisites -Config $deployConfig

if ($issues.Count -gt 0) {
    Write-DeploymentLog "Prerequisites validation failed:" -Level Error
    foreach ($issue in $issues) {
        Write-DeploymentLog "  - $issue" -Level Error
    }
    
    if (-not $Force) {
        Write-DeploymentLog "Use -Force to skip prerequisite checks (not recommended)" -Level Warning
        throw "Prerequisites validation failed. Please resolve the issues above."
    } else {
        Write-DeploymentLog "Continuing with -Force parameter despite validation issues" -Level Warning
    }
}

if ($ValidateOnly) {
    Write-DeploymentLog "Validation completed successfully. No issues found." -Level Success 
    Write-DeploymentLog "Configuration is ready for deployment." -Level Success
    return
}

# ============================================================================
# DEPLOYMENT EXECUTION
# ============================================================================

Write-DeploymentLog "Starting deployment..." -Level Success
Write-DeploymentLog "Logging to: $LogPath" -Level Info

try {
    # Build bicep parameters from hierarchical config
    $bicepParams = @{
        projectPrefix = $deployConfig.deploymentSettings.projectPrefix
        environment = $deployConfig.deploymentSettings.environment
        location = $deployConfig.location
        sharePointConnectionDisplayName = $deployConfig.serviceAccountEmail
        hubSiteUrl = $deployConfig.hubSiteUrl
        runbooksToDeploy = $deployConfig.deploymentSettings.runbooksToDeploy
        logicAppsToDeploy = $deployConfig.deploymentSettings.logicAppsToDeploy
        deploySharePointConnector = $deployConfig.deploymentSettings.deploySharePointConnector
        deployAutomationConnector = $deployConfig.deploymentSettings.deployAutomationConnector
    }
    
    # Add optional parameters from area/component configs (only if set)
    if ($deployConfig.sharePointSettings.projectListGuid) {
        $bicepParams.projectListGuid = $deployConfig.sharePointSettings.projectListGuid
    }
    if ($deployConfig.sharePointSettings.listViewGuid) {
        $bicepParams.listViewGuid = $deployConfig.sharePointSettings.listViewGuid
    }
    
    # Phase text (from runbooks.json ArchiveSite or logic-apps.json PhaseChanged)
    $phaseText = if ($deployConfig.finishedPhaseText) { $deployConfig.finishedPhaseText } elseif ($deployConfig.completionPhaseName) { $deployConfig.completionPhaseName } else { $null }
    if ($phaseText) { $bicepParams.finishedPhaseText = $phaseText }
    
    # Automation settings (from automation.json)
    if ($deployConfig.language) { $bicepParams.language = $deployConfig.language }
    if ($deployConfig.logLevel) { $bicepParams.logLevel = $deployConfig.logLevel }
    
    # Component-level settings (from runbooks.json / logic-apps.json)
    if ($deployConfig.archiveStatusName) { $bicepParams.archiveStatusName = $deployConfig.archiveStatusName }
    if ($deployConfig.defaultManagerRole) { $bicepParams.defaultManagerRole = $deployConfig.defaultManagerRole }
    if ($deployConfig.archiveBannerText) { $bicepParams.archiveBannerText = $deployConfig.archiveBannerText }
    if ($deployConfig.dateCalculationRules) { $bicepParams.dateCalculationRules = $deployConfig.dateCalculationRules }
    if ($deployConfig.folderStructure) { $bicepParams.folderStructure = $deployConfig.folderStructure }
    if ($deployConfig.tags) { $bicepParams.tags = $deployConfig.tags }
    
    # Ensure resource group exists
    $rg = az group show --name $deployConfig.resourceGroupName 2>$null | ConvertFrom-Json
    if (-not $rg) {
        Write-DeploymentLog "Resource group '$($deployConfig.resourceGroupName)' not found. Creating in '$($deployConfig.location)'..." -Level Warning
        $tagArgs = @()
        if ($bicepParams.ContainsKey('tags') -and $bicepParams.tags) {
            foreach ($key in $bicepParams.tags.Keys) {
                $tagArgs += "$key=$($bicepParams.tags[$key])"
            }
        }
        if ($tagArgs.Count -gt 0) {
            az group create --name $deployConfig.resourceGroupName --location $deployConfig.location --tags @tagArgs 2>$null | Out-Null
        } else {
            az group create --name $deployConfig.resourceGroupName --location $deployConfig.location 2>$null | Out-Null
        }
        Write-DeploymentLog "Resource group '$($deployConfig.resourceGroupName)' created." -Level Success
    } else {
        Write-DeploymentLog "Resource group '$($deployConfig.resourceGroupName)' already exists." -Level Info
    }

    # Check if automation modules already exist on the account
    $automationAccountName = "$($deployConfig.deploymentSettings.projectPrefix)-$($deployConfig.deploymentSettings.environment)-automation"
    # Deploy using bicep
    $templatePath = Join-Path $PSScriptRoot "Infrastructure\main.bicep"
    
    Write-DeploymentLog "Deploying bicep template: $templatePath" -Level Info
    Write-DeploymentLog "Resource Group: $($deployConfig.resourceGroupName)" -Level Info

    # Build parameters file for az deployment
    $paramsFilePath = Join-Path $PSScriptRoot "logs\deployment-params-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $paramsObject = @{ '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'; contentVersion = '1.0.0.0'; parameters = @{} }
    foreach ($key in $bicepParams.Keys) {
        $paramsObject.parameters[$key] = @{ value = $bicepParams[$key] }
    }
    $paramsObject | ConvertTo-Json -Depth 10 | Set-Content -Path $paramsFilePath -Encoding UTF8

    $deployStderrFile = Join-Path $PSScriptRoot "logs\deployment-stderr-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    $deploymentJson = $null
    $deploymentJson = az deployment group create `
        --resource-group $deployConfig.resourceGroupName `
        --template-file $templatePath `
        --parameters "@$paramsFilePath" `
        -o json 2>$deployStderrFile

    $deployExitCode = $LASTEXITCODE

    # Clean up params file
    Remove-Item -Path $paramsFilePath -Force -ErrorAction SilentlyContinue

    if ($deployExitCode -ne 0 -or -not $deploymentJson) {
        $stderrContent = if (Test-Path $deployStderrFile) { Get-Content $deployStderrFile -Raw } else { '(no stderr captured)' }
        Remove-Item -Path $deployStderrFile -Force -ErrorAction SilentlyContinue
        Write-DeploymentLog "az deployment group create failed (exit code: $deployExitCode)" -Level Error
        Write-DeploymentLog "Error details: $stderrContent" -Level Error
        throw "az deployment group create failed (exit code: $deployExitCode).`n$stderrContent"
    }

    Remove-Item -Path $deployStderrFile -Force -ErrorAction SilentlyContinue
    $deployment = $deploymentJson | ConvertFrom-Json

    if ($deployment -and $deployment.properties.provisioningState -eq 'Succeeded') {
        Write-DeploymentLog "Bicep deployment completed successfully!" -Level Success

        # Log deployment outputs
        if ($deployment.properties.outputs) {
            Write-DeploymentLog "Deployment outputs:" -Level Info
            foreach ($output in $deployment.properties.outputs.PSObject.Properties) {
                Write-DeploymentLog "  $($output.Name): $($output.Value.value)" -Level Info
            }
        }
        
        # Initialize managed identities if requested and not in WhatIf mode
        if (($CreateManagedIdentity -or ($deployConfig.createNewRegistration -eq $true)) -and -not $SkipManagedIdentity -and -not $WhatIf) {
            Write-DeploymentLog "Initializing managed identities..." -Level Info
            
            try {
                $identityResults = Initialize-ManagedIdentities -DeployConfig $deployConfig -AutomationAccountName $automationAccountName -CreateUserAssignedIdentity:$CreateUserAssignedIdentity -WhatIf:$WhatIf
                
                if ($identityResults.SystemAssignedPrincipalId) {
                    Write-DeploymentLog "System-assigned managed identity configured successfully!" -Level Success
                    Write-DeploymentLog "Principal ID: $($identityResults.SystemAssignedPrincipalId)" -Level Info
                }
                
                if ($identityResults.UserAssignedPrincipalId) {
                    Write-DeploymentLog "User-assigned managed identity configured successfully!" -Level Success
                    Write-DeploymentLog "Principal ID: $($identityResults.UserAssignedPrincipalId)" -Level Info
                }
            }
            catch {
                Write-DeploymentLog "Warning: Managed identity setup encountered issues: $($_.Exception.Message)" -Level Warning
                Write-DeploymentLog "You may need to run '.\\createentraidapp.ps1' manually after deployment" -Level Warning
            }
        } elseif ($CreateManagedIdentity -and $WhatIf) {
            Write-DeploymentLog "[WHATIF] Would initialize managed identities after deployment" -Level Warning
        } elseif ($SkipManagedIdentity) {
            Write-DeploymentLog "Skipping managed identity setup as requested" -Level Info
        }

        # Remind user to authorize SharePoint API connection manually
        if ($deployConfig.deploymentSettings.deploySharePointConnector) {
            Write-Host ""
            Write-DeploymentLog "MANUAL STEP REQUIRED: Authorize the SharePoint API connection" -Level Warning
            Write-DeploymentLog "  1. Go to the Azure Portal" -Level Warning
            Write-DeploymentLog "  2. Navigate to Resource Group '$($deployConfig.resourceGroupName)'" -Level Warning
            Write-DeploymentLog "  3. Open the 'sharepointonline' API Connection resource" -Level Warning
            Write-DeploymentLog "  4. Click 'Edit API Connection' in the left menu" -Level Warning
            Write-DeploymentLog "  5. Click 'Authorize' and sign in" -Level Warning
            Write-DeploymentLog "  6. Click 'Save'" -Level Warning
            Write-Host ""
        }

        # Grant Logic App managed identities Automation Operator role on the automation account
        if (-not $WhatIf) {
            $automationScope = "/subscriptions/$($deployConfig.subscriptionId)/resourceGroups/$($deployConfig.resourceGroupName)/providers/Microsoft.Automation/automationAccounts/$automationAccountName"
            $logicAppNames = $deployConfig.deploymentSettings.logicAppsToDeploy | ForEach-Object {
                "$($deployConfig.deploymentSettings.projectPrefix)-$($deployConfig.deploymentSettings.environment)-$_"
            }

            foreach ($laName in $logicAppNames) {
                try {
                    $la = az resource show --resource-group $deployConfig.resourceGroupName --resource-type 'Microsoft.Logic/workflows' --name $laName 2>$null | ConvertFrom-Json
                    if (-not $la) { continue }

                    $principalId = $la.identity.principalId
                    if (-not $principalId) {
                        Write-DeploymentLog "  Logic App '$laName' has no managed identity — skipping role assignment" -Level Warning
                        continue
                    }

                    $existing = az role assignment list --assignee $principalId --role 'Automation Operator' --scope $automationScope 2>$null | ConvertFrom-Json
                    if ($existing -and $existing.Count -gt 0) {
                        Write-DeploymentLog "  Logic App '$laName' already has Automation Operator role" -Level Info
                        continue
                    }

                    az role assignment create --assignee-object-id $principalId --assignee-principal-type ServicePrincipal --role 'Automation Operator' --scope $automationScope 2>$null | Out-Null
                    if ($LASTEXITCODE -ne 0) { throw "az role assignment create failed" }
                    Write-DeploymentLog "  Granted Automation Operator to '$laName' ($principalId)" -Level Success
                }
                catch {
                    Write-DeploymentLog "  Failed to assign role for '$laName': $($_.Exception.Message)" -Level Warning
                }
            }
        }
        
        Write-DeploymentLog "Deployment log saved to: $LogPath" -Level Success
        Write-DeploymentLog "View deployment details in Azure Portal: https://portal.azure.com/#blade/HubsExtension/DeploymentDetailsBlade/id/$($deployment.id)" -Level Info

    } else {
        $failState = if ($deployment) { $deployment.properties.provisioningState } else { 'Unknown (no response)' }
        throw "Deployment failed with state: $failState"
    }
    
} catch {
    Write-DeploymentLog "Deployment failed: $($_.Exception.Message)" -Level Error
    Write-DeploymentLog "Check the deployment log for details: $LogPath" -Level Error
    throw
}

Write-DeploymentLog "Deployment process completed." -Level Success