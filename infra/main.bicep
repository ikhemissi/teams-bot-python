targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name which is used to generate a short unique hash for each resource')
param name string

@minLength(1)
@description('Primary location for all resources')
param location string

var resourceToken = toLower(uniqueString(subscription().id, name, location))
var prefix = '${name}-${resourceToken}'
var tags = { 'azd-env-name': name }

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${name}-rg'
  location: location
  tags: tags
}

// Monitor application with Azure Monitor
module monitoring './monitoring.bicep' = {
  name: 'monitoring'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    applicationInsightsName: '${prefix}-appinsights'
    logAnalyticsName: '${take(prefix, 50)}-loganalytics' // Max 63 chars
  }
}

module managedIdentity './uami.bicep' = {
  name: 'uami'
  scope: resourceGroup
  params: {
    name: '${prefix}-uami'
    location: location
    tags: tags
  }
}

// Bot App
module app './app.bicep' = {
  name: 'app'
  scope: resourceGroup
  params: {
    name: replace('${take(prefix,19)}-appsvc', '--', '-')
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appCommandLine: 'gunicorn --bind 0.0.0.0 --worker-class aiohttp.worker.GunicornWebWorker --timeout 600 api:api'
    pythonVersion: '3.12'
    managedIdentityId: managedIdentity.outputs.id
    appSettings: {
      MicrosoftAppId: managedIdentity.outputs.clientId
      MicrosoftAppPassword: ''
      MicrosoftAppType: 'UserAssignedMSI'
      MicrosoftAppTenantId: subscription().tenantId
      InstrumentationKey: monitoring.outputs.applicationInsightsInstrumentationKey
      APPLICATIONINSIGHTS_CONNECTION_STRING: monitoring.outputs.applicationInsightsConnectionString
    }
  }
}

// Bot registration
module botRegistration './bot.bicep' = {
  name: 'bot-registration'
  scope: resourceGroup
  params: {
    botServiceName: replace('${take(prefix,15)}-bot', '--', '-')
    botDisplayName: take(prefix,42)
    botAadAppClientId: managedIdentity.outputs.clientId
    mesagingEndpoint: '${app.outputs.uri}/api/messages'
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    managedIdentityId: managedIdentity.outputs.id
  }
}

output AZURE_LOCATION string = location
output APPLICATIONINSIGHTS_NAME string = monitoring.outputs.applicationInsightsName
output BACKEND_URI string = app.outputs.uri
