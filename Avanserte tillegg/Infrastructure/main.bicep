metadata description = 'Main template for deploying Prosjektportalen Advanced Add-ons solution'

@description('Project name prefix (used for naming resources)')
@minLength(2)
@maxLength(10)
param projectPrefix string

@description('Environment (e.g., prod, test, dev)')
@minLength(2)
@maxLength(5)
param environment string = 'prod'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Display name for the SharePoint Online connection (usually an email address)')
param sharePointConnectionDisplayName string

@description('Display name for the Azure Automation connection')
param automationConnectionDisplayName string = 'Project Portal Automation'

@description('SharePoint hub site URL (e.g., https://contoso.sharepoint.com/sites/projectportal)')
param hubSiteUrl string

@description('SharePoint project list GUID')
param projectListGuid string

@description('SharePoint list view GUID')
param listViewGuid string

@description('Localized term for "Finished" phase status')
param finishedPhaseText string = 'Ferdig'

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

@description('Array of runbooks to deploy')
param runbooksToDeploy array = [
  'ArchiveSite'
  'GetSiteInformation'
  'UpdateProjectDates'
  'UpdateProjectManager'
]

@description('Array of logic apps to deploy')
param logicAppsToDeploy array = [
  'ChangeArchiveState'
  'PhaseChanged'
  'ProjectInfoChanged'
]

@description('Deploy SharePoint Online connector')
param deploySharePointConnector bool = true

@description('Deploy Azure Automation connector')
param deployAutomationConnector bool = true

@description('Resource tags')
param tags object = {
  Environment: environment
  Project: 'ProjectPortal'
  ManagedBy: 'ProjectPortalAutomation'
}

// Generate unique names for resources
var automationAccountName = '${projectPrefix}-${environment}-automation'
var sharePointConnectionName = 'sharepointonline'
var automationConnectionName = 'azureautomation'
var changeArchiveStateLogicAppName = '${projectPrefix}-${environment}-ChangeArchiveState'
var phaseChangedLogicAppName = '${projectPrefix}-${environment}-PhaseChanged'
var projectInfoChangedLogicAppName = '${projectPrefix}-${environment}-ProjectInfoChanged'

// Deploy Azure Automation Account (always deployed as foundation)
module automationAccount 'bicep/automation/AutomationAccount.bicep' = {
  name: 'automationAccount-deployment'
  params: {
    automationAccountName: automationAccountName
    location: location
    tags: tags
    language: language
    archiveStatusName: archiveStatusName
    defaultManagerRole: defaultManagerRole
    archiveBannerText: archiveBannerText
    dateCalculationRules: dateCalculationRules
    folderStructure: folderStructure
    logLevel: logLevel
  }
}

// Deploy runbook scripts (conditionally based on runbooksToDeploy parameter)
module archiveSiteRunbook 'bicep/automation/runbooks/ArchiveSite.bicep' = if (contains(runbooksToDeploy, 'ArchiveSite')) {
  name: 'archiveSite-runbook'
  params: {
    automationAccountName: automationAccountName
    location: location
    tags: tags
  }
  dependsOn: [
    automationAccount
  ]
}

module getSiteInformationRunbook 'bicep/automation/runbooks/GetSiteInformation.bicep' = if (contains(runbooksToDeploy, 'GetSiteInformation')) {
  name: 'getSiteInfo-runbook'
  params: {
    automationAccountName: automationAccountName
    location: location
    tags: tags
  }
  dependsOn: [
    automationAccount
  ]
}

module updateProjectDatesRunbook 'bicep/automation/runbooks/UpdateProjectDates.bicep' = if (contains(runbooksToDeploy, 'UpdateProjectDates')) {
  name: 'updateDates-runbook'
  params: {
    automationAccountName: automationAccountName
    location: location
    tags: tags
  }
  dependsOn: [
    automationAccount
  ]
}

module updateProjectManagerRunbook 'bicep/automation/runbooks/UpdateProjectManager.bicep' = if (contains(runbooksToDeploy, 'UpdateProjectManager')) {
  name: 'updateManager-runbook'
  params: {
    automationAccountName: automationAccountName
    location: location
    tags: tags
  }
  dependsOn: [
    automationAccount
  ]
}

