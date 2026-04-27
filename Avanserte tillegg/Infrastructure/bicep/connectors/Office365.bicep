@description('Name of the Office 365 connection')
param office365ConnectionName string = 'office365'

@description('Location for the connection resource')
param location string = resourceGroup().location

@description('Display name for the Office 365 connection (usually an email address)')
param displayName string

@description('Subscription ID')
param subscriptionId string = subscription().subscriptionId

@description('Resource tags')
param tags object = {}

resource office365Connection 'Microsoft.Web/connections@2016-06-01' = {
  name: office365ConnectionName
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
      name: office365ConnectionName
      displayName: 'Office 365 Outlook'
      description: 'Microsoft Office 365 is a cloud-based service that is designed to help meet your organization\'s needs for robust security, reliability, and user productivity.'
      iconUri: 'https://conn-afd-prod-endpoint-bmc9bqahasf3grgk.b01.azurefd.net/releases/v1.0.1769/1.0.1769.4361/${office365ConnectionName}/icon.png'
      id: '/subscriptions/${subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/${office365ConnectionName}'
      type: 'Microsoft.Web/locations/managedApis'
    }
    testLinks: []
  }
}

output connectionId string = office365Connection.id
output connectionName string = office365Connection.name
