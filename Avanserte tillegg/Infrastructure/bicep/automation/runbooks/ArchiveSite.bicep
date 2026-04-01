@description('Name of the automation account')
param automationAccountName string

@description('Location for the runbook resource')
param location string = resourceGroup().location

@description('Resource tags')
param tags object = {}

@description('URI to the runbook script file')
param scriptUri string

resource automationAccount 'Microsoft.Automation/automationAccounts@2024-10-23' existing = {
  name: automationAccountName
}

resource archiveSiteRunbook 'Microsoft.Automation/automationAccounts/runbooks@2024-10-23' = {
  parent: automationAccount
  name: 'ArchiveSite'
  location: location
  tags: tags
  properties: {
    logVerbose: false
    logProgress: false
    logActivityTrace: 0
    runbookType: 'PowerShell72'
    description: 'Archives a SharePoint project site by changing permissions and moving to archive'
    publishContentLink: {
      uri: scriptUri
    }
  }
}

output runbookName string = archiveSiteRunbook.name
output runbookId string = archiveSiteRunbook.id
