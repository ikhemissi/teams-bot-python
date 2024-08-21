param name string
param location string = resourceGroup().location
param tags object = {}
param pythonVersion string
param appCommandLine string
param applicationInsightsName string
param sku string = 'B1'
param alwaysOn bool = true
param ftpsState string = 'FtpsOnly'
param managedIdentityId string
param allowedOrigins array = []
param appSettings object = {}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${name}-asp'
  location: location
  tags: tags
  sku: {
    name: sku
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource web 'Microsoft.Web/sites@2022-09-01' = {
  name: '${name}-bot'
  location: location
  tags: union(tags, {'azd-service-name': 'bot'})
  kind: 'app,linux'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'python|${pythonVersion}'
      alwaysOn: alwaysOn
      ftpsState: ftpsState
      minTlsVersion: '1.2'
      appCommandLine: appCommandLine
      cors: {
        allowedOrigins: union([ 'https://portal.azure.com', 'https://ms.portal.azure.com' ], allowedOrigins)
      }
      // Diagnostic logging
      detailedErrorLoggingEnabled: true
      httpLoggingEnabled: true
      requestTracingEnabled: true
    }
    httpsOnly: true
  }

  // identity: {
  //   type: 'SystemAssigned'
  // }

  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }

  resource basicPublishingCredentialsPoliciesFtp 'basicPublishingCredentialsPolicies' = {
    name: 'ftp'
    properties: {
      allow: false
    }
  }

  resource basicPublishingCredentialsPoliciesScm 'basicPublishingCredentialsPolicies' = {
    name: 'scm'
    properties: {
      allow: false
    }
  }
}

resource configAppSettings 'Microsoft.Web/sites/config@2022-03-01' = {
  name: 'appsettings'
  parent: web
  properties: union(appSettings,
    {
      SCM_DO_BUILD_DURING_DEPLOYMENT: 'true'
      ENABLE_ORYX_BUILD: 'true'
      APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.properties.ConnectionString
    }
  )
}

// sites/web/config 'logs'
resource configLogs 'Microsoft.Web/sites/config@2022-03-01' = {
  name: 'logs'
  parent: web
  properties: {
    applicationLogs: { fileSystem: { level: 'Verbose' } }
    detailedErrorMessages: { enabled: true }
    failedRequestsTracing: { enabled: true }
    httpLogs: { fileSystem: { enabled: true, retentionInDays: 1, retentionInMb: 35 } }
  }
  dependsOn: [configAppSettings]
}

output uri string = 'https://${web.properties.defaultHostName}'
