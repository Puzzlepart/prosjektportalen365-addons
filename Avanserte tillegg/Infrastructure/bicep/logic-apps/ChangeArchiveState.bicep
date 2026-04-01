@description('Name of the ChangeArchiveState Logic App')
param logicAppName string = 'ChangeArchiveState'

@description('Location for the logic app')
param location string = resourceGroup().location

@description('Subscription ID')
param subscriptionId string = subscription().subscriptionId

@description('Resource group name')
param resourceGroupName string = resourceGroup().name

@description('Name of the automation account')
param automationAccountName string

@description('Connection ID for Azure Automation connection')
param automationConnectionId string

@description('Resource tags')
param tags object = {}

resource changeArchiveStateLogicApp 'Microsoft.Logic/workflows@2017-07-01' = {
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
        When_a_HTTP_request_is_received: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              type: 'object'
              properties: {
                Url: {
                  type: 'string'
                }
                Status: {
                  type: 'string'
                }
              }
            }
          }
        }
      }
      actions: {
        Start_Archive_Site_Job: {
          runAfter: {
            Parse_JSON: [
              'Succeeded'
            ]
          }
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
                  URL: '@triggerBody()?[\'Url\']'
                  groupID: '@body(\'Parse_JSON\')?[\'GroupId\']'
                  status: '@triggerBody()?[\'Status\']'
                  HubSiteUrl: '@body(\'Parse_JSON\')?[\'HubSiteUrl\']'
                }
              }
            }
            path: '/subscriptions/@{encodeURIComponent(\'${subscriptionId}\')}/resourceGroups/@{encodeURIComponent(\'${resourceGroupName}\')}/providers/Microsoft.Automation/automationAccounts/@{encodeURIComponent(\'${automationAccountName}\')}/jobs'
            queries: {
              'x-ms-api-version': '2015-10-31'
              runbookName: 'ArchiveSite'
              wait: false
            }
          }
        }
        Start_Get_Site_Information_runbook: {
          runAfter: {}
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
                  Url: '@triggerBody()?[\'Url\']'
                }
              }
            }
            path: '/subscriptions/@{encodeURIComponent(\'${subscriptionId}\')}/resourceGroups/@{encodeURIComponent(\'${resourceGroupName}\')}/providers/Microsoft.Automation/automationAccounts/@{encodeURIComponent(\'${automationAccountName}\')}/jobs'
            queries: {
              'x-ms-api-version': '2015-10-31'
              runbookName: 'GetSiteInformation'
              wait: true
            }
          }
        }
        Get_site_information_output: {
          runAfter: {
            Start_Get_Site_Information_runbook: [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'azureautomation\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/subscriptions/@{encodeURIComponent(\'${subscriptionId}\')}/resourceGroups/@{encodeURIComponent(\'${resourceGroupName}\')}/providers/Microsoft.Automation/automationAccounts/@{encodeURIComponent(\'${automationAccountName}\')}/jobs/@{encodeURIComponent(body(\'Start_Get_Site_Information_runbook\')?[\'properties\']?[\'jobId\'])}/output'
            queries: {
              'x-ms-api-version': '2015-10-31'
            }
          }
        }
        Parse_JSON: {
          runAfter: {
            Get_site_information_output: [
              'Succeeded'
            ]
          }
          type: 'ParseJson'
          inputs: {
            content: '@body(\'Get_site_information_output\')'
            schema: {
              type: 'object'
              properties: {
                GroupId: {
                  type: 'string'
                }
                SiteTitle: {
                  type: 'string'
                }
                HubSiteUrl: {
                  type: 'string'
                }
                Phase: {
                  type: 'string'
                }
                SiteId: {
                  type: 'string'
                }
              }
            }
          }
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
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

output logicAppId string = changeArchiveStateLogicApp.id
output logicAppName string = changeArchiveStateLogicApp.name
output triggerUrl string = listCallbackURL(resourceId('Microsoft.Logic/workflows/triggers', logicAppName, 'When_a_HTTP_request_is_received'), '2017-07-01').value
