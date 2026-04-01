#Requires -Modules Az.Accounts, Az.Resources, Az.Automation, PnP.PowerShell

<#
.SYNOPSIS
    Creates and configures managed identities for Prosjektportalen365 Advanced Add-ons

.DESCRIPTION
    This script creates and configures the necessary managed identities and permissions
    for the Prosjektportalen365 Advanced Add-ons solution to function properly.
    
    It will:
    - Enable system-assigned managed identity on the Automation Account
    - Create a user-assigned managed identity for Logic Apps (optional)
    - Assign necessary Azure RBAC permissions
    - Configure SharePoint permissions for the managed identity
    - Validate the configuration

.PARAMETER ConfigPath
    Path to the deployment configuration JSON file

.PARAMETER SubscriptionId
    Azure subscription ID (overrides config file)

.PARAMETER ResourceGroupName
    Resource group name (overrides config file)

.PARAMETER AutomationAccountName
    Automation Account name (overrides config file)

.PARAMETER SharePointTenant
    SharePoint tenant domain (overrides config file)

.PARAMETER HubSiteUrl
    Hub site URL (overrides config file)

.PARAMETER CreateUserAssignedIdentity
    Creates a user-assigned managed identity in addition to system-assigned

.PARAMETER WhatIf
    Shows what would be done without making changes

.EXAMPLE
    .\createentraidapp.ps1 -ConfigPath "config\my-tenant-config.json"

.EXAMPLE
    .\createentraidapp.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789abc" -ResourceGroupName "RG-Prosjektportalen365" -AutomationAccountName "AA-Prosjektportalen365"

#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath,
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$AutomationAccountName,
    
    [Parameter(Mandatory = $false)]
    [string]$SharePointTenant,
    
    [Parameter(Mandatory = $false)]
    [string]$HubSiteUrl,
    
    [Parameter(Mandatory = $false)]
    [switch]$CreateUserAssignedIdentity,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

# Import required functions
function Write-DeploymentLog {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "Error" { Write-Host $logMessage -ForegroundColor Red }
        "Warning" { Write-Host $logMessage -ForegroundColor Yellow }
        "Success" { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage -ForegroundColor White }
    }
}

function Convert-NewConfigFormat {
    param($ConfigObject)
    
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
    
    return ConvertObject($ConfigObject)
}

