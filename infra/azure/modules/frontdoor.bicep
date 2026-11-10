@description('Nombre del perfil compartido de Azure Front Door Standard.')
param frontDoorProfileName string

@description('Nombre del endpoint de Azure Front Door para SIGEA.')
param sigeaEndpointName string

@description('FQDN o dirección IP del origen de SIGEA (VM Windows Server con IIS).')
param sigeaOriginHostName string

@description('Puerto HTTP del origen de SIGEA.')
param sigeaOriginHttpPort int = 80

@description('Tags aplicados al perfil y endpoint de Azure Front Door.')
param tags object = {}

resource frontDoorProfile 'Microsoft.Cdn/profiles@2024-02-01' = {
  name: frontDoorProfileName
  location: 'Global'
  tags: tags
  sku: {
    name: 'Standard_AzureFrontDoor'
  }
  properties: {
    originResponseTimeoutSeconds: 60
  }
}

resource sigeaEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2024-02-01' = {
  parent: frontDoorProfile
  name: sigeaEndpointName
  location: 'Global'
  tags: union(tags, {
    application: 'SIGEA'
  })
  properties: {
    enabledState: 'Enabled'
  }
}

resource sigeaOriginGroup 'Microsoft.Cdn/profiles/originGroups@2024-02-01' = {
  parent: frontDoorProfile
  name: 'og-sigea'
  properties: {
    sessionAffinityState: 'Enabled'
    trafficRestorationTimeToHealedOrNewEndpointsInMinutes: 0
    loadBalancingSettings: {
      sampleSize: 2
      successfulSamplesRequired: 1
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'GET'
      probeProtocol: 'Http'
      probeIntervalInSeconds: 15
    }
  }
}

resource sigeaOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2024-02-01' = {
  parent: sigeaOriginGroup
  name: 'origin-sigea-vm'
  properties: {
    hostName: sigeaOriginHostName
    originHostHeader: sigeaOriginHostName
    httpPort: sigeaOriginHttpPort
    httpsPort: 443
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: false
  }
}

resource sigeaRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2024-02-01' = {
  parent: sigeaEndpoint
  name: 'route-sigea-default'
  dependsOn: [
    sigeaOrigin
  ]
  properties: {
    originGroup: {
      id: sigeaOriginGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
}

output frontDoorProfileId string = frontDoorProfile.id
output frontDoorProfileName string = frontDoorProfile.name
output frontDoorId string = frontDoorProfile.properties.frontDoorId
output sigeaEndpointName string = sigeaEndpoint.name
output sigeaEndpointHostName string = sigeaEndpoint.properties.hostName
output sigeaEndpointUrl string = 'https://${sigeaEndpoint.properties.hostName}/'
