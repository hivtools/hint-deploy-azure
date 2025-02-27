targetScope = 'resourceGroup'

// ------------------
//    PARAMETERS
// ------------------

@description('The location where the resources will be created.')
param location string = resourceGroup().location

@description('Name of existing container apps environment')
param containerAppsEnvironmentName string

@description('Workload profile for hint and hintr')
param workloadProfile string

// ------------------
//    EXISTING RESOURCES
// ------------------

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' existing = {
  name: containerAppsEnvironmentName
}

// ------------------
// HINTR
// ------------------

@description('Name of uploads volume')
param uploadsVolume string = 'uploads-volume'

@description('Name of results volume')
param resultsVolume string = 'results-volume'

resource hintr 'Microsoft.App/containerApps@2024-10-02-preview' = {
  name: 'nm-hintr'
  location: location
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8888
        allowInsecure: false
      }
    }
    template: {
      containers: [
        {
          name: 'hintr'
          image: 'ghcr.io/mrc-ide/hintr:add-health-check'
          command: [
            '/usr/local/bin/hintr_api'
          ]
          args: [
            '--workers'
            '0'
            '--results-dir'
            '/results'
            '--inputs-dir'
            '/uploads'
            '--port'
            '8888'
            '--health-check-interval'
            // Azure closes idle tcp connection after 4 mins, so make interval
            // slighty less than this
            '210'
          ]
          env: [
            {
              name: 'REDIS_URL'
              value: 'redis://nm-redis:6379'
            }
          ]
          resources: {
            cpu: json('1')
            memory: '2Gi'
          }
          volumeMounts: [
            {
              volumeName: uploadsVolume
              mountPath: '/uploads'
            }
            {
              volumeName: resultsVolume
              mountPath: '/results'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 2
      }
      volumes: [
        {
          name: uploadsVolume
          storageType: 'AzureFile'
          storageName: 'uploads-mount'
        }
        {
          name: resultsVolume
          storageType: 'AzureFile'
          storageName: 'results-mount'
        }
      ]
    }
    workloadProfileName: workloadProfile
  }
}

// ------------------
// HINTR workers
// ------------------

resource hintrWorker 'Microsoft.App/containerApps@2024-10-02-preview' = {
  name: 'nm-hintr-worker'
  location: location
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    template: {
      containers: [
        {
          name: 'hintr-worker'
          image: 'ghcr.io/mrc-ide/hintr-worker:add-health-check'
          env: [
            {
              name: 'REDIS_URL'
              value: 'redis://nm-redis:6379'
            }
          ]
          resources: {
            cpu: json('1')
            memory: '16Gi'
          }
          volumeMounts: [
            {
              volumeName: uploadsVolume
              mountPath: '/uploads'
            }
            {
              volumeName: resultsVolume
              mountPath: '/results'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
      volumes: [
        {
          name: uploadsVolume
          storageType: 'AzureFile'
          storageName: 'uploads-mount'
        }
        {
          name: resultsVolume
          storageType: 'AzureFile'
          storageName: 'results-mount'
        }
      ]
    }
    workloadProfileName: workloadProfile
  }
  dependsOn: [
    hintr
  ]
}
