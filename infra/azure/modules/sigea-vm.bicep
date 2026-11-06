@description('Región Azure para la VM y discos de SIGEA.')
@allowed([
  'mexicocentral'
])
param location string = 'mexicocentral'

@description('Nombre de la máquina virtual de SIGEA.')
param vmName string

@description('Tamaño de la VM de SIGEA.')
param vmSize string = 'Standard_D4s_v5'

@description('ID de la subred de SIGEA.')
param subnetId string

@description('ID del NSG de SIGEA.')
param nsgId string

@description('Crear IP pública estática para administración restringida.')
param enablePublicIp bool = true

@description('Publisher de la imagen del sistema operativo/SQL.')
param imagePublisher string = 'MicrosoftSQLServer'

@description('Offer de la imagen del sistema operativo/SQL.')
param imageOffer string = 'sql2022-ws2022'

@description('SKU de la imagen del sistema operativo/SQL.')
param imageSku string = 'sqldev-gen2'

@description('Versión de la imagen del sistema operativo/SQL.')
param imageVersion string = '16.0.260610'

@description('SKU del disco de sistema operativo.')
@allowed([
  'StandardSSD_LRS'
  'Premium_LRS'
])
param osDiskSku string = 'StandardSSD_LRS'

@description('Tamaño en GiB del disco de sistema operativo.')
param osDiskSizeGb int = 128

@description('Nombre del disco administrado persistente para datos de SQL Server.')
param dataDiskName string

@description('SKU del disco de datos persistente.')
@allowed([
  'StandardSSD_LRS'
  'Premium_LRS'
])
param dataDiskSku string = 'StandardSSD_LRS'

@description('Tamaño en GiB del disco de datos persistente.')
param dataDiskSizeGb int = 128

@description('Nombre del usuario administrador local.')
param adminUsername string

@description('Contraseña del usuario administrador local.')
@secure()
param adminPassword string

@description('Tags aplicados a los recursos de cómputo, disco y red de SIGEA.')
param tags object = {}

resource pip 'Microsoft.Network/publicIPAddresses@2023-11-01' = if (enablePublicIp) {
  name: 'pip-${vmName}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: 'sigea-vm-${take(uniqueString(resourceGroup().id, vmName), 8)}'
    }
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'nic-${vmName}'
  location: location
  tags: tags
  properties: {
    networkSecurityGroup: {
      id: nsgId
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
          publicIPAddress: enablePublicIp ? {
            id: pip!.id
          } : null
        }
      }
    ]
  }
}

resource sqlDataDisk 'Microsoft.Compute/disks@2023-10-02' = {
  name: dataDiskName
  location: location
  tags: union(tags, {
    dataRole: 'sigea-sql-persistent-data'
  })
  sku: {
    name: dataDiskSku
  }
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: dataDiskSizeGb
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: vmName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: take(replace(vmName, '-', ''), 15)
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
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        name: 'osdisk-${vmName}'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        deleteOption: 'Detach'
        diskSizeGB: osDiskSizeGb
        managedDisk: {
          storageAccountType: osDiskSku
        }
      }
      dataDisks: [
        {
          lun: 0
          name: sqlDataDisk.name
          createOption: 'Attach'
          caching: 'ReadOnly'
          deleteOption: 'Detach'
          managedDisk: {
            id: sqlDataDisk.id
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
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

output vmId string = vm.id
output vmName string = vm.name
output privateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output publicIpAddress string = enablePublicIp ? pip!.properties.ipAddress : ''
output publicIpFqdn string = enablePublicIp ? pip!.properties.dnsSettings.fqdn : ''
output dataDiskId string = sqlDataDisk.id
output principalId string = vm.identity.principalId
