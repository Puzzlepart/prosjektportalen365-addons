# Prosjektportalen365 Advanced Add-ons - Generic Deployment Solution

This solution provides automated project lifecycle management capabilities for SharePoint-based project portals. It has been completely refactored from a single-tenant implementation to support deployment across any tenant with proper configuration.

## 🌟 Features

- **🔄 Project Lifecycle Automation**: Automatically archive/unarchive projects based on completion status
- **👤 Dynamic Manager Assignment**: Assign appropriate project managers based on project phase
- **📅 Automated Date Calculations**: Calculate inspection, waiver, and complaint deadlines from handover dates
- **🔔 Change Detection**: Monitor project property changes and trigger appropriate workflows
- **🌐 Multi-Tenant Support**: Deploy to any SharePoint tenant with configuration files
- **🛡️ Configurable Security**: Manage document folder permissions based on project phases
- **📊 Comprehensive Logging**: Detailed execution logs and error reporting

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Logic Apps    │    │ Azure Automation │    │ SharePoint Online│
│                 │    │                 │    │                 │
│ • Phase Changed │───▶│ • ArchiveSite   │───▶│ • Project Sites │
│ • Info Changed  │    │ • UpdateManager │    │ • Hub Site      │
│ • Archive State │    │ • UpdateDates   │    │ • Document Libs │
│                 │    │ • GetSiteInfo   │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │ API Connectors  │
                    │                 │
                    │ • SharePoint    │
                    │ • Automation    │
                    └─────────────────┘
```

### Components

- **4 PowerShell Runbooks**: Business logic execution with configurable parameters
- **3 Logic Apps**: Workflow orchestration for different trigger scenarios  
- **2 API Connectors**: Authentication and connectivity to SharePoint and Azure
- **1 Automation Account**: Secure execution environment with managed identity
- **Configuration System**: JSON-based tenant and business logic configuration

## 🚀 Quick Start

### ⚡ 5-Minute Setup

1. **Prerequisites & Authentication**:
   ```powershell
   # Install required modules (if not already installed)
   Install-Module -Name Az -Scope CurrentUser -Force
   Install-Module -Name PnP.PowerShell -Scope CurrentUser -Force
   
   # Authenticate to Azure and SharePoint
   Connect-AzAccount
   Connect-PnPOnline -Url "https://yourtenant.sharepoint.com/sites/prosjektportalen" -Interactive
   ```

2. **Configure your tenant**:
   ```powershell
   # Copy configuration template
   Copy-Item "config\config.template.json" "config\my-tenant-config.json"
   
   # Edit my-tenant-config.json with your tenant details
   ```

3. **Deploy the solution**:
   ```powershell
   # Quick deployment with preset (recommended)
   .\Deploy-Solution.ps1 -Preset Full -SubscriptionId "your-subscription-id" -SharePointTenant "yourtenant.sharepoint.com" -HubSiteUrl "https://yourtenant.sharepoint.com/sites/prosjektportalen" -SharePointConnectionEmail "admin@yourdomain.com"
   
   # Or deploy with configuration file
   .\Deploy-Solution.ps1 -ConfigurationFile "config\my-tenant-config.json"
   ```

### 🎯 Deployment Options

The unified deployment script supports multiple modes:

#### **Preset Deployments** (Recommended for most scenarios)
Choose from pre-configured deployment scenarios:

- **`Full`** - Complete deployment with all components
- **`Minimal`** - Basic site information retrieval only  
- **`Testing`** - Core functionality for testing environments
- **`ArchiveOnly`** - Archive functionality only
- **`UpdateOnly`** - Project update functionality only
- **`LogicAppsOnly`** - Logic Apps workflow automation only

```powershell
# Example: Full production deployment
.\Deploy-Solution.ps1 -Preset Full -SubscriptionId "guid" -SharePointTenant "contoso.sharepoint.com" -HubSiteUrl "https://contoso.sharepoint.com/sites/projectportal" -SharePointConnectionEmail "admin@contoso.com"

