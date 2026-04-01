@description('Name of the automation account')
param automationAccountName string

@description('Location for the runbook resource')
param location string = resourceGroup().location

@description('Resource tags')
param tags object = {}

resource automationAccount 'Microsoft.Automation/automationAccounts@2024-10-23' existing = {
  name: automationAccountName
}

resource getSiteInformationRunbook 'Microsoft.Automation/automationAccounts/runbooks@2024-10-23' = {
  parent: automationAccount
  name: 'GetSiteInformation'
  location: location
  tags: tags
  properties: {
    logVerbose: false
    logProgress: false
    logActivityTrace: 0
    runbookType: 'PowerShell72'
    description: 'Retrieves SharePoint project site information including group ID, hub site URL, and phase'
  }
}

output runbookName string = getSiteInformationRunbook.name
output runbookId string = getSiteInformationRunbook.id
