@description('Región Azure para Azure Bastion y la VM puente (Jumpbox).')
@allowed([
  'mexicocentral'
])
param location string = 'mexicocentral'

@description('Nombre de la red virtual compartida existente.')
param vnetName string = 'vnet-legacy-lab-mxc'

@description('Prefijo CIDR para AzureBastionSubnet (/26 mínimo requerido por Azure Bastion).')
param bastionSubnetPrefix string = '10.42.7.0/26'

@description('Nombre de la subred dedicada a la VM puente (Jumpbox).')
param jumpboxSubnetName string = 'snet-jumpbox'

@description('Prefijo CIDR de la subred de la VM puente.')
param jumpboxSubnetPrefix string = '10.42.8.0/24'

@description('Nombre del recurso Azure Bastion.')
param bastionName string = 'bas-legacy-lab-mxc'

@description('SKU de Azure Bastion.')
@allowed([
  'Basic'
  'Standard'
])
param bastionSku string = 'Standard'

@description('Nombre de la máquina virtual puente (Jumpbox) para demostración del laboratorio.')
param jumpboxVmName string = 'vm-jumpbox-lab'

@description('Tamaño de la máquina virtual puente.')
param jumpboxVmSize string = 'Standard_D4s_v5'

@description('Usuario administrador local de la VM puente.')
param adminUsername string = 'jumpboxadmin'

@description('Contraseña del usuario administrador local de la VM puente.')
@secure()
param adminPassword string

@description('Tags aplicados a los recursos de Bastion y Jumpbox.')
param tags object = {}

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnetName
}

resource bastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  parent: vnet
  name: 'AzureBastionSubnet'
  properties: {
    addressPrefix: bastionSubnetPrefix
  }
}

resource jumpboxNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-${jumpboxVmName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-Bastion-RDP-SSH-Inbound'
        properties: {
          description: 'Permite conexiones RDP (3389) y SSH (22) exclusivamente desde AzureBastionSubnet.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '3389'
            '22'
          ]
          sourceAddressPrefix: bastionSubnetPrefix
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'Deny-Internet-Inbound'
        properties: {
          description: 'Bloquea cualquier acceso directo desde Internet hacia la VM puente.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 200
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource jumpboxSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  parent: vnet
  name: jumpboxSubnetName
  dependsOn: [
    bastionSubnet
  ]
  properties: {
    addressPrefix: jumpboxSubnetPrefix
    networkSecurityGroup: {
      id: jumpboxNsg.id
    }
  }
}

resource bastionPip 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: 'pip-${bastionName}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2023-11-01' = {
  name: bastionName
  location: location
  tags: tags
  sku: {
    name: bastionSku
  }
  properties: {
    enableTunneling: bastionSku == 'Standard'
    enableIpConnect: bastionSku == 'Standard'
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          subnet: {
            id: bastionSubnet.id
          }
          publicIPAddress: {
            id: bastionPip.id
          }
        }
      }
    ]
  }
}

resource jumpboxNic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'nic-${jumpboxVmName}'
  location: location
  tags: tags
  properties: {
    networkSecurityGroup: {
      id: jumpboxNsg.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: jumpboxSubnet.id
          }
        }
      }
    ]
  }
}

resource jumpboxVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: jumpboxVmName
  location: location
  tags: union(tags, {
    application: 'Lab-Jumpbox'
    role: 'presenter-workstation'
  })
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: jumpboxVmSize
    }
    osProfile: {
      computerName: 'vmjumpboxlab'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: false
        patchSettings: {
          patchMode: 'Manual'
          assessmentMode: 'ImageDefault'
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-g2'
        version: 'latest'
      }
      osDisk: {
        name: 'osdisk-${jumpboxVmName}'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        deleteOption: 'Detach'
        diskSizeGB: 128
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: jumpboxNic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

output bastionName string = bastion.name
output jumpboxVmName string = jumpboxVm.name
output jumpboxPrivateIp string = jumpboxNic.properties.ipConfigurations[0].properties.privateIPAddress
