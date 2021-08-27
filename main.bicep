targetScope = 'subscription'

var enableLock = false
param tags object = {
  environment: 'development'
}
param prefix string = 'iac'

// Resource Group Parameters
param groupName string = '${prefix}-bicep'
param location string = 'centralus'

// JumpBox Parameters
@secure()
param adminPassword string

// Cluster Parameters
param aksVersion string = '1.20.7'
param adminPublicKey string
param adminGroupObjectIDs array = []

// Create Resource Group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: groupName
  location: location
  tags: tags
}

// Apply Resource Group Lock
module applyLock 'modules/apply_lock.bicep' = if (enableLock) {
  scope: resourceGroup
  name: 'applyLock'
}

// Create a Managed User Identity for the Cluster
module clusterIdentity 'modules/user_identity.bicep' = {
  name: 'user_identity_cluster'
  scope: resourceGroup
  params: {
    name: '${groupName}-cluster-identity'
  }
}

// Create a Managed User Identity for the Pods
module podIdentity 'modules/user_identity.bicep' = {
  name: 'user_identity_pod'
  scope: resourceGroup
  params: {
    name: '${groupName}-pod-identity'
  }
}

// Create Log Analytics Workspace
module logAnalytics 'modules/azure_log_analytics.bicep' = {
  name: 'log_analytics'
  scope: resourceGroup
  params: {
    sku: 'PerGB2018'
    retentionInDays: 30
  }
  // This dependency is only added to attempt to solve a timing issue.
  // Identities sometimes list as completed but can't be used yet.
  dependsOn: [
    clusterIdentity
    podIdentity
  ]
}

// Create Virtual Network
module vnet 'modules/azure_vnet.bicep' = {
  name: 'azure_vnet'
  scope: resourceGroup
  params: {
    principalId: clusterIdentity.outputs.principalId
    workspaceId: logAnalytics.outputs.Id
  }
  dependsOn: [
    clusterIdentity
    logAnalytics
  ]
}

// Create Firewall
module firewall 'modules/azure_firewall.bicep' = {
  name: 'azure_firewall'
  scope: resourceGroup
  params: {
    subnetId: vnet.outputs.egressSubnetId
  }
  dependsOn: [
    vnet
  ]
}

// Create Keyvault
module keyvault 'modules/azure_keyvault.bicep' = {
  name: 'azure_keyvault'
  scope: resourceGroup
  params: {
    principalId: podIdentity.outputs.principalId
    privateLinkSettings: {
      vnetId: vnet.outputs.vnetId
      subnetId: vnet.outputs.serviceSubnetId
    }
  }
  dependsOn: [
    vnet
  ]
}

// Create Storage Account
module storage 'modules/azure_storage.bicep' = {
  name: 'azure_storage'
  scope: resourceGroup
  params: {
    principalId: podIdentity.outputs.principalId
    privateLinkSettings: {
      vnetId: vnet.outputs.vnetId
      subnetId: vnet.outputs.serviceSubnetId
    }
  }
  dependsOn: [
    vnet
  ]
}

// Create Bastion Host
module bastion 'modules/bastion_host.bicep' = {
  name: 'bastion_host'
  scope: resourceGroup
  params: {
    subnetId: vnet.outputs.bastionSubnetId
  }
  dependsOn: [
    vnet
  ]
}

// Create JumpBox
module virtualmachine 'modules/virtual_machine.bicep' = {
  name: 'virtual_machine'
  scope: resourceGroup
  params: {
    workspaceId: logAnalytics.outputs.Id
    subnetId: vnet.outputs.serviceSubnetId
    adminPassword: adminPassword
  }
  dependsOn: [
    logAnalytics
    vnet
  ]
}

// Create Container Registry
module acr 'modules/azure_registry.bicep' = {
  name: 'container_registry'
  scope: resourceGroup
  params: {
    principalId: clusterIdentity.outputs.principalId
    privateLinkSettings: {
      vnetId: vnet.outputs.vnetId
      subnetId: vnet.outputs.serviceSubnetId
    }
  }
}

// Create Cluster
module cluster 'modules/aks_cluster.bicep' = {
  name: 'aks_cluster'
  scope: resourceGroup
  params: {
    identityId: clusterIdentity.outputs.resourceId
    workspaceId: logAnalytics.outputs.Id
    subnetId: vnet.outputs.clusterSubnetId
    podSubnetId: vnet.outputs.podSubnetId
    version: aksVersion
    adminPublicKey: adminPublicKey
    adminGroupObjectIDs: adminGroupObjectIDs
  }
  dependsOn: [
    clusterIdentity
    logAnalytics
    vnet
    firewall
  ]
}
