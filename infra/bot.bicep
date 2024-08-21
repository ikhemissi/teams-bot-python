@maxLength(20)
@minLength(4)
@description('Used to generate names for all resources in this file')
param botServiceName string

@maxLength(42)
param botDisplayName string

param botServiceSku string = 'S1'
param botAadAppClientId string
param mesagingEndpoint string
param managedIdentityId string

param logAnalyticsWorkspaceId string

// param botAadAppClientId string
// param oauthConnectionName string

// @secure()
// param botAddAppClientSecret string

// Register your web service as a bot with the Bot Framework
resource botService 'Microsoft.BotService/botServices@2023-09-15-preview' = {
  kind: 'azurebot'
  location: 'global'
  name: botServiceName
  properties: {
    displayName: botDisplayName
    endpoint: mesagingEndpoint
    msaAppId: botAadAppClientId
    msaAppTenantId: subscription().tenantId
    msaAppType: 'UserAssignedMSI'
    msaAppMSIResourceId: managedIdentityId
    tenantId: subscription().tenantId
  }
  sku: {
    name: botServiceSku
  }
}

// Connect the bot service to Microsoft Teams
resource botServiceMsTeamsChannel 'Microsoft.BotService/botServices/channels@2023-09-15-preview' = {
  parent: botService
  location: 'global'
  name: 'MsTeamsChannel'
  properties: {
    channelName: 'MsTeamsChannel'
    properties: {
      acceptedTerms: true
      isEnabled: true
      deploymentEnvironment: 'CommercialDeployment'
      // callingWebhook: 'string'
      // enableCalling: bool
      // incomingCallRoute: 'string'
    }
  }
}

// resource botServicesMicrosoftGraphConnection 'Microsoft.BotService/botServices/connections@2022-09-15' = {
//   parent: botService
//   name: oauthConnectionName
//   location: 'global'
//   properties: {
//     serviceProviderDisplayName: 'Azure Active Directory v2'
//     serviceProviderId: '30dd229c-58e3-4a48-bdfd-91ec48eb906c'
//     clientId: botAadAppClientId
//     clientSecret: botAddAppClientSecret
//     scopes: 'User.Read'
//     parameters: [
//       {
//         key: 'tenantID'
//         value: 'common'
//       }
//       {
//         key: 'tokenExchangeUrl'
//         value: 'api://botid-${botAadAppClientId}'
//       }
//     ]
//   }
// }

resource diagnosticLogs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: botService.name
  scope: botService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'BotRequest'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}
