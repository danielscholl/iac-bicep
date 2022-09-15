targetScope = 'resourceGroup'

@description('Virtual Machine Name.')
param name string = '${resourceGroup().name}-vm'

@description('Virtual Machine Location.')
param location string = resourceGroup().location

@description('Enable lock to prevent accidental deletion')
param enableDeleteLock bool = false

@description('Tags.')
param tags object = {}

@description('Virtual Machine Administrator.')
param adminUser string = 'azureuser'

@description('Virtual Machine Password.')
@secure()
param adminPassword string

@description('Virtual Machine Subnet.')
param subnetId string

@description('Virtual Machine Inititalize Script.')
param cloudInit string = '''
#cloud-config
packages:
 - build-essential
 - procps
 - file
 - linuxbrew-wrapper
 - docker.io
runcmd:
 - curl -sL https://aka.ms/InstallAzureCLIDeb | bash
 - curl -s https://fluxcd.io/install.sh | bash
 - az aks install-cli
 - systemctl start docker
 - systemctl enable docker
 - wget -q https://get.helm.sh/helm-v3.2.2-linux-amd64.tar.gz -O helm-v3.2.2-linux-amd64.tar.gz
 - tar -zxvf helm-v3.2.2-linux-amd64.tar.gz -C /usr/local/bin --strip-components=1 linux-amd64/helm

final_message: "cloud init completed"
'''

@description('Log Workspace.')
param workspaceId string

resource nic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: '${name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2021-04-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1ms'
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    osProfile: {
      computerName: name
      adminUsername: adminUser
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
      customData: base64(cloudInit)
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}

resource lock 'Microsoft.Authorization/locks@2016-09-01' = if (enableDeleteLock) {
  scope: vm

  name: '${vm.name}-lock'
  properties: {
    level: 'CanNotDelete'
  }
}

resource omsAgentForLinux 'Microsoft.Compute/virtualMachines/extensions@2020-06-01' = {
  parent: vm
  name: 'omsAgentForLinux'
  location: location
  properties: {
    publisher: 'Microsoft.EnterpriseCloud.Monitoring'
    type: 'OmsAgentForLinux'
    typeHandlerVersion: '1.12'
    settings: {
      workspaceId: reference(workspaceId, '2020-03-01-preview').customerId
      stopOnMultipleConnections: false
    }
    protectedSettings: {
      workspaceKey: listKeys(workspaceId, '2020-03-01-preview').primarySharedKey
    }
  }
  dependsOn: [
    vm
  ]
}