function Get-Configuration {
    param(
        [string]$ConfigPath,
        [string]$SubscriptionId,
        [string]$ResourceGroupName,
        [string]$AutomationAccountName,
        [string]$SharePointTenant,
        [string]$HubSiteUrl
    )
    
    $config = $null
    
    # Load configuration from file if provided
    if ($ConfigPath -and (Test-Path $ConfigPath)) {
        Write-DeploymentLog "Loading configuration from: $ConfigPath"
        try {
            $rawConfig = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $config = Convert-NewConfigFormat -ConfigObject $rawConfig
        }
        catch {
            Write-DeploymentLog "Failed to load configuration file: $($_.Exception.Message)" -Level Error
            throw
        }
    } else {
        $config = [PSCustomObject]@{}
    }
    
    # Override with parameters if provided
    if ($SubscriptionId) { $config | Add-Member -NotePropertyName "subscriptionId" -NotePropertyValue $SubscriptionId -Force }
    if ($ResourceGroupName) { $config | Add-Member -NotePropertyName "resourceGroupName" -NotePropertyValue $ResourceGroupName -Force }
    if ($AutomationAccountName) { $config | Add-Member -NotePropertyName "automationAccountName" -NotePropertyValue $AutomationAccountName -Force }
    if ($SharePointTenant) { $config | Add-Member -NotePropertyName "tenant" -NotePropertyValue $SharePointTenant -Force }
    if ($HubSiteUrl) { $config | Add-Member -NotePropertyName "hubSiteUrl" -NotePropertyValue $HubSiteUrl -Force }
    
    # Validate required parameters
    $missing = @()
    if (-not $config.subscriptionId) { $missing += "subscriptionId" }
    if (-not $config.resourceGroupName) { $missing += "resourceGroupName" }
    if (-not $config.automationAccountName) { $missing += "automationAccountName" }
    if (-not $config.tenant) { $missing += "tenant" }
    if (-not $config.hubSiteUrl) { $missing += "hubSiteUrl" }
    
    if ($missing.Count -gt 0) {
        Write-DeploymentLog "Missing required configuration: $($missing -join ', ')" -Level Error
        throw "Missing required configuration parameters"
    }
    
    return $config
}

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
        
        # Enable managed identity using REST API since PowerShell cmdlets might not support it
        $resourceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Automation/automationAccounts/$AutomationAccountName"
        
        # Get current automation account properties
        $currentAccount = Invoke-AzRestMethod -Path "$($resourceId)?api-version=2020-01-13-preview" -Method GET
        
        if ($currentAccount.StatusCode -eq 200) {
            $accountData = ($currentAccount.Content | ConvertFrom-Json)
            
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

function New-UserAssignedManagedIdentity {
    param(
        [string]$ResourceGroupName,
        [string]$Name,
        [string]$Location,
        [switch]$WhatIf
    )
    
    Write-DeploymentLog "Creating user-assigned managed identity: $Name"
    
    if ($WhatIf) {
        Write-DeploymentLog "[WHATIF] Would create user-assigned managed identity: $Name" -Level Warning
        return $null
    }
    
    try {
        # Check if identity already exists
        $existingIdentity = Get-AzUserAssignedIdentity -ResourceGroupName $ResourceGroupName -Name $Name -ErrorAction SilentlyContinue
        
        if ($existingIdentity) {
            Write-DeploymentLog "User-assigned managed identity '$Name' already exists" -Level Warning
            return $existingIdentity.PrincipalId
        }
        
        # Create new user-assigned managed identity
        $identity = New-AzUserAssignedIdentity -ResourceGroupName $ResourceGroupName -Name $Name -Location $Location
        Write-DeploymentLog "Successfully created user-assigned managed identity" -Level Success
        return $identity.PrincipalId
    }
    catch {
        Write-DeploymentLog "Error creating user-assigned managed identity: $($_.Exception.Message)" -Level Error
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

function Set-SharePointPermissions {
    param(
        [string]$PrincipalId,
        [string]$SharePointTenant,
        [string]$HubSiteUrl,
        [switch]$WhatIf
    )
    
    Write-DeploymentLog "Configuring SharePoint permissions for managed identity"
    
    if ($WhatIf) {
        Write-DeploymentLog "[WHATIF] Would configure SharePoint permissions" -Level Warning
        return
    }
    
    try {
        # Connect to SharePoint admin center
        $adminUrl = "https://$($SharePointTenant.Replace('.sharepoint.com', '-admin.sharepoint.com'))"
        Write-DeploymentLog "Connecting to SharePoint admin center: $adminUrl"
        
        Connect-PnPOnline -Url $adminUrl -Interactive -ErrorAction Stop
        
        # Get the managed identity service principal
        $servicePrincipal = Get-AzADServicePrincipal -Id $PrincipalId -ErrorAction SilentlyContinue
        
        if (-not $servicePrincipal) {
            Write-DeploymentLog "Could not find service principal for managed identity" -Level Error
            return
        }
        
        Write-DeploymentLog "Found managed identity service principal: $($servicePrincipal.DisplayName)"
        
        # Grant SharePoint admin permissions to the managed identity
        # This enables the runbooks to manage SharePoint sites and permissions
        try {
            # Note: This requires manual steps in SharePoint Admin Center
            Write-DeploymentLog "MANUAL STEP REQUIRED:" -Level Warning
            Write-DeploymentLog "1. Go to SharePoint Admin Center > Advanced > App permissions" -Level Warning
            Write-DeploymentLog "2. Grant the following permissions to the managed identity:" -Level Warning
            Write-DeploymentLog "   - App ID: $($servicePrincipal.AppId)" -Level Warning
            Write-DeploymentLog "   - Permission: Full Control to SharePoint" -Level Warning
            Write-DeploymentLog "   - Scope: $SharePointTenant" -Level Warning
        }
        catch {
            Write-DeploymentLog "Note: SharePoint permissions must be configured manually" -Level Warning
        }
    }
    catch {
        Write-DeploymentLog "Error configuring SharePoint permissions: $($_.Exception.Message)" -Level Error
        Write-DeploymentLog "SharePoint permissions must be configured manually" -Level Warning
    }
}

function Test-ManagedIdentityConfiguration {
    param(
        [string]$PrincipalId,
        [string]$ResourceGroupName,
        [string]$AutomationAccountName
    )
    
    Write-DeploymentLog "Testing managed identity configuration"
    
    try {
        # Check if managed identity exists
        $servicePrincipal = Get-AzADServicePrincipal -Id $PrincipalId -ErrorAction SilentlyContinue
        
        if ($servicePrincipal) {
            Write-DeploymentLog "✓ Managed identity service principal exists: $($servicePrincipal.DisplayName)" -Level Success
        } else {
            Write-DeploymentLog "✗ Managed identity service principal not found" -Level Error
            return $false
        }
        
        # Check role assignments
        $roleAssignments = Get-AzRoleAssignment -ObjectId $PrincipalId -ErrorAction SilentlyContinue
        
        if ($roleAssignments) {
            Write-DeploymentLog "✓ Found $($roleAssignments.Count) role assignment(s)" -Level Success
            foreach ($assignment in $roleAssignments) {
                Write-DeploymentLog "  - $($assignment.RoleDefinitionName) on $($assignment.Scope)"
            }
        } else {
            Write-DeploymentLog "✗ No role assignments found" -Level Error
            return $false
        }
        
        return $true
    }
    catch {
        Write-DeploymentLog "Error testing managed identity: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# Main execution
try {
    Write-DeploymentLog "Starting managed identity configuration for Prosjektportalen365 Add-ons"
    
    # Load configuration
    $config = Get-Configuration -ConfigPath $ConfigPath -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -SharePointTenant $SharePointTenant -HubSiteUrl $HubSiteUrl
    
    Write-DeploymentLog "Configuration loaded:"
    Write-DeploymentLog "  Subscription: $($config.subscriptionId)"
    Write-DeploymentLog "  Resource Group: $($config.resourceGroupName)"
    Write-DeploymentLog "  Automation Account: $($config.automationAccountName)"
    Write-DeploymentLog "  SharePoint Tenant: $($config.tenant)"
    Write-DeploymentLog "  Hub Site: $($config.hubSiteUrl)"
    
    # Connect to Azure
    Write-DeploymentLog "Connecting to Azure..."
    $azContext = Get-AzContext
    if (-not $azContext -or $azContext.Subscription.Id -ne $config.subscriptionId) {
        Connect-AzAccount -SubscriptionId $config.subscriptionId
    }
    Set-AzContext -SubscriptionId $config.subscriptionId | Out-Null
    
    # Enable system-assigned managed identity on Automation Account
    $systemAssignedPrincipalId = Enable-AutomationAccountManagedIdentity -SubscriptionId $config.subscriptionId -ResourceGroupName $config.resourceGroupName -AutomationAccountName $config.automationAccountName -WhatIf:$WhatIf
    
    if ($systemAssignedPrincipalId -and -not $WhatIf) {
        Write-DeploymentLog "System-assigned managed identity Principal ID: $systemAssignedPrincipalId" -Level Success
        
        # Wait a moment for the identity to propagate
        Write-DeploymentLog "Waiting for managed identity to propagate..."
        Start-Sleep -Seconds 30
        
        # Assign Azure RBAC roles
        Set-AzureRoleAssignments -PrincipalId $systemAssignedPrincipalId -SubscriptionId $config.subscriptionId -ResourceGroupName $config.resourceGroupName -WhatIf:$WhatIf
        
        # Configure SharePoint permissions
        Set-SharePointPermissions -PrincipalId $systemAssignedPrincipalId -SharePointTenant $config.tenant -HubSiteUrl $config.hubSiteUrl -WhatIf:$WhatIf
        
        # Test configuration
        if (-not $WhatIf) {
            Start-Sleep -Seconds 15  # Allow time for role propagation
            $testResult = Test-ManagedIdentityConfiguration -PrincipalId $systemAssignedPrincipalId -ResourceGroupName $config.resourceGroupName -AutomationAccountName $config.automationAccountName
            
            if ($testResult) {
                Write-DeploymentLog "Managed identity configuration completed successfully!" -Level Success
            } else {
                Write-DeploymentLog "Managed identity configuration completed with warnings" -Level Warning
            }
        }
    }
    
    # Create user-assigned managed identity if requested
    if ($CreateUserAssignedIdentity) {
        $identityName = "$($config.automationAccountName)-identity"
        $location = (Get-AzResourceGroup -Name $config.resourceGroupName).Location
        
        $userAssignedPrincipalId = New-UserAssignedManagedIdentity -ResourceGroupName $config.resourceGroupName -Name $identityName -Location $location -WhatIf:$WhatIf
        
        if ($userAssignedPrincipalId -and -not $WhatIf) {
            Write-DeploymentLog "User-assigned managed identity Principal ID: $userAssignedPrincipalId" -Level Success
            
            # Assign roles to user-assigned identity as well
            Set-AzureRoleAssignments -PrincipalId $userAssignedPrincipalId -SubscriptionId $config.subscriptionId -ResourceGroupName $config.resourceGroupName -WhatIf:$WhatIf
        }
    }
    
    if (-not $WhatIf) {
        Write-DeploymentLog @"

MANAGED IDENTITY CONFIGURATION COMPLETE!

Next Steps:
1. Verify that the Automation Account runbooks can authenticate using managed identity
2. Complete SharePoint permissions configuration in SharePoint Admin Center:
   - Go to https://$($config.tenant.Replace('.sharepoint.com', '-admin.sharepoint.com'))/_layouts/15/appinv.aspx
   - Use the Principal ID to grant SharePoint permissions

3. Test the Logic Apps and runbooks to ensure they work with managed identity

Principal IDs for reference:
"@ -Level Success
        
        if ($systemAssignedPrincipalId) {
            Write-DeploymentLog "- System-assigned: $systemAssignedPrincipalId" -Level Success
        }
        if ($userAssignedPrincipalId) {
            Write-DeploymentLog "- User-assigned: $userAssignedPrincipalId" -Level Success
        }
    }
    
} catch {
    Write-DeploymentLog "Error during managed identity configuration: $($_.Exception.Message)" -Level Error
    throw
}
        if ($userAssignedPrincipalId) {
            Write-DeploymentLog "- User-assigned: $userAssignedPrincipalId" -Level Success
        }
    }
    
} catch {
    Write-DeploymentLog "Error during managed identity configuration: $($_.Exception.Message)" -Level Error
    throw
}
