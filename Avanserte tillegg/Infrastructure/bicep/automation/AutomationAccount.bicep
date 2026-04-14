@description('Name of the Azure Automation Account')
param automationAccountName string

@description('Location for the automation account')
param location string = resourceGroup().location

@description('Resource tags')
param tags object = {}

@description('Language code for localization')
param language string = 'nb-NO'

@description('Localized text for archived project status')
param archiveStatusName string = 'Avsluttet'

@description('Default SharePoint permission level for project managers')
param defaultManagerRole string = 'Full Kontroll'

@description('Message displayed on archived project sites')
param archiveBannerText string = 'Dette området er arkivert og skrivebeskyttet. Ta kontakt med administrator for å aktivere området igjen.'

@description('Rules for calculating project milestone dates')
param dateCalculationRules object = {
  inspectionPeriodYears: 1
  waiverPeriodYears: 3
  complaintPeriodYears: 5
}

@description('Standard folder structure for project document libraries')
param folderStructure object = {
  planningPhase: [
    '01 Planlegging'
    '02 Prosjektering'
  ]
  buildingPhase: [
    '03 Bygging'
    '04 Ferdigstillelse'
    '05 Oppfølging'
  ]
}

@description('Logging level for automation scripts')
param logLevel string = 'Info'

resource automationAccount 'Microsoft.Automation/automationAccounts@2024-10-23' = {
  name: automationAccountName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: true
    disableLocalAuth: false
    sku: {
      name: 'Basic'
    }
    encryption: {
      keySource: 'Microsoft.Automation'
      identity: {}
    }
  }
}

// Outputs
output automationAccountId string = automationAccount.id
output automationAccountName string = automationAccount.name
output managedIdentityPrincipalId string = automationAccount.identity.principalId

// Configuration Variables
resource languageVariable 'Microsoft.Automation/automationAccounts/variables@2024-10-23' = {
  parent: automationAccount
  name: 'Language'
  properties: {
    description: 'Language code for localization'
    value: '"${language}"'
    isEncrypted: false
  }
}

resource archiveStatusNameVariable 'Microsoft.Automation/automationAccounts/variables@2024-10-23' = {
  parent: automationAccount
  name: 'ArchiveStatusName'
  properties: {
    description: 'Localized text for archived project status'
    value: '"${archiveStatusName}"'
    isEncrypted: false
  }
}

resource defaultManagerRoleVariable 'Microsoft.Automation/automationAccounts/variables@2024-10-23' = {
  parent: automationAccount
  name: 'DefaultManagerRole'
  properties: {
    description: 'Default SharePoint permission level for project managers'
    value: '"${defaultManagerRole}"'
    isEncrypted: false
  }
}

resource archiveBannerTextVariable 'Microsoft.Automation/automationAccounts/variables@2024-10-23' = {
  parent: automationAccount
  name: 'ArchiveBannerText'
  properties: {
    description: 'Message displayed on archived project sites'
    value: '"${archiveBannerText}"'
    isEncrypted: false
  }
}

resource dateCalculationRulesVariable 'Microsoft.Automation/automationAccounts/variables@2024-10-23' = {
  parent: automationAccount
  name: 'DateCalculationRules'
  properties: {
    description: 'Rules for calculating project milestone dates as JSON'
    value: '"${replace(string(dateCalculationRules), '"', '\\"')}"'
    isEncrypted: false
  }
}

resource folderStructureVariable 'Microsoft.Automation/automationAccounts/variables@2024-10-23' = {
  parent: automationAccount
  name: 'FolderStructure'
  properties: {
    description: 'Standard folder structure for project document libraries as JSON'
    value: '"${replace(string(folderStructure), '"', '\\"')}"'
    isEncrypted: false
  }
}

resource logLevelVariable 'Microsoft.Automation/automationAccounts/variables@2024-10-23' = {
  parent: automationAccount
  name: 'LogLevel'
  properties: {
    description: 'Logging level for automation scripts'
    value: '"${logLevel}"'
    isEncrypted: false
  }
}
