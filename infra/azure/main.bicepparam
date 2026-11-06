using './main.bicep'

// Archivo de ejemplo sin secretos ni IPs privadas.
// Para desplegar, suministre adminPassword de forma segura (p.ej. variable de entorno o prompt)
// y, opcionalmente, presenterAllowedCidr con su IPv4 pública /32 verificada.

param location = 'mexicocentral'
param resourceGroupName = 'rg-legacy-apps-demo-mxc'
param vnetName = 'vnet-legacy-lab-mxc'
param sigeaSubnetName = 'snet-sigea'
param geperSubnetName = 'snet-geper'
param presenterAllowedCidr = ''
param enablePublicIp = true
param sigeaVmName = 'vm-sigea-win'
param sigeaVmSize = 'Standard_D4s_v5'
param sigeaImagePublisher = 'MicrosoftSQLServer'
param sigeaImageOffer = 'sql2022-ws2022'
param sigeaImageSku = 'sqldev-gen2'
param sigeaImageVersion = '16.0.260610'
param osDiskSku = 'StandardSSD_LRS'
param osDiskSizeGb = 128
param dataDiskSku = 'StandardSSD_LRS'
param dataDiskSizeGb = 128
param adminUsername = 'sigeaadmin'
param adminPassword = readEnvironmentVariable('SIGEA_VM_ADMIN_PASSWORD', '')
param enableKeyVault = true
param enableFrontDoor = true