# Example: Testing deployment
.\Deploy-Solution.ps1 -Preset Testing -SubscriptionId "guid" -SharePointTenant "contoso.sharepoint.com" -HubSiteUrl "https://contoso.sharepoint.com/sites/projectportal" -SharePointConnectionEmail "admin@contoso.com" -Environment "test"
```

#### **Configuration File Deployment**
For standardized deployments and team collaboration:

```powershell
.\Deploy-Solution.ps1 -ConfigurationFile "config\tenant-config.json"
```

#### **Custom Selective Deployment**
Deploy only specific components:

```powershell
# Deploy specific runbooks and logic apps
.\Deploy-Solution.ps1 -SubscriptionId "guid" -SharePointTenant "contoso.sharepoint.com" -HubSiteUrl "url" -SharePointConnectionEmail "email" -RunbooksToDeploy "ArchiveSite","UpdateProjectManager" -LogicAppsToDeploy "PhaseChanged"

# Deploy without SharePoint connector
.\Deploy-Solution.ps1 -Preset Full ... -SkipSharePointConnector
```

#### **Help and Examples**
```powershell
# View all available options and examples
.\Deploy-Solution.ps1 -ShowExamples

# Validate before deploying
.\Deploy-Solution.ps1 -ConfigurationFile "config\tenant-config.json" -ValidateOnly

# Preview what would be deployed
.\Deploy-Solution.ps1 -Preset Full ... -WhatIf
```

⚙️ Configuration

### Tenant Configuration

The solution supports flexible configuration through JSON files. All configuration properties use a structured format with `"Value"` (the actual setting) and `"Description"` (documentation) for each property. See the templates in the `config/` directory:

- **`config.template.json`**: Basic template with Norwegian defaults
- **`deployment-config.schema.json`**: JSON schema for validation

#### Key Configuration Sections

```json
{
  "azure": {
    "subscriptionId": "...",
    "resourceGroupName": "...",
    "location": "westeurope",
    "automationAccountName": "PP365-Automation"
  },
  "sharepoint": {
    "tenant": "yourtenant.sharepoint.com", 
    "hubSiteUrl": "https://yourtenant.sharepoint.com/sites/prosjektportalen"
  },
  "deploymentSettings": {
    "Value": {
      "projectPrefix": "PP365",
      "environment": "prod",
      "runbooksToDeploy": [
        "ArchiveSite",
        "GetSiteInformation", 
        "UpdateProjectDates",
        "UpdateProjectManager"
      ],
      "logicAppsToDeploy": [
        "ChangeArchiveState",
        "PhaseChanged", 
        "ProjectInfoChanged"
      ],
      "deploySharePointConnector": true,
      "deployAutomationConnector": true
    },
    "Description": "Controls which components are deployed"
  },
  "businessLogic": {
    "language": "nb-NO",
    "completionPhaseName": "Ferdig",
    "archiveStatusName": "Avsluttet",
    "dateCalculationRules": {
      "inspectionPeriodYears": 1,
      "waiverPeriodYears": 3,
      "complaintPeriodYears": 5
    }
  }
}
```

### Selective Deployment Configuration

The `deploymentSettings` section enables fine-grained control over which components are deployed:

#### Available Components

**Runbooks** (PowerShell automation scripts):
- `ArchiveSite` - Archive SharePoint sites
- `GetSiteInformation` - Retrieve site metadata  
- `UpdateProjectDates` - Update project milestone dates
- `UpdateProjectManager` - Assign project manager permissions

**Logic Apps** (Workflow automation):
- `ChangeArchiveState` - Handle site archiving workflows
- `PhaseChanged` - Process project phase changes
- `ProjectInfoChanged` - React to project information updates

**Connectors** (API connections):
- `deploySharePointConnector` - SharePoint Online API connection
- `deployAutomationConnector` - Azure Automation API connection

#### Example Configurations

```json
// Minimal deployment for testing
"deploymentSettings": {
  "runbooksToDeploy": ["GetSiteInformation"],
  "logicAppsToDeploy": [],
  "deploySharePointConnector": false,
  "deployAutomationConnector": true
}

// Archive-only functionality
"deploymentSettings": {
  "runbooksToDeploy": ["ArchiveSite"],
  "logicAppsToDeploy": ["ChangeArchiveState"],
  "deploySharePointConnector": false,
  "deployAutomationConnector": true
}

