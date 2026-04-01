@description('Name of the PhaseChanged Logic App')
param logicAppName string = 'PhaseChanged'

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

@description('Localized term for "Finished" phase status')
param finishedPhaseText string = 'Ferdig'

@description('Resource tags')
param tags object = {}

resource phaseChangedLogicApp 'Microsoft.Logic/workflows@2017-07-01' = {
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
              properties: {
                webUrl: {
                  type: 'string'
                }
                apiKey: {
                  type: 'string'
                }
              }
              type: 'object'
            }
          }
        }
      }
      actions: {
        Start_Site_Information_job: {
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
                  Url: '@triggerBody()?[\'webUrl\']'
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
        Parse_SiteInfo_JSON: {
          runAfter: {
            Get_Site_Information_Output: [
              'Succeeded'
            ]
          }
          type: 'ParseJson'
          inputs: {
            content: '@body(\'Get_Site_Information_Output\')'
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
        If_phase_is_Finished: {
          actions: {
            Archive_Project_Site: {
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
                      URL: '@triggerBody()?[\'webUrl\']'
                      groupID: '@body(\'Parse_SiteInfo_JSON\')?[\'GroupId\']'
                      HubSiteUrl: '@body(\'Parse_SiteInfo_JSON\')?[\'HubSiteUrl\']'
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
          }
          runAfter: {
            Update_Project_Manager_Field: [
              'Succeeded'
            ]
          }
          else: {
            actions: {}
          }
          expression: {
            and: [
              {
                equals: [
                  '@body(\'Parse_SiteInfo_JSON\')?[\'Phase\']'
                  finishedPhaseText
                ]
              }
            ]
          }
          type: 'If'
        }
        Get_Site_Information_Output: {
          runAfter: {
            Start_Site_Information_job: [
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
            path: '/subscriptions/@{encodeURIComponent(\'${subscriptionId}\')}/resourceGroups/@{encodeURIComponent(\'${resourceGroupName}\')}/providers/Microsoft.Automation/automationAccounts/@{encodeURIComponent(\'${automationAccountName}\')}/jobs/@{encodeURIComponent(body(\'Start_Site_Information_job\')?[\'properties\']?[\'jobId\'])}/output'
            queries: {
              'x-ms-api-version': '2015-10-31'
            }
          }
        }
        Update_Project_Manager_Field: {
          runAfter: {
            Parse_SiteInfo_JSON: [
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
                  Url: '@triggerBody()?[\'webUrl\']'
                  HubSiteUrl: '@body(\'Parse_SiteInfo_JSON\')?[\'HubSiteUrl\']'
                }
              }
            }
            path: '/subscriptions/@{encodeURIComponent(\'${subscriptionId}\')}/resourceGroups/@{encodeURIComponent(\'${resourceGroupName}\')}/providers/Microsoft.Automation/automationAccounts/@{encodeURIComponent(\'${automationAccountName}\')}/jobs'
            queries: {
              'x-ms-api-version': '2015-10-31'
              runbookName: 'UpdateProjectManager'
              wait: true
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

output logicAppId string = phaseChangedLogicApp.id
output logicAppName string = phaseChangedLogicApp.name
output triggerUrl string = listCallbackURL(resourceId('Microsoft.Logic/workflows/triggers', logicAppName, 'When_a_HTTP_request_is_received'), '2017-07-01').value
