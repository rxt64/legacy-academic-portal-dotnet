@description('Región Azure para los recursos de red.')
@allowed([
  'mexicocentral'
])
param location string = 'mexicocentral'

@description('Nombre de la red virtual compartida.')
param vnetName string

@description('Espacio de direcciones CIDR de la VNet.')
param vnetAddressPrefix string

@description('Nombre de la subred para SIGEA.')
param sigeaSubnetName string

@description('Prefijo CIDR de la subred de SIGEA.')
param sigeaSubnetPrefix string

@description('Nombre de la subred para GEPER.')
param geperSubnetName string

@description('Prefijo CIDR de la subred de GEPER.')
param geperSubnetPrefix string

@description('Nombre de la subred delegada a Azure SQL Managed Instance.')
param sqlMiSubnetName string = 'snet-sqlmi'

@description('Prefijo CIDR de la subred delegada a Azure SQL Managed Instance (/26 mínimo recomendado).')
param sqlMiSubnetPrefix string = '10.42.3.0/26'

@description('Nombre de la subred delegada a Azure Container Apps Environment.')
param acaSubnetName string = 'snet-aca'

@description('Prefijo CIDR de la subred delegada a Azure Container Apps Environment (/23 para Consumption workload profile).')
param acaSubnetPrefix string = '10.42.4.0/23'

@description('Nombre de la subred para Private Endpoints de bases de datos y almacenamiento.')
param privateEndpointSubnetName string = 'snet-private-endpoints'

@description('Prefijo CIDR de la subred para Private Endpoints.')
param privateEndpointSubnetPrefix string = '10.42.6.0/24'

@description('Nombre del NSG de SIGEA.')
param sigeaNsgName string

@description('CIDR IPv4 público del presentador para RDP (3389). Vacío deshabilita la regla de entrada RDP. Prohibido 0.0.0.0/0 o *.')
param presenterAllowedCidr string = ''

@description('Permitir tráfico entrante desde el Service Tag AzureFrontDoor.Backend hacia el puerto 80 de SIGEA.')
param enableFrontDoorBackend bool = true

@description('Tags de los recursos.')
param tags object = {}

var hasValidPresenterCidr = !empty(presenterAllowedCidr) && presenterAllowedCidr != '0.0.0.0/0' && presenterAllowedCidr != '*' && presenterAllowedCidr != 'Internet'

var rdpAllowRules = hasValidPresenterCidr ? [
  {
    name: 'Allow-Presenter-RDP-Inbound'
    properties: {
      description: 'Permite RDP exclusivamente desde la IP publica verificada del presentador.'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '3389'
      sourceAddressPrefix: presenterAllowedCidr
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 100
      direction: 'Inbound'
    }
  }
] : []

var frontDoorAllowRules = enableFrontDoorBackend ? [
  {
    name: 'Allow-AzureFrontDoor-HTTP-Inbound'
    properties: {
      description: 'Permite trafico HTTP entrante exclusivamente desde Azure Front Door (Service Tag AzureFrontDoor.Backend).'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '80'
      sourceAddressPrefix: 'AzureFrontDoor.Backend'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 150
      direction: 'Inbound'
    }
  }
] : []

var baseDenyRules = [
  {
    name: 'Deny-Internet-Web-Inbound'
    properties: {
      description: 'Bloquea exposicion publica de puertos web HTTP/HTTPS hacia SIGEA.'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRanges: [
        '80'
        '443'
        '8080'
      ]
      sourceAddressPrefix: 'Internet'
      destinationAddressPrefix: '*'
      access: 'Deny'
      priority: 200
      direction: 'Inbound'
    }
  }
  {
    name: 'Deny-Internet-Database-Inbound'
    properties: {
      description: 'Bloquea exposicion publica de SQL Server (1433/1434) desde Internet.'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRanges: [
        '1433'
        '1434'
      ]
      sourceAddressPrefix: 'Internet'
      destinationAddressPrefix: '*'
      access: 'Deny'
      priority: 210
      direction: 'Inbound'
    }
  }
]

resource sigeaNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: sigeaNsgName
  location: location
  tags: tags
  properties: {
    securityRules: concat(rdpAllowRules, frontDoorAllowRules, baseDenyRules)
  }
}

resource sqlMiNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-${sqlMiSubnetName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-VNet-TDS-1433-Inbound'
        properties: {
          description: 'Permite conexiones TDS (1433) desde la VNet compartida (vm-sigea-win) hacia Azure SQL Managed Instance.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: vnetAddressPrefix
          destinationAddressPrefix: sqlMiSubnetPrefix
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-VNet-Redirect-11000-11999-Inbound'
        properties: {
          description: 'Permite puertos de redireccion de Azure SQL Managed Instance desde la VNet compartida.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '11000-11999'
          sourceAddressPrefix: vnetAddressPrefix
          destinationAddressPrefix: sqlMiSubnetPrefix
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource sqlMiRouteTable 'Microsoft.Network/routeTables@2023-11-01' = {
  name: 'rt-${sqlMiSubnetName}'
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'sqlmi-default-internet'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'Internet'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: sigeaSubnetName
        properties: {
          addressPrefix: sigeaSubnetPrefix
          networkSecurityGroup: {
            id: sigeaNsg.id
          }
        }
      }
      {
        name: geperSubnetName
        properties: {
          addressPrefix: geperSubnetPrefix
        }
      }
      {
        name: sqlMiSubnetName
        properties: {
          addressPrefix: sqlMiSubnetPrefix
          networkSecurityGroup: {
            id: sqlMiNsg.id
          }
          routeTable: {
            id: sqlMiRouteTable.id
          }
          delegations: [
            {
              name: 'sqlmi-delegation'
              properties: {
                serviceName: 'Microsoft.Sql/managedInstances'
              }
            }
          ]
        }
      }
      {
        name: acaSubnetName
        properties: {
          addressPrefix: acaSubnetPrefix
          delegations: [
            {
              name: 'aca-delegation'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        name: privateEndpointSubnetName
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output sigeaSubnetId string = vnet.properties.subnets[0].id
output sigeaSubnetName string = vnet.properties.subnets[0].name
output geperSubnetId string = vnet.properties.subnets[1].id
output geperSubnetName string = vnet.properties.subnets[1].name
output sqlMiSubnetId string = vnet.properties.subnets[2].id
output sqlMiSubnetName string = vnet.properties.subnets[2].name
output acaSubnetId string = vnet.properties.subnets[3].id
output acaSubnetName string = vnet.properties.subnets[3].name
output privateEndpointSubnetId string = vnet.properties.subnets[4].id
output privateEndpointSubnetName string = vnet.properties.subnets[4].name
output sigeaNsgId string = sigeaNsg.id
