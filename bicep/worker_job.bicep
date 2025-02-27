targetScope = 'resourceGroup'

// ------------------
//    PARAMETERS
// ------------------


@description('The location where the resources will be created.')
param location string = resourceGroup().location

@description('Name of existing container apps environment')
param containerAppsEnvironmentName string

@description('Workload profile for workers')
param workloadProfile string

@description('URL (without scheme) proxy is deployed at')
param proxyUrl string

@description('String for connecting to Azure managed redis')
param redisConnectionString string

@description('Worker image name with registry and tag')
param hintrWorkerImage string

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
@description('Name of uploads mount')
param uploadsMount string = 'uploads-mount-r'

@description('Name of results volume')
param resultsVolume string = 'results-volume'
@description('Name of results mount')
param resultsMount string = 'uploads-mount-rw'

param azureCRUrl string
param azureCRUsername string
@secure()
param azureCRPassword string

// ------------------
// HINTR workers
// ------------------

resource hintrWorker 'Microsoft.App/jobs@2024-03-01' = {
  name: 'nm-hintr-worker-job'
  location: location
  properties: {
    environmentId: containerAppsEnvironment.id
    template: {
      containers: [
        {
          name: 'hintr-worker-job'
          image: hintrWorkerImage
          command: [
            '/usr/local/bin/hintr_worker_single_job'
          ]
          args: [
            '--fit-only'
          ]
          env: [
            {
              name: 'REDIS_URL'
              value: redisConnectionString
            }
          ]
          resources: {
            cpu: json('4')
            memory: '8Gi'
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
      volumes: [
        {
          name: uploadsVolume
          storageType: 'NfsAzureFile'
          storageName: uploadsMount
        }
        {
          name: resultsVolume
          storageType: 'NfsAzureFile'
          storageName: resultsMount
        }
      ]
    }
    configuration: {
      triggerType: 'Event'
      eventTriggerConfig: {
        parallelism: 10
        replicaCompletionCount: 1
        scale: {
          minExecutions: 0
          maxExecutions: 10
          pollingInterval: 5
          rules: [
            {
              name: 'job-queued-trigger'
              type: 'metrics-api'
              metadata: {
                url: 'https://${proxyUrl}/queue-length'
                targetValue: '1'
                valueLocation: 'length'
                method: 'GET'
              }
            }
          ]
        }
      }
      registries: [
        {
          passwordSecretRef: 'registry-password'
          server: azureCRUrl
          username: azureCRUsername
        }
      ]
      secrets: [
        {
          name: 'registry-password'
          value: azureCRPassword
        }
      ]
      replicaTimeout: 500
      replicaRetryLimit: 1
    }
    workloadProfileName: 'Consumption'
  }
}
