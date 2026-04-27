@description('Name of the RequestProjectAccess Logic App')
param logicAppName string = 'RequestProjectAccess'

@description('Location for the logic app')
param location string = resourceGroup().location

@description('Subscription ID')
param subscriptionId string = subscription().subscriptionId

@description('Connection ID for SharePoint Online connection')
param sharePointConnectionId string

@description('Connection ID for Office 365 connection')
param office365ConnectionId string

@description('Resource tags')
param tags object = {}

resource requestProjectAccessLogicApp 'Microsoft.Logic/workflows@2017-07-01' = {
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
        sendEmail: {
          defaultValue: true
          type: 'Bool'
        }
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        When_an_HTTP_request_is_received: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            method: 'POST'
            schema: {
              type: 'object'
              properties: {
                listName: {
                  type: 'string'
                }
                listId: {
                  type: 'string'
                }
                listTitle: {
                  type: 'string'
                }
                webUrl: {
                  type: 'string'
                }
                siteId: {
                  type: 'string'
                }
                siteTitle: {
                  type: 'string'
                }
                selectedItems: {
                  type: 'array'
                  items: {
                    type: 'object'
                    properties: {
                      GtProjectManager: {
                        type: 'string'
                      }
                      Author: {
                        type: 'string'
                      }
                      Editor: {
                        type: 'string'
                      }
                      FileSystemObjectType: {
                        type: 'integer'
                      }
                      Id: {
                        type: 'integer'
                      }
                      ServerRedirectedEmbedUri: {}
                      ServerRedirectedEmbedUrl: {
                        type: 'string'
                      }
                      ContentTypeId: {
                        type: 'string'
                      }
                      Title: {
                        type: 'string'
                      }
                      OData__ColorTag: {}
                      ComplianceAssetId: {}
                      GtProjectFinanceName: {
                        type: 'string'
                      }
                      GtProjectNumber: {
                        type: 'string'
                      }
                      GtArchiveReference: {
                        type: 'string'
                      }
                      GtProjectServiceArea: {
                        type: 'string'
                      }
                      GtProjectType: {
                        type: 'string'
                      }
                      GtUNSustDevGoals: {
                        type: 'string'
                      }
                      GtProjectPhase: {}
                      GtProjectManagerId: {
                        type: 'integer'
                      }
                      GtProjectManagerStringId: {
                        type: 'string'
                      }
                      GtProjectOwnerId: {}
                      GtProjectOwnerStringId: {}
                      GtProjectSupportId: {}
                      GtProjectSupportStringId: {}
                      GtGainsResponsibleId: {}
                      GtGainsResponsibleStringId: {}
                      GtStartDate: {
                        type: 'string'
                      }
                      GtEndDate: {
                        type: 'string'
                      }
                      GtProjectGoals: {
                        type: 'string'
                      }
                      GtBudgetTotal: {}
                      GtCostsTotal: {}
                      GtProjectForecast: {}
                      GtBudgetLastReportDate: {}
                      GtGroupId: {
                        type: 'string'
                      }
                      GtSiteId: {
                        type: 'string'
                      }
                      GtSiteUrl: {
                        type: 'string'
                      }
                      GtLastSyncTime: {}
                      GtProjectLifecycleStatus: {
                        type: 'string'
                      }
                      GtProjectPhaseText: {}
                      GtProjectServiceAreaText: {
                        type: 'string'
                      }
                      GtProjectTypeText: {
                        type: 'string'
                      }
                      GtUNSustDevGoalsText: {
                        type: 'string'
                      }
                      GtProjectAdminRoles: {
                        type: 'string'
                      }
                      GtProjectTemplate: {
                        type: 'string'
                      }
                      GtParentProjects: {
                        type: 'string'
                      }
                      GtChildProjects: {
                        type: 'string'
                      }
                      GtIsParentProject: {
                        type: 'boolean'
                      }
                      GtIsProgram: {
                        type: 'boolean'
                      }
                      GtInstalledVersion: {
                        type: 'string'
                      }
                      GtCurrentVersion: {
                        type: 'string'
                      }
                      GtBAEndDateOriginal: {}
                      GtBAProjectPolitical: {}
                      GtBAProjectPoliticalComment: {}
                      GtBAProjectPoliticalLink: {}
                      GtProjectExtensions: {}
                      GtProjectListContent: {}
                      ID: {
                        type: 'integer'
                      }
                      Modified: {
                        type: 'string'
                      }
                      Created: {
                        type: 'string'
                      }
                      AuthorId: {
                        type: 'integer'
                      }
                      EditorId: {
                        type: 'integer'
                      }
                      OData__UIVersionString: {
                        type: 'string'
                      }
                      Attachments: {
                        type: 'boolean'
                      }
                      GUID: {
                        type: 'string'
                      }
                    }
                    required: [
                      'GtProjectManager'
                      'Author'
                      'Editor'
                      'FileSystemObjectType'
                      'Id'
                      'ServerRedirectedEmbedUri'
                      'ServerRedirectedEmbedUrl'
                      'ContentTypeId'
                      'Title'
                      'OData__ColorTag'
                      'ComplianceAssetId'
                      'GtProjectFinanceName'
                      'GtProjectNumber'
                      'GtArchiveReference'
                      'GtProjectServiceArea'
                      'GtProjectType'
                      'GtUNSustDevGoals'
                      'GtProjectPhase'
                      'GtProjectManagerId'
                      'GtProjectManagerStringId'
                      'GtProjectOwnerId'
                      'GtProjectOwnerStringId'
                      'GtProjectSupportId'
                      'GtProjectSupportStringId'
                      'GtGainsResponsibleId'
                      'GtGainsResponsibleStringId'
                      'GtStartDate'
                      'GtEndDate'
                      'GtProjectGoals'
                      'GtBudgetTotal'
                      'GtCostsTotal'
                      'GtProjectForecast'
                      'GtBudgetLastReportDate'
                      'GtGroupId'
                      'GtSiteId'
                      'GtSiteUrl'
                      'GtLastSyncTime'
                      'GtProjectLifecycleStatus'
                      'GtProjectPhaseText'
                      'GtProjectServiceAreaText'
                      'GtProjectTypeText'
                      'GtUNSustDevGoalsText'
                      'GtProjectAdminRoles'
                      'GtProjectTemplate'
                      'GtParentProjects'
                      'GtChildProjects'
                      'GtIsParentProject'
                      'GtIsProgram'
                      'GtInstalledVersion'
                      'GtCurrentVersion'
                      'GtBAEndDateOriginal'
                      'GtBAProjectPolitical'
                      'GtBAProjectPoliticalComment'
                      'GtBAProjectPoliticalLink'
                      'GtProjectExtensions'
                      'GtProjectListContent'
                      'ID'
                      'Modified'
                      'Created'
                      'AuthorId'
                      'EditorId'
                      'OData__UIVersionString'
                      'Attachments'
                      'GUID'
                    ]
                  }
                }
                currentUser: {
                  type: 'object'
                  properties: {
                    displayName: {
                      type: 'string'
                    }
                    email: {
                      type: 'string'
                    }
                    loginName: {
                      type: 'string'
                    }
                  }
                }
                timestamp: {
                  type: 'string'
                }
                actionName: {
                  type: 'string'
                }
              }
            }
          }
        }
      }
      actions: {
        Iterate_Projects: {
          foreach: '@triggerBody()?[\'selectedItems\']'
          actions: {
            Get_Project_Manager: {
              type: 'Query'
              inputs: {
                from: '@body(\'Build_Users_array\')'
                where: '@equals(items(\'Iterate_Projects\')?[\'GtProjectManagerId\'], item()?[\'ID\'])'
              }
            }
            Append_to_projectArray: {
              runAfter: {
                Get_Project_Owner: [
                  'Succeeded'
                ]
              }
              type: 'AppendToArrayVariable'
              inputs: {
                name: 'ProjectArray'
                value: {
                  Project: '@{item()?[\'Title\']}'
                  GtProjectOwnerName: '@{first(body(\'Get_Project_Owner\'))?[\'Title\']}'
                  GtProjectOwnerEmail: '@{first(body(\'Get_Project_Owner\'))?[\'Email\']}'
                  GtProjectManagerName: '@{first(body(\'Get_Project_Manager\'))?[\'Title\']}'
                  GtProjectManagerEmail: '@{first(body(\'Get_Project_Manager\'))?[\'Email\']}'
                  ProjectUrl: '@{item()?[\'GtSiteUrl\']}'
                }
              }
            }
            Get_Project_Owner: {
              runAfter: {
                Get_Project_Manager: [
                  'Succeeded'
                ]
              }
              type: 'Query'
              inputs: {
                from: '@body(\'Build_Users_array\')'
                where: '@equals(items(\'Iterate_Projects\')?[\'GtProjectOwnerId\'], item()?[\'ID\'])'
              }
            }
          }
          runAfter: {
            Build_Users_array: [
              'Succeeded'
            ]
          }
          type: 'Foreach'
        }
        'Get_Users_(HTTP)': {
          runAfter: {
            Initialize_variables: [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'sharepointonline\'][\'connectionId\']'
              }
            }
            method: 'post'
            body: {
              method: 'GET'
              uri: '/_api/web/siteusers\n'
            }
            path: '/datasets/@{encodeURIComponent(encodeURIComponent(triggerBody()?[\'webUrl\']))}/httprequest'
          }
        }
        Build_Users_array: {
          runAfter: {
            'Get_Users_(HTTP)': [
              'Succeeded'
            ]
          }
          type: 'Select'
          inputs: {
            from: '@body(\'Get_Users_(HTTP)\')?[\'d\']?[\'results\']'
            select: {
              ID: '@item()?[\'Id\']'
              Title: '@item()?[\'Title\']'
              Email: '@item()?[\'Email\']'
            }
          }
        }
        Initialize_variables: {
          runAfter: {}
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'projectArray'
                type: 'array'
              }
              {
                name: 'approvers'
                type: 'array'
              }
            ]
          }
        }
        For_the_Project: {
          foreach: '@variables(\'ProjectArray\')'
          actions: {
            Send_approval_email_one_project: {
              runAfter: {
                If_manager_not_empty: [
                  'Succeeded'
                ]
              }
              type: 'ApiConnectionWebhook'
              inputs: {
                host: {
                  connection: {
                    name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
                  }
                }
                body: {
                  NotificationUrl: '@listCallbackUrl()'
                  Message: {
                    To: '@join(variables(\'approvers\'), \';\')'
                    HeaderText: 'Tilgangsforespørsel @{items(\'For_the_Project\')?[\'Project\']}.'
                    Body: 'Hei,\n\n@{triggerBody()?[\'currentUser\']?[\'displayName\']} (@{triggerBody()?[\'currentUser\']?[\'email\']}) har forespurt tilgang i @{items(\'For_the_Project\')?[\'Project\']}.'
                    Importance: 'Normal'
                    UseOnlyHTMLMessage: false
                    HideHTMLMessage: true
                    ShowHTMLConfirmationDialog: false
                    Subject: 'Tilgangsforespørsel @{items(\'For_the_Project\')?[\'Project\']}.'
                    Options: 'Godkjenn,Avslå'
                  }
                }
                path: '/approvalmail/$subscriptions'
              }
            }
            If_owner_not_empty: {
              actions: {
                Append_Owner_to_approvers: {
                  type: 'AppendToArrayVariable'
                  inputs: {
                    name: 'approvers'
                    value: '@items(\'For_the_Project\')?[\'GtProjectOwnerEmail\']'
                  }
                }
              }
              else: {
                actions: {}
              }
              expression: {
                and: [
                  {
                    equals: [
                      '@not(empty(items(\'For_the_Project\')?[\'GtProjectOwnerEmail\']))'
                      '@true'
                    ]
                  }
                ]
              }
              type: 'If'
            }
            If_manager_not_empty: {
              actions: {
                Append_to_Manager_approvers: {
                  type: 'AppendToArrayVariable'
                  inputs: {
                    name: 'approvers'
                    value: '@items(\'For_the_Project\')?[\'GtProjectManagerEmail\']'
                  }
                }
              }
              runAfter: {
                If_owner_not_empty: [
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
                      '@not(empty(items(\'For_the_Project\')?[\'GtProjectManagerEmail\']))'
                      '@true'
                    ]
                  }
                ]
              }
              type: 'If'
            }
            If_Approved: {
              actions: {
                Get_Visitor_group: {
                  type: 'ApiConnection'
                  inputs: {
                    host: {
                      connection: {
                        name: '@parameters(\'$connections\')[\'sharepointonline\'][\'connectionId\']'
                      }
                    }
                    method: 'post'
                    body: {
                      method: 'GET'
                      uri: '_api/web?$select=AssociatedVisitorGroup/Id&$expand=AssociatedVisitorGroup'
                    }
                    path: '/datasets/@{encodeURIComponent(encodeURIComponent(items(\'For_the_Project\')?[\'ProjectUrl\']))}/httprequest'
                  }
                }
                Add_user_to_visitor_group: {
                  runAfter: {
                    Ensure_user: [
                      'Succeeded'
                    ]
                  }
                  type: 'ApiConnection'
                  inputs: {
                    host: {
                      connection: {
                        name: '@parameters(\'$connections\')[\'sharepointonline\'][\'connectionId\']'
                      }
                    }
                    method: 'post'
                    body: {
                      method: 'POST'
                      uri: '_api/web/sitegroups(@{body(\'Get_Visitor_group\')?[\'d\']?[\'AssociatedVisitorGroup\']?[\'Id\']})/users'
                      headers: {
                        Accept: 'application/json;odata=verbose'
                        'Content-Type': 'application/json;odata=verbose'
                      }
                      body: '{\n  "__metadata": { "type": "SP.User" },\n  "LoginName": "@{body(\'Ensure_user\')?[\'d\']?[\'LoginName\']}"\n}'
                    }
                    path: '/datasets/@{encodeURIComponent(encodeURIComponent(items(\'For_the_Project\')?[\'ProjectUrl\']))}/httprequest'
                  }
                }
                Ensure_user: {
                  runAfter: {
                    Get_Visitor_group: [
                      'Succeeded'
                    ]
                  }
                  type: 'ApiConnection'
                  inputs: {
                    host: {
                      connection: {
                        name: '@parameters(\'$connections\')[\'sharepointonline\'][\'connectionId\']'
                      }
                    }
                    method: 'post'
                    body: {
                      method: 'POST'
                      uri: '_api/web/ensureuser'
                      headers: {
                        Accept: 'application/json;odata=verbose'
                        'Content-Type': 'application/json;odata=verbose'
                      }
                      body: '{ "logonName": "@{triggerBody()?[\'currentUser\']?[\'loginName\']}" }'
                    }
                    path: '/datasets/@{encodeURIComponent(encodeURIComponent(items(\'For_the_Project\')?[\'ProjectUrl\']))}/httprequest'
                  }
                }
                Send_approved_email: {
                  runAfter: {
                    Add_user_to_visitor_group: [
                      'Succeeded'
                    ]
                  }
                  type: 'ApiConnection'
                  inputs: {
                    host: {
                      connection: {
                        name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
                      }
                    }
                    method: 'post'
                    body: {
                      To: '@triggerBody()?[\'currentUser\']?[\'email\']'
                      Subject: 'Tilgangsforespørsel til @{items(\'For_the_Project\')?[\'Project\']} godkjent'
                      Body: '<p class="editor-paragraph">Hei @{triggerBody()?[\'currentUser\']?[\'displayName\']},</p><br><p class="editor-paragraph">Din tilgangsforespørsel til @{items(\'For_the_Project\')?[\'Project\']} er godkjent.</p><br><p class="editor-paragraph"><a href="@{items(\'For_the_Project\')?[\'ProjectUrl\']}" class="editor-link">Trykk her for å gå til prosjektet</a></p>'
                      Importance: 'Normal'
                    }
                    path: '/v2/Mail'
                  }
                }
              }
              runAfter: {
                Send_approval_email_one_project: [
                  'Succeeded'
                ]
              }
              else: {
                actions: {
                  Send_rejected_email: {
                    type: 'ApiConnection'
                    inputs: {
                      host: {
                        connection: {
                          name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
                        }
                      }
                      method: 'post'
                      body: {
                        To: '@triggerBody()?[\'currentUser\']?[\'email\']'
                        Subject: 'Tilgangsforespørsel til @{items(\'For_the_Project\')?[\'Project\']} avslått'
                        Body: '<p class="editor-paragraph">Hei @{triggerBody()?[\'currentUser\']?[\'displayName\']},</p><br><p class="editor-paragraph">Din tilgangsforespørsel til  @{items(\'For_the_Project\')?[\'Project\']} er avslått.</p>'
                        Importance: 'Normal'
                      }
                      path: '/v2/Mail'
                    }
                  }
                }
              }
              expression: {
                and: [
                  {
                    equals: [
                      '@body(\'Send_approval_email_one_project\')?[\'SelectedOption\']'
                      'Godkjenn'
                    ]
                  }
                ]
              }
              type: 'If'
            }
          }
          runAfter: {
            Iterate_Projects: [
              'Succeeded'
            ]
          }
          type: 'Foreach'
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
          office365: {
            id: '/subscriptions/${subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/office365'
            connectionId: office365ConnectionId
            connectionName: 'office365'
            connectionProperties: {}
          }
        }
      }
    }
  }
}

output logicAppId string = requestProjectAccessLogicApp.id
output logicAppName string = requestProjectAccessLogicApp.name
output triggerUrl string = listCallbackURL(resourceId('Microsoft.Logic/workflows/triggers', logicAppName, 'When_an_HTTP_request_is_received'), '2017-07-01').value