// Full deployment (default)
"deploymentSettings": {
  "runbooksToDeploy": ["ArchiveSite", "GetSiteInformation", "UpdateProjectDates", "UpdateProjectManager"],
  "logicAppsToDeploy": ["ChangeArchiveState", "PhaseChanged", "ProjectInfoChanged"],
  "deploySharePointConnector": true,
  "deployAutomationConnector": true
}
```

### Business Logic Customization

The solution supports different business rules and localization:

#### Supported Languages
- **Norwegian Bokmål** (`nb-NO`) - Default
- **English US** (`en-US`)
- **Plus**: Swedish, Danish, German, French, Spanish

#### Configurable Rules
- **Date Calculation Periods**: Customize inspection/waiver/complaint deadlines
- **Phase Names**: Define project phases that trigger different behaviors
- **Folder Structures**: Configure document folder paths for permission management
- **Status Values**: Customize completion and archive status names

## 🛠️ Advanced Usage

### Prerequisites & Dependencies

**Azure Requirements:**
- **Subscription**: Contributor role or higher
- **Regions**: Logic Apps and Automation available in your chosen region
- **Resource Providers**: `Microsoft.Automation`, `Microsoft.Logic`, `Microsoft.Web`

**SharePoint Requirements:**
- **SharePoint Admin** access to the tenant
- **Existing Hub Site** with Prosjektportalen installed
- **Required Lists**: `Prosjektegenskaper`, `Prosjekter`, `Dokumenter`

### Deployment Validation

```powershell
# Validate prerequisites before deployment
.\Validate-Prerequisites.ps1 -ConfigurationFile "config\my-tenant-config.json"

# Validate deployment configuration without deploying
.\Deploy-Solution.ps1 -ConfigurationFile "config\my-tenant-config.json" -ValidateOnly

# Preview what would be deployed
.\Deploy-Solution.ps1 -Preset Full ... -WhatIf
```

### Environment-Specific Deployments

Deploy to different environments with environment-specific configurations:

```powershell
# Development environment
.\Deploy-Solution.ps1 -Preset Testing -SubscriptionId "guid" -SharePointTenant "tenant.sharepoint.com" -HubSiteUrl "url" -SharePointConnectionEmail "email" -Environment "dev"

# Production environment  
.\Deploy-Solution.ps1 -ConfigurationFile "config\prod-config.json" -Environment "production"
```

### Manual Script Execution

Each PowerShell script can be run independently for testing or manual operations:

```powershell
# Archive a specific project
.\Infrastructure\scripts\ArchiveSite.ps1 -Url "https://tenant.sharepoint.com/sites/project1" -GroupId "12345678-1234-1234-1234-123456789012" -Status "Avsluttet"

# Update project manager based on phase
.\Infrastructure\scripts\UpdateProjectManager.ps1 -Url "https://tenant.sharepoint.com/sites/project1" -DryRun

# Calculate and update project dates
.\Infrastructure\scripts\UpdateProjectDates.ps1 -Url "https://tenant.sharepoint.com/sites/project1" -HandoverDate "2024-06-01"

# Get site information
.\Infrastructure\scripts\GetSiteInformation.ps1 -Url "https://tenant.sharepoint.com/sites/project1" -OutputFormat "Summary"
```

## 📋 Troubleshooting

### Common Issues

#### 1. Authentication Problems

**Symptoms**: Runbooks fail with authentication errors

**Solutions**:
- Verify managed identity is enabled on Automation Account
- Check SharePoint admin consent for the application
- Ensure API connections are properly authenticated in Azure Portal

#### 2. SharePoint Permissions

**Symptoms**: Access denied errors when accessing SharePoint

**Solutions**:
- Grant SharePoint admin privileges to the deployment account
- Verify the managed identity has appropriate SharePoint permissions
- Check if conditional access policies block service principals

#### 3. Module Import Issues

**Symptoms**: PnP.PowerShell module errors in runbooks

**Solutions**:
- Verify module versions in Automation Account
- Check for module conflicts
- Reimport modules if necessary

#### 4. Logic App Trigger Issues

**Symptoms**: Logic Apps don't trigger on SharePoint changes

**Solutions**:
- Verify SharePoint connection is authenticated
- Check if SharePoint list has the required fields
- Test the trigger manually in the Logic Apps designer

### Diagnostic Commands

```powershell
# Test Azure connectivity
Get-AzContext
Get-AzResourceGroup -Name "YourResourceGroup"

