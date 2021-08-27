targetScope = 'resourceGroup'

@description('Bastion Host Name.')
param name string = '${resourceGroup().name}-bastion'

@description('Bastion Location.')
param location string = resourceGroup().location

@description('Enable lock to prevent accidental deletion')
param enableDeleteLock bool = false

@description('Tags.')
param tags object = {}

@description('Bastion Host Subnet.')
param subnetId string

resource publicIP 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: '${name}-ip'
  location: location
  tags: tags
  properties: {
    publicIPAllocationMethod: 'Static'
  }
  sku: {
    name: 'Standard'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2021-02-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          publicIPAddress: {
            id: publicIP.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource publicIPLock 'Microsoft.Authorization/locks@2016-09-01' = if (enableDeleteLock) {
  scope: publicIP

  name: '${publicIP.name}-lock'
  properties: {
    level: 'CanNotDelete'
  }
}

resource bastionLock 'Microsoft.Authorization/locks@2016-09-01' = if (enableDeleteLock) {
  scope: bastion

  name: '${bastion.name}-lock'
  properties: {
    level: 'CanNotDelete'
  }
}
