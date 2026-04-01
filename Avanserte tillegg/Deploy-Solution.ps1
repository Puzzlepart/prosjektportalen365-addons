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
    [ValidateSet('ChangeArchiveState', 'PhaseChanged', 'ProjectInfoChanged')]
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
        if (Get-Module -Name Az.Accounts -ListAvailable -ErrorAction SilentlyContinue) {
            $context = Get-AzContext -ListAvailable -ErrorAction SilentlyContinue | Select-Object -First 5
            if ($context) {
                $context | ForEach-Object {
                    if ($_.Subscription.Id -like "$wordToComplete*") {
                        [System.Management.Automation.CompletionResult]::new(
                            $_.Subscription.Id, 
                            "$($_.Subscription.Name) ($($_.Subscription.Id))",
                            'ParameterValue',
                            $_.Subscription.Name
                        )
                    }
                }
            }
        }
    }
    catch {
        # Silently fail and provide no completions if Az module issues
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

# Check required modules
$requiredModules = @('Az', 'PnP.PowerShell')
$missingModules = @()

foreach ($module in $requiredModules) {
    if (-not (Get-Module -Name $module -ListAvailable -ErrorAction SilentlyContinue)) {
        $missingModules += $module
        Write-Host "Missing required module: $module" -ForegroundColor Red
    }
    else {
        Write-Host "Found module: $module" -ForegroundColor Green
    }
}

if ($missingModules.Count -gt 0) {
    Write-Host "Missing required PowerShell modules. Please install them using:" -ForegroundColor Red
    foreach ($module in $missingModules) {
        Write-Host "  Install-Module -Name $module -Force" -ForegroundColor Yellow
    }
    throw "Missing required PowerShell modules: $($missingModules -join ', ')"
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

# Check if already connected to Azure
try {
    $currentContext = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $currentContext) {
        Write-Host "Not connected to Azure. Initiating login..." -ForegroundColor Yellow
        Connect-AzAccount -ErrorAction Stop
        $currentContext = Get-AzContext
    }
    
    Write-Host "Connected to Azure as: $($currentContext.Account.Id)" -ForegroundColor Green
    Write-Host "Current subscription: $($currentContext.Subscription.Name) ($($currentContext.Subscription.Id))" -ForegroundColor Green
    
    # Set subscription context if SubscriptionId is provided and different from current
    if ($SubscriptionId) {
        if ($currentContext.Subscription.Id -ne $SubscriptionId) {
            Write-Host "Switching to subscription: $SubscriptionId" -ForegroundColor Yellow
            try {
                Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop | Out-Null
                $newContext = Get-AzContext
                Write-Host "Successfully switched to subscription: $($newContext.Subscription.Name)" -ForegroundColor Green
            }
            catch {
                Write-Host "Failed to switch to subscription $SubscriptionId. Error: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "Available subscriptions:" -ForegroundColor Yellow
                Get-AzSubscription | Format-Table Name, Id, State -AutoSize
                throw "Invalid or inaccessible subscription ID: $SubscriptionId"
            }
        }
        else {
            Write-Host "Already using target subscription" -ForegroundColor Green
        }
    }
    
    # Verify subscription access and get details
    $subscription = Get-AzSubscription -SubscriptionId (Get-AzContext).Subscription.Id -ErrorAction Stop
    Write-Host "Subscription verified: $($subscription.Name) (State: $($subscription.State))" -ForegroundColor Green
    
    # Check if subscription is active
    if ($subscription.State -ne 'Enabled') {
        throw "Subscription '$($subscription.Name)' is not in an active state (Current state: $($subscription.State))"
    }
    
    Write-Host "Azure authentication successful!" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "Azure authentication failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please ensure you have:" -ForegroundColor Yellow
    Write-Host "1. Az PowerShell module installed (Install-Module -Name Az)" -ForegroundColor Yellow
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
        $automationAccount = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName -ErrorAction SilentlyContinue
        if (-not $automationAccount) {
            Write-DeploymentLog "Automation Account '$AutomationAccountName' not found in resource group '$ResourceGroupName'" -Level Error
            throw "Automation Account not found"
        }
        
        # Enable managed identity using REST API
        $resourceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Automation/automationAccounts/$AutomationAccountName"
        
        # Get current automation account properties
        $currentAccount = Invoke-AzRestMethod -Path "$($resourceId)?api-version=2020-01-13-preview" -Method GET
        
        if ($currentAccount.StatusCode -eq 200) {
            $accountData = ($currentAccount.Content | ConvertFrom-Json)
            
            # Check if managed identity is already enabled
            if ($accountData.identity -and $accountData.identity.type -eq "SystemAssigned" -and $accountData.identity.principalId) {
                Write-DeploymentLog "Managed identity already enabled" -Level Warning
                return $accountData.identity.principalId
            }
            
            # Enable managed identity
            if (-not $accountData.identity) {
                $accountData.identity = @{
                    type = "SystemAssigned"
                }
            } else {
                $accountData.identity.type = "SystemAssigned"
            }
            
            $body = $accountData | ConvertTo-Json -Depth 10
            $result = Invoke-AzRestMethod -Path "$($resourceId)?api-version=2020-01-13-preview" -Method PATCH -Payload $body
            
            if ($result.StatusCode -eq 200) {
                $updatedAccount = ($result.Content | ConvertFrom-Json)
                Write-DeploymentLog "Successfully enabled managed identity" -Level Success
                return $updatedAccount.identity.principalId
            } else {
                Write-DeploymentLog "Failed to enable managed identity: $($result.StatusCode) - $($result.Content)" -Level Error
                throw "Failed to enable managed identity"
            }
        } else {
            Write-DeploymentLog "Failed to get Automation Account details: $($currentAccount.StatusCode)" -Level Error
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
            $existingAssignment = Get-AzRoleAssignment -ObjectId $PrincipalId -RoleDefinitionName $role.RoleDefinitionName -Scope $role.Scope -ErrorAction SilentlyContinue
            
            if ($existingAssignment) {
                Write-DeploymentLog "Role assignment already exists: $($role.RoleDefinitionName)" -Level Warning
                continue
            }
            
            # Create role assignment
            $assignment = New-AzRoleAssignment -ObjectId $PrincipalId -RoleDefinitionName $role.RoleDefinitionName -Scope $role.Scope
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
            $location = (Get-AzResourceGroup -Name $DeployConfig.resourceGroupName).Location
            
            Write-DeploymentLog "Creating user-assigned managed identity: $identityName"
            
            if ($WhatIf) {
                Write-DeploymentLog "[WHATIF] Would create user-assigned managed identity: $identityName" -Level Warning
            } else {
                try {
                    # Check if identity already exists
                    $existingIdentity = Get-AzUserAssignedIdentity -ResourceGroupName $DeployConfig.resourceGroupName -Name $identityName -ErrorAction SilentlyContinue
                    
                    if ($existingIdentity) {
                        Write-DeploymentLog "User-assigned managed identity '$identityName' already exists" -Level Warning
                        $userAssignedPrincipalId = $existingIdentity.PrincipalId
                    } else {
                        # Create new user-assigned managed identity
                        $identity = New-AzUserAssignedIdentity -ResourceGroupName $DeployConfig.resourceGroupName -Name $identityName -Location $location
                        Write-DeploymentLog "Successfully created user-assigned managed identity" -Level Success
                        $userAssignedPrincipalId = $identity.PrincipalId
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
        $spResource = Get-AzADServicePrincipal -ApplicationId $sharePointAppId -ErrorAction Stop
        $fullControlRole = $spResource.AppRole | Where-Object { $_.Value -eq 'Sites.FullControl.All' }

        if (-not $fullControlRole) {
            Write-DeploymentLog "Could not find Sites.FullControl.All app role on SharePoint service principal" -Level Error
            return
        }

        # Check if assignment already exists
        $existingAssignments = Get-AzADServicePrincipalAppRoleAssignment -ServicePrincipalId $PrincipalId -ErrorAction SilentlyContinue
        $alreadyAssigned = $existingAssignments | Where-Object { $_.AppRoleId -eq $fullControlRole.Id -and $_.ResourceId -eq $spResource.Id }

        if ($alreadyAssigned) {
            Write-DeploymentLog "SharePoint Sites.FullControl.All already granted to $AutomationAccountName" -Level Info
            return
        }

        New-AzADServicePrincipalAppRoleAssignment `
            -ServicePrincipalId $PrincipalId `
            -ResourceId $spResource.Id `
            -AppRoleId $fullControlRole.Id `
            -ErrorAction Stop

        Write-DeploymentLog "Granted SharePoint Sites.FullControl.All to $AutomationAccountName" -Level Success
    }
    catch {
        Write-DeploymentLog "Failed to grant SharePoint permissions: $($_.Exception.Message)" -Level Warning
        Write-DeploymentLog "You may need to grant permissions manually. Use the Azure Portal or run:" -Level Warning
        Write-DeploymentLog "  Connect-MgGraph -Scopes AppRoleAssignment.ReadWrite.All" -Level Warning
        Write-DeploymentLog "  New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId '$PrincipalId' -ResourceId '<SharePoint SP Id>' -AppRoleId '<Sites.FullControl.All Id>'" -Level Warning
    }
}

function Authorize-SharePointConnection {
    param(
        [string]$SubscriptionId,
        [string]$ResourceGroupName,
        [string]$ConnectionName = 'sharepointonline',
        [switch]$WhatIf
    )

    Write-DeploymentLog "Checking SharePoint API connection authorization..." -Level Info

    if ($WhatIf) {
        Write-DeploymentLog "[WHATIF] Would authorize SharePoint connection '$ConnectionName'" -Level Warning
        return
    }

    try {
        $connectionPath = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/connections/$ConnectionName"

        # Check current connection status
        $connResult = Invoke-AzRestMethod -Path "$($connectionPath)?api-version=2016-06-01" -Method GET
        if ($connResult.StatusCode -ne 200) {
            Write-DeploymentLog "SharePoint connection '$ConnectionName' not found — skipping authorization" -Level Warning
            return
        }

        $connData = $connResult.Content | ConvertFrom-Json
        $currentStatus = $connData.properties.statuses | Where-Object { $_.status -eq 'Connected' }

        if ($currentStatus) {
            Write-DeploymentLog "SharePoint connection '$ConnectionName' is already authorized" -Level Info
            return
        }

        # Get consent link
        $consentPath = "$connectionPath/listConsentLinks?api-version=2016-06-01"
        $consentBody = @{
            parameters = @(
                @{ parameterName = 'token'; redirectUrl = 'https://ema1.exp.azure.com/ema/default/authredirect' }
            )
        } | ConvertTo-Json -Depth 3

        $consentResult = Invoke-AzRestMethod -Path $consentPath -Method POST -Payload $consentBody
        if ($consentResult.StatusCode -eq 200) {
            $consentLinks = ($consentResult.Content | ConvertFrom-Json).value
            if ($consentLinks -and $consentLinks.link) {
                Write-DeploymentLog "SharePoint connection requires manual authorization." -Level Warning
                Write-DeploymentLog "Open this URL in a browser to authorize the connection:" -Level Warning
                Write-DeploymentLog "  $($consentLinks.link)" -Level Warning
                Write-Host ""
                Write-Host "SharePoint API connection needs authorization." -ForegroundColor Yellow
                Write-Host "Opening consent URL in your default browser..." -ForegroundColor Yellow
                Start-Process $consentLinks.link
                Write-Host "After authorizing, press Enter to continue..." -ForegroundColor Yellow
                Read-Host | Out-Null

                # Verify connection after consent
                $verifyResult = Invoke-AzRestMethod -Path "$($connectionPath)?api-version=2016-06-01" -Method GET
                if ($verifyResult.StatusCode -eq 200) {
                    $verifyData = $verifyResult.Content | ConvertFrom-Json
                    $connected = $verifyData.properties.statuses | Where-Object { $_.status -eq 'Connected' }
                    if ($connected) {
                        Write-DeploymentLog "SharePoint connection authorized successfully!" -Level Success
                    } else {
                        Write-DeploymentLog "Connection status could not be verified. Check Azure Portal if issues persist." -Level Warning
                    }
                }
            }
        } else {
            Write-DeploymentLog "Could not get consent link (status $($consentResult.StatusCode)). Authorize manually in Azure Portal." -Level Warning
        }
    }
    catch {
        Write-DeploymentLog "Error authorizing SharePoint connection: $($_.Exception.Message)" -Level Warning
        Write-DeploymentLog "Authorize manually: Azure Portal > Resource Group > $ConnectionName > Edit API Connection > Authorize" -Level Warning
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
            logicAppsToDeploy = @('ChangeArchiveState', 'PhaseChanged', 'ProjectInfoChanged')
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
            logicAppsToDeploy = @('PhaseChanged', 'ProjectInfoChanged')
            deploySharePointConnector = $true
            deployAutomationConnector = $true
            createManagedIdentity = $true
            description = 'Project update functionality only'
        }
        'LogicAppsOnly' = @{
            runbooksToDeploy = @()
            logicAppsToDeploy = @('ChangeArchiveState', 'PhaseChanged', 'ProjectInfoChanged')
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

   # Deploy using configuration file (all parameters come from config)
   .\Deploy-Solution.ps1 -ConfigurationFile "config\config.json"
   
   # Deploy with config file but override specific parameters
   .\Deploy-Solution.ps1 -ConfigurationFile "config\config.json" -Environment "test"

   # Validate configuration without deploying
   .\Deploy-Solution.ps1 -ConfigurationFile "config\config.json" -ValidateOnly
   
   📝 Required properties in configuration file:
   • subscriptionId: Azure subscription GUID
   • tenant: SharePoint tenant (e.g., "contoso.sharepoint.com")
   • hubSiteUrl: Full URL to hub site
   • serviceAccountEmail: Service account email address

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

function Convert-NewConfigFormat {
    param($ConfigObject)
    
    function ConvertObject($obj) {
        if ($null -eq $obj) { return $null }
        
        if ($obj -is [PSCustomObject]) {
            $result = @{}
            foreach ($property in $obj.PSObject.Properties) {
                $value = $property.Value
                
                # Check if this property uses the new format (has Value and Description)
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
    
    return ConvertObject($ConfigObject)
}

function Get-DeploymentConfiguration {
    # Handle different parameter sets
    if ($PSCmdlet.ParameterSetName -eq 'ConfigFile') {
        Write-DeploymentLog "Loading configuration from: $ConfigurationFile"
        $rawConfig = Get-Content -Path $ConfigurationFile -Raw | ConvertFrom-Json
        
        # Convert new config format to old format for backward compatibility
        $config = Convert-NewConfigFormat -ConfigObject $rawConfig
        
        # Override with command line parameters if provided
        if ($SubscriptionId) { $config.subscriptionId = $SubscriptionId }
        if ($ResourceGroupName) { $config.resourceGroupName = $ResourceGroupName }
        if ($Location) { $config.location = $Location }
        if ($SharePointTenant) { $config.tenant = $SharePointTenant }
        if ($HubSiteUrl) { $config.hubSiteUrl = $HubSiteUrl }
        
        # Validate required properties exist in config file
        $requiredProperties = @(
            @{Name = 'subscriptionId'; DisplayName = 'Subscription ID'},
            @{Name = 'tenant'; DisplayName = 'SharePoint Tenant'},
            @{Name = 'hubSiteUrl'; DisplayName = 'Hub Site URL'},
            @{Name = 'serviceAccountEmail'; DisplayName = 'Service Account Email'}
        )
        
        $missingProperties = @()
        foreach ($prop in $requiredProperties) {
            if (-not $config.($prop.Name)) {
                $missingProperties += $prop.DisplayName
            }
        }
        
        if ($missingProperties.Count -gt 0) {
            Write-Host "Configuration file is missing required properties:" -ForegroundColor Red
            foreach ($missing in $missingProperties) {
                Write-Host "  - $missing" -ForegroundColor Red
            }
            Write-Host "Please update your configuration file or provide these parameters on the command line." -ForegroundColor Yellow
            throw "Configuration file validation failed. Missing required properties: $($missingProperties -join ', ')"
        }
        
        # Ensure required nested objects exist with defaults
        if (-not $config.deploymentSettings) {
            $config.deploymentSettings = @{
                projectPrefix = if ($ProjectPrefix -ne 'PP365') { $ProjectPrefix } else { 'PP365' }
                environment = if ($Environment -ne 'prod') { $Environment } else { 'prod' }
                runbooksToDeploy = @('ArchiveSite', 'GetSiteInformation', 'UpdateProjectDates', 'UpdateProjectManager')
                logicAppsToDeploy = @('ChangeArchiveState', 'PhaseChanged', 'ProjectInfoChanged')
                deploySharePointConnector = $true
                deployAutomationConnector = $true
            }
        }
        
        # Add default values for optional properties if missing
        if (-not $config.resourceGroupName) { $config.resourceGroupName = $ResourceGroupName }
        if (-not $config.location) { $config.location = $Location }
        if (-not $config.completionPhaseName) { $config.completionPhaseName = $FinishedPhaseText }
        
        Write-DeploymentLog "Configuration loaded successfully from file" -Level Success
        
        # Validate loaded configuration values
        if ($config.subscriptionId -and $config.subscriptionId -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
            Write-Host "Invalid subscriptionId in config file. Must be a valid GUID." -ForegroundColor Red
            throw "Invalid subscriptionId format in configuration file"
        }
        
        if ($config.tenant -and $config.tenant -notmatch '^[a-zA-Z0-9][a-zA-Z0-9-]*\.sharepoint\.com$') {
            Write-Host "Invalid tenant in config file. Must be like 'contoso.sharepoint.com'" -ForegroundColor Red
            throw "Invalid tenant format in configuration file"
        }
        
        if ($config.hubSiteUrl -and $config.hubSiteUrl -notmatch '^https://[a-zA-Z0-9][a-zA-Z0-9-]*\.sharepoint\.com/sites/[a-zA-Z0-9-]+$') {
            Write-Host "Invalid hubSiteUrl in config file. Must be like 'https://contoso.sharepoint.com/sites/sitename'" -ForegroundColor Red
            throw "Invalid hubSiteUrl format in configuration file"
        }
        
        if ($config.serviceAccountEmail -and $config.serviceAccountEmail -notmatch '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
            Write-Host "Invalid serviceAccountEmail in config file. Must be a valid email address." -ForegroundColor Red
            throw "Invalid serviceAccountEmail format in configuration file"
        }
        
        return $config
        
    } elseif ($PSCmdlet.ParameterSetName -eq 'Preset') {
        Write-DeploymentLog "Using preset configuration: $Preset"
        $presetConfig = Get-PresetConfiguration -PresetName $Preset
        
        # Build configuration from preset and parameters
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
        
        # Add SharePoint settings if provided
        if ($ProjectListGuid) {
            $config.sharePointSettings = @{
                projectListGuid = $ProjectListGuid
            }
            if ($ListViewGuid) {
                $config.sharePointSettings.listViewGuid = $ListViewGuid  
            }
        }
        
        Write-DeploymentLog "Preset Description: $($presetConfig.description)" -Level Info
        return [PSCustomObject]$config
        
    } else {
        # Interactive parameter set
        Write-DeploymentLog "Using interactive parameter configuration"
        
        # Determine selective deployment arrays
        $runbooks = if ($RunbooksToDeploy) { $RunbooksToDeploy } else { @('ArchiveSite', 'GetSiteInformation', 'UpdateProjectDates', 'UpdateProjectManager') }
        $logicApps = if ($LogicAppsToDeploy) { $LogicAppsToDeploy } else { @('ChangeArchiveState', 'PhaseChanged', 'ProjectInfoChanged') }
        
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
        
        # Add SharePoint settings if provided
        if ($ProjectListGuid) {
            $config.sharePointSettings = @{
                projectListGuid = $ProjectListGuid
            }
            if ($ListViewGuid) {
                $config.sharePointSettings.listViewGuid = $ListViewGuid
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
    
    # Test Azure PowerShell connection
    try {
        $azContext = Get-AzContext -ErrorAction SilentlyContinue
        if (-not $azContext) {
            $issues += "Not connected to Azure. Please run 'Connect-AzAccount'"
        } elseif ($Config.subscriptionId -and $azContext.Subscription.Id -ne $Config.subscriptionId) {
            $issues += "Connected to wrong subscription. Expected: $($Config.subscriptionId), Current: $($azContext.Subscription.Id)"
        }
    } catch {
        $issues += "Azure PowerShell module not available or not connected: $($_.Exception.Message)"
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
    # Build bicep parameters
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
    
    # Add optional SharePoint parameters
    if ($deployConfig.sharePointSettings.projectListGuid) {
        $bicepParams.projectListGuid = $deployConfig.sharePointSettings.projectListGuid
    }
    if ($deployConfig.sharePointSettings.listViewGuid) {
        $bicepParams.listViewGuid = $deployConfig.sharePointSettings.listViewGuid
    }
    if ($deployConfig.completionPhaseName) {
        $bicepParams.finishedPhaseText = $deployConfig.completionPhaseName
    }
    
    # Add configuration parameters
    if ($deployConfig.language) {
        $bicepParams.language = $deployConfig.language
    }
    if ($deployConfig.archiveStatusName) {
        $bicepParams.archiveStatusName = $deployConfig.archiveStatusName
    }
    if ($deployConfig.defaultManagerRole) {
        $bicepParams.defaultManagerRole = $deployConfig.defaultManagerRole
    }
    if ($deployConfig.archiveBannerText) {
        $bicepParams.archiveBannerText = $deployConfig.archiveBannerText
    }
    if ($deployConfig.dateCalculationRules) {
        $bicepParams.dateCalculationRules = $deployConfig.dateCalculationRules
    }
    if ($deployConfig.folderStructure) {
        $bicepParams.folderStructure = $deployConfig.folderStructure
    }
    if ($deployConfig.logLevel) {
        $bicepParams.logLevel = $deployConfig.logLevel
    }
    
    # Ensure resource group exists
    $rg = Get-AzResourceGroup -Name $deployConfig.resourceGroupName -ErrorAction SilentlyContinue
    if (-not $rg) {
        Write-DeploymentLog "Resource group '$($deployConfig.resourceGroupName)' not found. Creating in '$($deployConfig.location)'..." -Level Warning
        $rg = New-AzResourceGroup -Name $deployConfig.resourceGroupName -Location $deployConfig.location -Tag ($bicepParams.ContainsKey('tags') ? $bicepParams.tags : @{})
        Write-DeploymentLog "Resource group '$($deployConfig.resourceGroupName)' created." -Level Success
    } else {
        Write-DeploymentLog "Resource group '$($deployConfig.resourceGroupName)' already exists." -Level Info
    }

    # Check if automation modules already exist on the account
    $automationAccountName = "$($deployConfig.deploymentSettings.projectPrefix)-$($deployConfig.deploymentSettings.environment)-automation"
    $modulesToCheck = [ordered]@{
        'Az.Accounts'    = 'https://www.powershellgallery.com/api/v2/Packages/Az.Accounts/2.19.0'
        'Az.Resources'   = 'https://www.powershellgallery.com/api/v2/Packages/Az.Resources/7.1.0'
        'PnP.PowerShell' = 'https://www.powershellgallery.com/api/v2/Packages/PnP.PowerShell/2.12.0'
    }

    # Deploy using bicep
    $templatePath = Join-Path $PSScriptRoot "Infrastructure\main.bicep"
    
    Write-DeploymentLog "Deploying bicep template: $templatePath" -Level Info
    Write-DeploymentLog "Resource Group: $($deployConfig.resourceGroupName)" -Level Info
    
    $deployment = New-AzResourceGroupDeployment `
        -ResourceGroupName $deployConfig.resourceGroupName `
        -TemplateFile $templatePath `
        -TemplateParameterObject $bicepParams `
        -Verbose
    
    if ($deployment.ProvisioningState -eq 'Succeeded') {
        Write-DeploymentLog "Bicep deployment completed successfully!" -Level Success

        # Install automation modules (skip if already present)
        Write-DeploymentLog "Checking automation account modules..." -Level Info
        foreach ($modName in $modulesToCheck.Keys) {
            $existing = Get-AzAutomationModule -ResourceGroupName $deployConfig.resourceGroupName -AutomationAccountName $automationAccountName -Name $modName -ErrorAction SilentlyContinue
            if ($existing -and $existing.ProvisioningState -eq 'Succeeded') {
                Write-DeploymentLog "  Module '$modName' already exists. Skipping." -Level Info
                continue
            }
            $modUri = $modulesToCheck[$modName]
            Write-DeploymentLog "  Installing module '$modName'..." -Level Info
            New-AzAutomationModule -ResourceGroupName $deployConfig.resourceGroupName -AutomationAccountName $automationAccountName -Name $modName -ContentLinkUri $modUri | Out-Null
            # Wait for module provisioning to complete before installing the next one
            $maxWait = 300; $elapsed = 0
            do {
                Start-Sleep -Seconds 10; $elapsed += 10
                $modState = (Get-AzAutomationModule -ResourceGroupName $deployConfig.resourceGroupName -AutomationAccountName $automationAccountName -Name $modName).ProvisioningState
            } while ($modState -notin @('Succeeded', 'Failed') -and $elapsed -lt $maxWait)
            if ($modState -eq 'Succeeded') {
                Write-DeploymentLog "  Module '$modName' installed successfully." -Level Success
            } else {
                Write-DeploymentLog "  Module '$modName' provisioning ended with state: $modState" -Level Warning
            }
        }
        Write-DeploymentLog "Module installation complete." -Level Success
        
        # Log deployment outputs
        if ($deployment.Outputs) {
            Write-DeploymentLog "Deployment outputs:" -Level Info
            foreach ($output in $deployment.Outputs.GetEnumerator()) {
                Write-DeploymentLog "  $($output.Key): $($output.Value.Value)" -Level Info
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

        # Authorize SharePoint API connection if it was deployed
        if ($deployConfig.deploymentSettings.deploySharePointConnector -and -not $WhatIf) {
            Authorize-SharePointConnection `
                -SubscriptionId $deployConfig.subscriptionId `
                -ResourceGroupName $deployConfig.resourceGroupName `
                -ConnectionName 'sharepointonline' `
                -WhatIf:$WhatIf
        }

        # Grant Logic App managed identities Automation Operator role on the automation account
        if (-not $WhatIf) {
            $automationScope = "/subscriptions/$($deployConfig.subscriptionId)/resourceGroups/$($deployConfig.resourceGroupName)/providers/Microsoft.Automation/automationAccounts/$automationAccountName"
            $logicAppNames = $deployConfig.deploymentSettings.logicAppsToDeploy | ForEach-Object {
                "$($deployConfig.deploymentSettings.projectPrefix)-$($deployConfig.deploymentSettings.environment)-$_"
            }

            foreach ($laName in $logicAppNames) {
                try {
                    $la = Get-AzResource -ResourceGroupName $deployConfig.resourceGroupName -ResourceType 'Microsoft.Logic/workflows' -Name $laName -ErrorAction SilentlyContinue
                    if (-not $la) { continue }

                    $laDetail = Get-AzResource -ResourceId $la.ResourceId -ErrorAction SilentlyContinue
                    $principalId = $laDetail.Identity.PrincipalId
                    if (-not $principalId) {
                        Write-DeploymentLog "  Logic App '$laName' has no managed identity — skipping role assignment" -Level Warning
                        continue
                    }

                    $existing = Get-AzRoleAssignment -ObjectId $principalId -RoleDefinitionName 'Automation Operator' -Scope $automationScope -ErrorAction SilentlyContinue
                    if ($existing) {
                        Write-DeploymentLog "  Logic App '$laName' already has Automation Operator role" -Level Info
                        continue
                    }

                    New-AzRoleAssignment -ObjectId $principalId -RoleDefinitionName 'Automation Operator' -Scope $automationScope -ErrorAction Stop | Out-Null
                    Write-DeploymentLog "  Granted Automation Operator to '$laName' ($principalId)" -Level Success
                }
                catch {
                    Write-DeploymentLog "  Failed to assign role for '$laName': $($_.Exception.Message)" -Level Warning
                }
            }
        }
        
        Write-DeploymentLog "Deployment log saved to: $LogPath" -Level Success
        Write-DeploymentLog "View deployment details in Azure Portal: https://portal.azure.com/#blade/HubsExtension/DeploymentDetailsBlade/id/$($deployment.Id)" -Level Info
        
    } else {
        throw "Deployment failed with state: $($deployment.ProvisioningState)"
    }
    
} catch {
    Write-DeploymentLog "Deployment failed: $($_.Exception.Message)" -Level Error
    Write-DeploymentLog "Check the deployment log for details: $LogPath" -Level Error
    throw
}

Write-DeploymentLog "Deployment process completed." -Level Success