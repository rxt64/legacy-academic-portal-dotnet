@description('Región Azure del Load Balancer interno.')
@allowed([
  'mexicocentral'
])
param location string = 'mexicocentral'

@description('Nombre del Load Balancer interno de SIGEA.')
param lbName string = 'lb-sigea-internal'

@description('ID de la subred de SIGEA donde se asigna el frontend privado del Load Balancer (asignación dinámica).')
param sigeaSubnetId string

@description('ID de la red virtual compartida, requerido para registrar la IP del backend por dirección.')
param vnetId string

@description('IP privada de la VM de SIGEA (vm-sigea-win) ya existente, para agregarla al pool de backend sin modificar su NIC.')
param sigeaVmPrivateIp string

@description('Puerto HTTP de la aplicación SIGEA (IIS, binding *:80).')
param appPort int = 80

@description('Tags de los recursos.')
param tags object = {}

var frontendName = 'fe-sigea-private'
var backendPoolName = 'pool-sigea-vm'
var probeName = 'probe-sigea-http'
var ruleName = 'rule-sigea-http'

resource lb 'Microsoft.Network/loadBalancers@2024-07-01' = {
  name: lbName
  location: location
  sku: {
    name: 'Standard'
  }
  tags: tags
  properties: {
    frontendIPConfigurations: [
      {
        name: frontendName
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: sigeaSubnetId
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: backendPoolName
        properties: {
          loadBalancerBackendAddresses: [
            {
              name: 'addr-vm-sigea-win'
              properties: {
                ipAddress: sigeaVmPrivateIp
                virtualNetwork: {
                  id: vnetId
                }
              }
            }
          ]
        }
      }
    ]
    probes: [
      {
        name: probeName
        properties: {
          protocol: 'Tcp'
          port: appPort
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    loadBalancingRules: [
      {
        name: ruleName
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, frontendName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, backendPoolName)
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', lbName, probeName)
          }
          protocol: 'Tcp'
          frontendPort: appPort
          backendPort: appPort
          idleTimeoutInMinutes: 4
          enableFloatingIP: false
          disableOutboundSnat: false
        }
      }
    ]
  }
}

output lbName string = lb.name
output lbId string = lb.id
output frontendPrivateIp string = lb.properties.frontendIPConfigurations[0].properties.privateIPAddress
