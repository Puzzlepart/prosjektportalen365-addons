@description('Name of the SharePoint Online connection')
param sharePointOnlineConnectionName string = 'sharepointonline'

@description('Location for the connection resource')
param location string = resourceGroup().location

@description('Display name for the SharePoint Online connection (usually an email address)')
param displayName string

@description('Subscription ID')
param subscriptionId string = subscription().subscriptionId

@description('Resource tags')
param tags object = {}

resource sharePointOnlineConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: sharePointOnlineConnectionName
  location: location
  tags: tags
  kind: 'V1'
  properties: {
    displayName: displayName
    statuses: [
      {
        status: 'Ready'
      }
    ]
    customParameterValues: {}
    nonSecretParameterValues: {}
    api: {
      name: sharePointOnlineConnectionName
      displayName: 'SharePoint'
      description: 'SharePoint helps organizations share and collaborate with colleagues, partners, and customers. You can connect to SharePoint Online or to an on-premises SharePoint 2016 or 2019 farm using the On-Premises Data Gateway to manage documents and list items.'
      iconUri: 'https://conn-afd-prod-endpoint-bmc9bqahasf3grgk.b01.azurefd.net/releases/v1.0.1769/1.0.1769.4361/${sharePointOnlineConnectionName}/icon.png'
      id: '/subscriptions/${subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/${sharePointOnlineConnectionName}'
      type: 'Microsoft.Web/locations/managedApis'
    }
    testLinks: [
      {
        requestUri: '${environment().resourceManager}subscriptions/${subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/connections/${sharePointOnlineConnectionName}/extensions/proxy/datasets?api-version=2016-06-01'
        method: 'get'
      }
    ]
  }
}

output connectionId string = sharePointOnlineConnection.id
output connectionName string = sharePointOnlineConnection.name
