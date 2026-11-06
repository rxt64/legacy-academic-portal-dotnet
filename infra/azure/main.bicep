targetScope = 'subscription'

@description('Región Azure obligatoria para todos los recursos regionales del laboratorio.')
@allowed([
  'mexicocentral'
])
param location string = 'mexicocentral'

@description('Nombre del grupo de recursos compartido del laboratorio.')
param resourceGroupName string = 'rg-legacy-apps-demo-mxc'

@description('Nombre de la red virtual compartida entre SIGEA y GEPER.')
param vnetName string = 'vnet-legacy-lab-mxc'

@description('Prefijo CIDR de la red virtual compartida.')
param vnetAddressPrefix string = '10.42.0.0/16'

@description('Nombre de la subred dedicada a SIGEA.')
param sigeaSubnetName string = 'snet-sigea'

@description('Prefijo CIDR de la subred de SIGEA.')
param sigeaSubnetPrefix string = '10.42.1.0/24'

@description('Nombre de la subred dedicada a GEPER (referenciada como existing desde legacy-hr-portal-java).')
param geperSubnetName string = 'snet-geper'

@description('Prefijo CIDR de la subred de GEPER.')
param geperSubnetPrefix string = '10.42.2.0/24'

@description('CIDR IPv4 público verificado del presentador para acceso RDP (ej. 198.51.100.25/32). Si se deja vacío, no se crea regla de entrada RDP desde Internet. Prohibido 0.0.0.0/0 o *.')
param presenterAllowedCidr string = ''

@description('Habilitar IP pública en la VM de SIGEA para acceso RDP restringido al CIDR del presentador.')
param enablePublicIp bool = true

@description('Nombre de la máquina virtual Windows Server + SQL Server para SIGEA.')
param sigeaVmName string = 'vm-sigea-win'

@description('Tamaño de la VM de SIGEA en Mexico Central (4 vCPU, 16 GiB RAM recomendado).')
param sigeaVmSize string = 'Standard_D4s_v5'

@description('Publisher de la imagen de SIGEA (Windows Server 2022 + SQL Server 2022 Developer).')
param sigeaImagePublisher string = 'MicrosoftSQLServer'

@description('Offer de la imagen de SIGEA.')
param sigeaImageOffer string = 'sql2022-ws2022'

@description('SKU de la imagen de SIGEA (Developer Edition Gen2).')
param sigeaImageSku string = 'sqldev-gen2'

@description('Versión exacta de la imagen de SIGEA.')
param sigeaImageVersion string = '16.0.260610'

@description('SKU del disco de sistema operativo de SIGEA.')
@allowed([
  'StandardSSD_LRS'
  'Premium_LRS'
])
param osDiskSku string = 'StandardSSD_LRS'

@description('Tamaño en GiB del disco de sistema operativo de SIGEA.')
param osDiskSizeGb int = 128

@description('SKU del disco administrado persistente para datos de SQL Server.')
@allowed([
  'StandardSSD_LRS'
  'Premium_LRS'
])
param dataDiskSku string = 'StandardSSD_LRS'

@description('Tamaño en GiB del disco administrado persistente para datos de SQL Server.')
param dataDiskSizeGb int = 128

@description('Usuario administrador local de la VM de SIGEA.')
param adminUsername string = 'sigeaadmin'

@description('Contraseña del administrador local de la VM de SIGEA.')
@secure()
param adminPassword string

@description('Habilitar Key Vault compartido del laboratorio para resguardo de secretos.')
param enableKeyVault bool = true

@description('Habilitar publicación en Azure Front Door Standard compartido del laboratorio.')
param enableFrontDoor bool = true

@description('Nombre del perfil compartido de Azure Front Door Standard (vacío usa nombre determinista basado en el grupo de recursos).')
param frontDoorProfileName string = ''

@description('Nombre del endpoint de Azure Front Door para SIGEA (vacío usa nombre determinista).')
param sigeaFrontDoorEndpointName string = ''

