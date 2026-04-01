@description('Name of the automation account')
param automationAccountName string

@description('Location for the runbook resource')
param location string = resourceGroup().location

@description('Resource tags')
param tags object = {}

resource automationAccount 'Microsoft.Automation/automationAccounts@2024-10-23' existing = {
  name: automationAccountName
}

resource updateProjectManagerRunbook 'Microsoft.Automation/automationAccounts/runbooks@2024-10-23' = {
  parent: automationAccount
  name: 'UpdateProjectManager'
  location: location
  tags: tags
  properties: {
    logVerbose: false
    logProgress: false
    logActivityTrace: 0
    runbookType: 'PowerShell72'
    description: 'Updates project manager information in SharePoint lists and project site permissions'
  }
}

output runbookName string = updateProjectManagerRunbook.name
output runbookId string = updateProjectManagerRunbook.id
