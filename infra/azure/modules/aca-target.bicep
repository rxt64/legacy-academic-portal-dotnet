@description('Región Azure para Container Registry, Log Analytics y Container Apps Environment.')
@allowed([
  'mexicocentral'
])
param location string = 'mexicocentral'

@description('Nombre del Azure Container Registry compartido para imágenes modernizadas de SIGEA y GEPER.')
param acrName string

@description('Nombre del área de trabajo de Log Analytics para el entorno de Container Apps.')
param logAnalyticsName string

@description('Nombre del entorno administrado de Azure Container Apps (integrado en la VNet compartida).')
param containerAppsEnvironmentName string = 'cae-legacy-modern-mxc'

@description('ID de la subred delegada a Microsoft.App/environments.')
param acaSubnetId string

@description('Nombre de la identidad administrada asignada por el usuario para la futura aplicación SIGEA en Container Apps.')
param sigeaModernIdentityName string = 'id-sigea-modern-aca'

@description('Tags aplicados a los recursos de destino de contenedores.')
param tags object = {}

var acrPullRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource sigeaModernIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: sigeaModernIdentityName
  location: location
  tags: union(tags, {
    application: 'SIGEA'
    role: 'modernized-aca-identity'
  })
}

resource sigeaAcrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, sigeaModernIdentity.id, acrPullRoleId)
  scope: acr
  properties: {
    roleDefinitionId: acrPullRoleId
    principalId: sigeaModernIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource acaEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: containerAppsEnvironmentName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: acaSubnetId
      internal: false
    }
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}

output acrId string = acr.id
output acrName string = acr.name
output acrLoginServer string = acr.properties.loginServer
output containerAppsEnvironmentId string = acaEnv.id
output containerAppsEnvironmentName string = acaEnv.name
output containerAppsDefaultDomain string = acaEnv.properties.defaultDomain
output sigeaModernIdentityId string = sigeaModernIdentity.id
output sigeaModernIdentityName string = sigeaModernIdentity.name
output sigeaModernIdentityClientId string = sigeaModernIdentity.properties.clientId
output sigeaModernIdentityPrincipalId string = sigeaModernIdentity.properties.principalId
