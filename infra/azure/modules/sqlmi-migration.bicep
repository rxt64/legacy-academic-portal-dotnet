@description('Región Azure para el almacenamiento temporal de backups y Azure SQL Managed Instance.')
@allowed([
  'mexicocentral'
])
param location string = 'mexicocentral'

@description('Nombre de la cuenta de almacenamiento privada para archivos .bak de migración (3-24 caracteres minúsculas/números).')
param storageAccountName string

@description('Nombre del contenedor privado para backups SQL.')
param backupContainerName string = 'sqlbackups'

@description('Nombre de la instancia de Azure SQL Managed Instance destino para SIGEA.')
param sqlManagedInstanceName string

@description('ID de la subred delegada a Microsoft.Sql/managedInstances.')
param sqlMiSubnetId string

@description('Login del administrador SQL de Azure SQL Managed Instance.')
param sqlMiAdminLogin string = 'sigeamiadmin'

@description('Contraseña del administrador SQL de Azure SQL Managed Instance.')
@secure()
param sqlMiAdminPassword string

@description('SKU de Azure SQL Managed Instance.')
param sqlMiSkuName string = 'GP_Gen5'

@description('Tier de Azure SQL Managed Instance.')
param sqlMiTier string = 'GeneralPurpose'

@description('Familia de hardware de Azure SQL Managed Instance.')
param sqlMiFamily string = 'Gen5'

@description('Número de vCores para Azure SQL Managed Instance.')
param sqlMiVCores int = 4

@description('Tamaño de almacenamiento en GB para Azure SQL Managed Instance.')
param sqlMiStorageSizeInGB int = 32

@description('Principal ID de la identidad administrada de vm-sigea-win para conceder rol Storage Blob Data Contributor.')
param sigeaVmPrincipalId string

@description('ID de la VNet compartida para vinculación de zona DNS privada de Blob Storage.')
param vnetId string

@description('ID de la subred para el Private Endpoint de Blob Storage.')
param privateEndpointSubnetId string

@description('Nombre del administrador Microsoft Entra (UPN) para Azure SQL Managed Instance (opcional).')
param entraAdminLogin string = ''

@description('Object ID (SID) del administrador Microsoft Entra para Azure SQL Managed Instance (opcional).')
param entraAdminObjectId string = ''

@description('Tags aplicados a los recursos de migración de SIGEA.')
param tags object = {}

var storageBlobDataContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')

resource backupStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: union(tags, {
    dataRole: 'sigea-sqlmi-migration-staging'
  })
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: backupStorage
  name: 'default'
}

resource backupContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: backupContainerName
  properties: {
    publicAccess: 'None'
  }
}

resource blobPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  location: 'global'
  tags: tags
}

resource blobPrivateDnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: blobPrivateDnsZone
  name: 'link-blob-vnet'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource blobPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${storageAccountName}-blob'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-${storageAccountName}-blob'
        properties: {
          privateLinkServiceId: backupStorage.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource blobPrivateDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: blobPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-blob'
        properties: {
          privateDnsZoneId: blobPrivateDnsZone.id
        }
      }
    ]
  }
}

resource vmBlobRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(backupStorage.id, sigeaVmPrincipalId, storageBlobDataContributorRoleId)
  scope: backupStorage
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleId
    principalId: sigeaVmPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource sqlMi 'Microsoft.Sql/managedInstances@2023-08-01' = {
  name: sqlManagedInstanceName
  location: location
  tags: union(tags, {
    application: 'SIGEA'
    migrationTarget: 'sql-managed-instance'
  })
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: sqlMiSkuName
    tier: sqlMiTier
    family: sqlMiFamily
    capacity: sqlMiVCores
  }
  properties: {
    administratorLogin: sqlMiAdminLogin
    administratorLoginPassword: sqlMiAdminPassword
    subnetId: sqlMiSubnetId
    vCores: sqlMiVCores
    storageSizeInGB: sqlMiStorageSizeInGB
    licenseType: 'LicenseIncluded'
    requestedBackupStorageRedundancy: 'Local'
    databaseFormat: 'AlwaysUpToDate'
    minimalTlsVersion: '1.2'
    publicDataEndpointEnabled: false
    proxyOverride: 'Default'
    administrators: (!empty(entraAdminLogin) && !empty(entraAdminObjectId)) ? {
      administratorType: 'ActiveDirectory'
      login: entraAdminLogin
      sid: entraAdminObjectId
      tenantId: subscription().tenantId
      principalType: 'User'
      azureADOnlyAuthentication: true
    } : null
  }
}

resource sqlMiBlobRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(backupStorage.id, sqlMi.id, storageBlobDataContributorRoleId)
  scope: backupStorage
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleId
    principalId: sqlMi.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output storageAccountName string = backupStorage.name
output backupContainerUrl string = '${backupStorage.properties.primaryEndpoints.blob}${backupContainerName}'
output sqlManagedInstanceName string = sqlMi.name
output sqlManagedInstanceFqdn string = sqlMi.properties.fullyQualifiedDomainName
output sqlManagedInstancePrincipalId string = sqlMi.identity.principalId
