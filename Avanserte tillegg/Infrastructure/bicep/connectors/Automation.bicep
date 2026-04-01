@description('Name of the Azure Automation connection')
param azureAutomationConnectionName string = 'azureautomation'

@description('Location for the connection resource')
param location string = resourceGroup().location

@description('Display name for the Azure Automation connection')
param displayName string

@description('Subscription ID')
param subscriptionId string = subscription().subscriptionId

@description('Resource tags')
param tags object = {}

resource azureAutomationConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: azureAutomationConnectionName
  location: location
  tags: tags
  kind: 'V1'
  properties: {
    displayName: displayName
    parameterValueType: 'Alternative'
    statuses: [
      {
        status: 'Ready'
      }
    ]
    customParameterValues: {}
    api: {
      name: azureAutomationConnectionName
      displayName: 'Azure Automation'
      description: 'Azure Automation provides tools to manage your cloud and on-premises infrastructure seamlessly.'
      iconUri: 'https://conn-afd-prod-endpoint-bmc9bqahasf3grgk.b01.azurefd.net/releases/v1.0.1793/1.0.1793.4565/${azureAutomationConnectionName}/icon.png'
      id: '/subscriptions/${subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/${azureAutomationConnectionName}'
      type: 'Microsoft.Web/locations/managedApis'
    }
    testLinks: []
  }
}

output connectionId string = azureAutomationConnection.id
output connectionName string = azureAutomationConnection.name
