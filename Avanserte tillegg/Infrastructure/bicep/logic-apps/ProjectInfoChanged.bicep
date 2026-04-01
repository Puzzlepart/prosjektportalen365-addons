@description('Name of the ProjectInfoChanged Logic App')
param logicAppName string = 'ProjectInfoChanged'

@description('Location for the logic app')
param location string = resourceGroup().location

@description('Subscription ID')
param subscriptionId string = subscription().subscriptionId

@description('Resource group name')
param resourceGroupName string = resourceGroup().name

@description('Name of the automation account')
param automationAccountName string

@description('Connection ID for SharePoint Online connection')
param sharePointConnectionId string

@description('Connection ID for Azure Automation connection')
param automationConnectionId string

@description('SharePoint hub site URL (e.g., https://contoso.sharepoint.com/sites/projectportal)')
param hubSiteUrl string

@description('SharePoint project list GUID')
param projectListGuid string

@description('SharePoint list view GUID')
param listViewGuid string

@description('Resource tags')
param tags object = {}

resource projectInfoChangedLogicApp 'Microsoft.Logic/workflows@2017-07-01' = {
  name: logicAppName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        When_project_information_changes: {
          recurrence: {
            interval: 1
            frequency: 'Minute'
          }
          evaluatedRecurrence: {
            interval: 1
            frequency: 'Minute'
          }
          splitOn: '@triggerBody()?[\'value\']'
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'sharepointonline\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/datasets/@{encodeURIComponent(encodeURIComponent(\'${hubSiteUrl}\'))}/tables/@{encodeURIComponent(encodeURIComponent(\'${projectListGuid}\'))}/onchangeditems'
            queries: {
              view: listViewGuid
            }
          }
          conditions: []
        }
      }
      actions: {
        Get_project_changes: {
          runAfter: {}
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'sharepointonline\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/datasets/@{encodeURIComponent(encodeURIComponent(\'${hubSiteUrl}\'))}/tables/@{encodeURIComponent(encodeURIComponent(\'${projectListGuid}\'))}/items/@{encodeURIComponent(encodeURIComponent(triggerBody()?[\'ID\']))}/changes'
            queries: {
              since: '@sub(int(triggerOutputs()?[\'body/{VersionNumber}\']),1)'
              includeDrafts: false
              view: listViewGuid
            }
          }
        }
        'Condition_(Manager)': {
          actions: {
            Update_Project_Manager_Field: {
              type: 'ApiConnection'
              inputs: {
                host: {
                  connection: {
                    name: '@parameters(\'$connections\')[\'azureautomation\'][\'connectionId\']'
                  }
                }
                method: 'put'
                body: {
                  properties: {
                    parameters: {
                      Url: '@triggerBody()?[\'GtSiteUrl\']'
                      HubSiteUrl: hubSiteUrl
                    }
                  }
                }
                path: '/subscriptions/@{encodeURIComponent(\'${subscriptionId}\')}/resourceGroups/@{encodeURIComponent(\'${resourceGroupName}\')}/providers/Microsoft.Automation/automationAccounts/@{encodeURIComponent(\'${automationAccountName}\')}/jobs'
                queries: {
                  'x-ms-api-version': '2015-10-31'
                  runbookName: 'UpdateProjectManager'
                  wait: false
                }
              }
            }
          }
          runAfter: {
            Get_project_changes: [
              'Succeeded'
            ]
          }
          else: {
            actions: {}
          }
          expression: {
            or: [
              {
                equals: [
                  '@body(\'Get_project_changes\')?[\'ColumnHasChanged\']?[\'GtVeiPlanningManager\']'
                  '@true'
                ]
              }
              {
                equals: [
                  '@body(\'Get_project_changes\')?[\'ColumnHasChanged\']?[\'GtVeiProjectingManager\']'
                  '@true'
                ]
              }
              {
                equals: [
                  '@body(\'Get_project_changes\')?[\'ColumnHasChanged\']?[\'GtVeiConstructionManager\']'
                  '@true'
                ]
              }
            ]
          }
          type: 'If'
        }
        'Condition_(Date)': {
          actions: {
            Update_Project_Manager_Field_1: {
              type: 'ApiConnection'
              inputs: {
                host: {
                  connection: {
                    name: '@parameters(\'$connections\')[\'azureautomation\'][\'connectionId\']'
                  }
                }
                method: 'put'
                body: {
                  properties: {
                    parameters: {
                      Url: '@triggerBody()?[\'GtSiteUrl\']'
                      HubSiteUrl: hubSiteUrl
                    }
                  }
                }
                path: '/subscriptions/@{encodeURIComponent(\'${subscriptionId}\')}/resourceGroups/@{encodeURIComponent(\'${resourceGroupName}\')}/providers/Microsoft.Automation/automationAccounts/@{encodeURIComponent(\'${automationAccountName}\')}/jobs'
                queries: {
                  'x-ms-api-version': '2015-10-31'
                  runbookName: 'UpdateProjectDates'
                  wait: false
                }
              }
            }
          }
          runAfter: {
            'Condition_(Manager)': [
              'Succeeded'
              'TimedOut'
              'Skipped'
              'Failed'
            ]
          }
          else: {
            actions: {}
          }
          expression: {
            or: [
              {
                equals: [
                  '@body(\'Get_project_changes\')?[\'ColumnHasChanged\']?[\'GtcHandoverDate\']'
                  '@true'
                ]
              }
            ]
          }
          type: 'If'
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          sharepointonline: {
            id: '/subscriptions/${subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/sharepointonline'
            connectionId: sharePointConnectionId
            connectionName: 'sharepointonline'
            connectionProperties: {}
          }
          azureautomation: {
            id: '/subscriptions/${subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/azureautomation'
            connectionId: automationConnectionId
            connectionName: 'azureautomation'
            connectionProperties: {
              authentication: {
                type: 'ManagedServiceIdentity'
              }
            }
          }
        }
      }
    }
  }
}

output logicAppId string = projectInfoChangedLogicApp.id
output logicAppName string = projectInfoChangedLogicApp.name