@description('Tags genéricos aplicados a todos los recursos del laboratorio.')
param tags object = {
  project: 'legacy-modernization-lab'
  environment: 'demo'
  purpose: 'academic-and-hr-legacy-baseline'
  managedBy: 'bicep'
}

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module network 'modules/network.bicep' = {
  name: 'deploy-shared-network'
  scope: rg
  params: {
    location: location
    vnetName: vnetName
    vnetAddressPrefix: vnetAddressPrefix
    sigeaSubnetName: sigeaSubnetName
    sigeaSubnetPrefix: sigeaSubnetPrefix
    geperSubnetName: geperSubnetName
    geperSubnetPrefix: geperSubnetPrefix
    sigeaNsgName: 'nsg-${sigeaVmName}'
    presenterAllowedCidr: presenterAllowedCidr
    enableFrontDoorBackend: enableFrontDoor
    tags: tags
  }
}

module keyVault 'modules/keyvault.bicep' = if (enableKeyVault) {
  name: 'deploy-shared-keyvault'
  scope: rg
  params: {
    location: location
    keyVaultName: 'kv-legacylabb-${ take(uniqueString(rg.id), 8) }'
    tags: tags
  }
}

module sigeaVm 'modules/sigea-vm.bicep' = {
  name: 'deploy-sigea-vm'
  scope: rg
  params: {
    location: location
    vmName: sigeaVmName
    vmSize: sigeaVmSize
    subnetId: network.outputs.sigeaSubnetId
    nsgId: network.outputs.sigeaNsgId
    enablePublicIp: enablePublicIp
    imagePublisher: sigeaImagePublisher
    imageOffer: sigeaImageOffer
    imageSku: sigeaImageSku
    imageVersion: sigeaImageVersion
    osDiskSku: osDiskSku
    osDiskSizeGb: osDiskSizeGb
    dataDiskName: 'disk-${sigeaVmName}-sqldata'
    dataDiskSku: dataDiskSku
    dataDiskSizeGb: dataDiskSizeGb
    adminUsername: adminUsername
    adminPassword: adminPassword
    tags: union(tags, {
      application: 'SIGEA'
      stack: 'dotnet48-mvc5-ef6-sql2022'
    })
  }
}

var effectiveFrontDoorProfileName = !empty(frontDoorProfileName) ? frontDoorProfileName : 'afd-legacy-lab-${take(uniqueString(rg.id), 8)}'
var effectiveSigeaEndpointName = !empty(sigeaFrontDoorEndpointName) ? sigeaFrontDoorEndpointName : 'sigea-lab-${take(uniqueString(rg.id), 8)}'

module frontDoor 'modules/frontdoor.bicep' = if (enableFrontDoor && enablePublicIp) {
  name: 'deploy-shared-frontdoor-sigea'
  scope: rg
  params: {
    frontDoorProfileName: effectiveFrontDoorProfileName
    sigeaEndpointName: effectiveSigeaEndpointName
    sigeaOriginHostName: sigeaVm.outputs.publicIpFqdn
    sigeaOriginHttpPort: 80
    tags: tags
  }
}

output resourceGroupName string = rg.name
output location string = rg.location
output vnetName string = network.outputs.vnetName
output vnetId string = network.outputs.vnetId
output sigeaSubnetName string = network.outputs.sigeaSubnetName
output geperSubnetName string = network.outputs.geperSubnetName
output geperSubnetId string = network.outputs.geperSubnetId
output keyVaultName string = enableKeyVault ? keyVault!.outputs.keyVaultName : ''
output sigeaVmName string = sigeaVm.outputs.vmName
output sigeaPrivateIp string = sigeaVm.outputs.privateIpAddress
output sigeaPublicIp string = sigeaVm.outputs.publicIpAddress
output sigeaPublicFqdn string = sigeaVm.outputs.publicIpFqdn
output sigeaDataDiskId string = sigeaVm.outputs.dataDiskId
output frontDoorProfileName string = (enableFrontDoor && enablePublicIp) ? frontDoor!.outputs.frontDoorProfileName : ''
output frontDoorId string = (enableFrontDoor && enablePublicIp) ? frontDoor!.outputs.frontDoorId : ''
output sigeaFrontDoorEndpointHostName string = (enableFrontDoor && enablePublicIp) ? frontDoor!.outputs.sigeaEndpointHostName : ''
output sigeaFrontDoorUrl string = (enableFrontDoor && enablePublicIp) ? frontDoor!.outputs.sigeaEndpointUrl : ''
