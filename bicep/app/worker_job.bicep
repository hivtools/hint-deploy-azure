// ------------------
//    PARAMETERS
// ------------------

@description('The location where the resources will be created.')
param location string = resourceGroup().location

@description('Name of existing container apps environment')
param containerAppsEnvironmentName string

@description('String for connecting to Azure managed redis')
param redisConnectionString string

@description('String for connecting to Azure managed redis')
param redisConnectionStringNoProtocol string

@description('Worker image name with registry and tag')
param hintrWorkerImage string

@description('Worker configuration string')
param workerConfigString string
var workerConfig object = json(workerConfigString)

@description('Key to access redis')
@secure()
param redisKey string

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

// ------------------
// HINTR workers
// ------------------

var workers = [for worker in items(workerConfig.workers): {
  name: worker.key
  cpu: worker.value.deployment_options.resources.cpu
  memory: worker.value.deployment_options.resources.memory
  workloadProfile: worker.value.deployment_options.workload_profile
  queue: worker.value.queue[0]
  timeout: worker.value.deployment_options.timeout
}]

output workersOut object[] = workers

resource hintrWorkerJobs 'Microsoft.App/jobs@2025-02-02-preview' = [for worker in workers: {
  name: 'nm-hintr-${worker.name}-job'
  location: location
  properties: {
    environmentId: containerAppsEnvironment.id
    template: {
      containers: [
        {
          name: 'hintr-${worker.name}-job'
          image: hintrWorkerImage
          command: [
            '/usr/local/bin/hintr_worker_single_job'
          ]
          args: [
            '--worker-config=${worker.name}'
          ]
          env: [
            {
              name: 'REDIS_URL'
              value: redisConnectionString
            }
            {
              name: 'HINTR_WORKER_CONFIG'
              value: workerConfigString
            }
          ]
          resources: {
            cpu: worker.cpu
            memory: worker.memory
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
          storageType: 'AzureFile'
          storageName: uploadsMount
        }
        {
          name: resultsVolume
          storageType: 'AzureFile'
          storageName: resultsMount
        }
      ]
    }
    configuration: {
      triggerType: 'Event'
      secrets: [
        {
          name: 'redis-key'
          value: redisKey
        }
      ]
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
              type: 'redis'
              metadata: {
                address: redisConnectionStringNoProtocol
                listName: 'hintr:queue:${worker.queue}'
                listLength: '1'
              }
              auth: [
                {
                  secretRef: 'redis-key'
                  triggerParameter: 'password'
                }
              ]
            }
          ]
        }
      }
      replicaTimeout: worker.timeout
      replicaRetryLimit: 1
    }
    workloadProfileName: worker.workloadProfile
  }
}]
