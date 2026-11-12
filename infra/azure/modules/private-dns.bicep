@description('Nombre de la zona DNS privada compartida para acceso interno a las aplicaciones (sin pasar por Azure Front Door).')
param privateDnsZoneName string = 'lab.internal'

@description('ID de la red virtual compartida del laboratorio, para vincular la zona DNS privada.')
param vnetId string

@description('Nombre del enlace de red virtual de la zona DNS privada.')
param vnetLinkName string = 'link-vnet-legacy-lab-mxc'

@description('IP privada del frontend del Load Balancer interno de SIGEA, para el registro A sigea.<privateDnsZoneName>.')
param sigeaLbFrontendIp string

@description('TTL en segundos de los registros DNS.')
param dnsTtlSeconds int = 300

@description('Tags de los recursos.')
param tags object = {}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: privateDnsZoneName
  location: 'global'
  tags: tags
}

resource vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZone
  name: vnetLinkName
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
  tags: tags
}

resource sigeaARecord 'Microsoft.Network/privateDnsZones/A@2024-06-01' = {
  parent: privateDnsZone
  name: 'sigea'
  properties: {
    ttl: dnsTtlSeconds
    aRecords: [
      {
        ipv4Address: sigeaLbFrontendIp
      }
    ]
  }
}

output privateDnsZoneName string = privateDnsZone.name
output privateDnsZoneId string = privateDnsZone.id
output sigeaFqdn string = 'sigea.${privateDnsZoneName}'