# Test SharePoint connectivity  
Get-PnPConnection
Get-PnPList

# Validate configuration
Test-Json -Json (Get-Content "config\my-tenant-config.json" -Raw) -SchemaFile "config\deployment-config.schema.json"
```

## 📚 File Structure

```
├── Deploy-Solution.ps1              # 🚀 Unified deployment script (handles all scenarios)  
├── Infrastructure/                  # Azure infrastructure and templates
│   ├── main.bicep                  # Main orchestration template
│   ├── deployment/                 # Additional deployment utilities
│   │   └── Validate-Solution.ps1   # Solution validation
│   ├── bicep/                      # Bicep templates organized by type
│   │   ├── automation/             # Azure Automation resources
│   │   │   ├── AutomationAccount.bicep
│   │   │   └── runbooks/           # Individual runbook templates
│   │   ├── connectors/             # API connector templates
│   │   │   ├── Automation.bicep
│   │   │   └── SharePointOnline.bicep
│   │   └── logic-apps/             # Logic App templates
│   │       ├── ChangeArchiveState.bicep
│   │       ├── PhaseChanged.bicep
│   │       └── ProjectInfoChanged.bicep
│   └── scripts/                    # PowerShell scripts for runbooks
│       ├── ArchiveSite.ps1
│       ├── GetSiteInformation.ps1
│       ├── UpdateProjectDates.ps1
│       └── UpdateProjectManager.ps1
├── config/                         # Configuration templates
│   ├── deployment-config.schema.json
│   └── config.template.json
├── README.md                       # This file
└── logs/                          # Deployment logs (created automatically)
```

## 🔒 Security Considerations

### Managed Identity

The solution uses Azure Automation managed identity for secure authentication:

- **No stored credentials** in runbooks or configuration
- **Minimal required permissions** assigned through RBAC
- **Audit trail** of all actions through Azure Activity Log

### SharePoint Permissions

- **Limited scope**: Only accesses project-related lists and sites
- **Configurable permissions**: Document folder access based on project phase
- **Inheritance management**: Breaks inheritance only when necessary for security

### Data Privacy

- **No data storage**: Solution only processes SharePoint data in-transit
- **Logging**: Logs contain project URLs and user emails (required for operation)
- **Configuration**: Sensitive information stored in Azure Automation variables

## 🤝 Contributing

To contribute improvements or bug fixes:

1. **Test thoroughly** in a development environment
2. **Update configuration schema** if adding new options
3. **Update documentation** for any new features
4. **Follow PowerShell best practices** for script development

### Development Guidelines

- Use **approved PowerShell verbs** for function names
- Include **comprehensive error handling** with meaningful messages
- Add **parameter validation** where appropriate
- Follow **existing logging patterns** for consistency
- Test with **multiple tenant configurations**

## 📞 Support

For issues and questions:

1. **Check the troubleshooting section** above
2. **Review deployment logs** in the `logs/` directory
3. **Validate configuration** against the JSON schema
4. **Test individual scripts** before full deployment

## 🔄 Version History

### v2.0.0 - Generic Multi-Tenant Version
- ✅ Complete refactor for multi-tenant support
- ✅ Configuration-based business logic
- ✅ Improved error handling and logging
- ✅ Comprehensive deployment validation
- ✅ Multiple language support
- ✅ Modular Bicep infrastructure templates

### v1.0.0 - Original Single-Tenant Version  
- ✅ Basic automation functionality
- ✅ Hardcoded for Innlandet fylke tenant
- ✅ Manual deployment process

## 📜 License

This solution is provided as-is for project management automation purposes. Ensure compliance with your organization's policies and Microsoft licensing requirements.