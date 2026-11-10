@description('Virtual Network Name')
param vnetName string
param location string = resourceGroup().location
param addressPrefix string = '172.18.0.0/16'

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  properties: { addressSpace: { addressPrefixes: [addressPrefix] } }
}
output vnetId string = vnet.id