// Deploy API connections (conditionally based on parameters)
module sharePointConnection 'bicep/connectors/SharePointOnline.bicep' = if (deploySharePointConnector) {
  name: 'sharepoint-connection'
  params: {
    sharePointOnlineConnectionName: sharePointConnectionName
    location: location
    displayName: sharePointConnectionDisplayName
    tags: tags
  }
}

module automationConnection 'bicep/connectors/Automation.bicep' = if (deployAutomationConnector) {
  name: 'automation-connection'
  params: {
    azureAutomationConnectionName: automationConnectionName
    location: location
    displayName: automationConnectionDisplayName
    tags: tags
  }
}

// Deploy Logic Apps (conditionally based on logicAppsToDeploy parameter)
module changeArchiveStateLogicApp 'bicep/logic-apps/ChangeArchiveState.bicep' = if (contains(logicAppsToDeploy, 'ChangeArchiveState') && deployAutomationConnector) {
  name: 'changeArchiveState-logicapp'
  params: {
    logicAppName: changeArchiveStateLogicAppName
    location: location
    automationAccountName: automationAccountName
    automationConnectionId: automationConnection!.outputs.connectionId
    tags: tags
  }
  dependsOn: [
    automationAccount
  ]
}

module phaseChangedLogicApp 'bicep/logic-apps/PhaseChanged.bicep' = if (contains(logicAppsToDeploy, 'PhaseChanged') && deployAutomationConnector) {
  name: 'phaseChanged-logicapp'
  params: {
    logicAppName: phaseChangedLogicAppName
    location: location
    automationAccountName: automationAccountName
    automationConnectionId: automationConnection!.outputs.connectionId
    finishedPhaseText: finishedPhaseText
    tags: tags
  }
  dependsOn: [
    automationAccount
  ]
}

module projectInfoChangedLogicApp 'bicep/logic-apps/ProjectInfoChanged.bicep' = if (contains(logicAppsToDeploy, 'ProjectInfoChanged') && deploySharePointConnector && deployAutomationConnector) {
  name: 'projectInfoChanged-logicapp'
  params: {
    logicAppName: projectInfoChangedLogicAppName
    location: location
    automationAccountName: automationAccountName
    sharePointConnectionId: sharePointConnection!.outputs.connectionId
    automationConnectionId: automationConnection!.outputs.connectionId
    hubSiteUrl: hubSiteUrl
    projectListGuid: projectListGuid
    listViewGuid: listViewGuid
    tags: tags
  }
  dependsOn: [
    automationAccount
  ]
}

// Outputs (conditional based on deployments)
output automationAccountName string = automationAccount.outputs.automationAccountName
output automationAccountId string = automationAccount.outputs.automationAccountId
output managedIdentityPrincipalId string = automationAccount.outputs.managedIdentityPrincipalId

output sharePointConnectionId string = deploySharePointConnector ? sharePointConnection!.outputs.connectionId : ''
output automationConnectionId string = deployAutomationConnector ? automationConnection!.outputs.connectionId : ''

output changeArchiveStateLogicAppId string = (contains(logicAppsToDeploy, 'ChangeArchiveState') && deployAutomationConnector) ? changeArchiveStateLogicApp!.outputs.logicAppId : ''
output changeArchiveStateTriggerUrl string = (contains(logicAppsToDeploy, 'ChangeArchiveState') && deployAutomationConnector) ? changeArchiveStateLogicApp!.outputs.triggerUrl : ''

output phaseChangedLogicAppId string = (contains(logicAppsToDeploy, 'PhaseChanged') && deployAutomationConnector) ? phaseChangedLogicApp!.outputs.logicAppId : ''
output phaseChangedTriggerUrl string = (contains(logicAppsToDeploy, 'PhaseChanged') && deployAutomationConnector) ? phaseChangedLogicApp!.outputs.triggerUrl : ''

output projectInfoChangedLogicAppId string = (contains(logicAppsToDeploy, 'ProjectInfoChanged') && deploySharePointConnector && deployAutomationConnector) ? projectInfoChangedLogicApp!.outputs.logicAppId : ''

// Summary output showing what was deployed
output deploymentSummary object = {
  automationAccount: automationAccountName
  runbooksDeployed: runbooksToDeploy
  logicAppsDeployed: logicAppsToDeploy
  sharePointConnectorDeployed: deploySharePointConnector
  automationConnectorDeployed: deployAutomationConnector
}