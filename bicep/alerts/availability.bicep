@description('The location where the resources will be created.')
param location string = resourceGroup().location

@description('The prefix to use for all resource names')
param prefix string

@description('URL to check is up, should return a 200')
param url string

@description('ID of the log analytics workspace that availability results are stored in')
param logAnalyticsWorkspaceId string

@description('Action group to notify when the site is down')
param actionGroupId string

// Standard tests are billed per execution ($0.0005 in Oct 2026), 3 locations
// every 5 mins is ~26k executions, ~$13 a month
var testLocations = [
  'us-va-ash-azr' // East US
  'emea-nl-ams-azr' // West Europe
  'emea-gb-db3-azr' // North Europe
]

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${prefix}-availability-insights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspaceId
  }
}

resource webTest 'Microsoft.Insights/webtests@2022-06-15' = {
  name: '${prefix}-naomi-availability'
  location: location
  // Links the test to app insights so it shows in the portal
  tags: {
    'hidden-link:${appInsights.id}': 'Resource'
  }
  properties: {
    SyntheticMonitorId: '${prefix}-naomi-availability'
    Name: 'Naomi availability'
    Kind: 'standard'
    Enabled: true
    Frequency: 300
    Timeout: 30
    RetryEnabled: true
    Locations: [for testLocation in testLocations: {
      Id: testLocation
    }]
    Request: {
      RequestUrl: url
      HttpVerb: 'GET'
      ParseDependentRequests: false
    }
    ValidationRules: {
      ExpectedHttpStatusCode: 200
      SSLCheck: true
      SSLCertRemainingLifetimeCheck: 14
    }
  }
}

resource availabilityAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${prefix}-naomi-down'
  location: 'global'
  properties: {
    description: '${url} is failing availability checks from 2 or more locations. This also fails if the SSL certificate expires within 14 days.\nAction: Check the nm-naomi web app in the portal (Diagnose and solve problems, recent deploys, AppServiceConsoleLogs). If only the SSL check is failing, renew the certificate.'
    severity: 0
    enabled: true
    scopes: [
      webTest.id
      appInsights.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.WebtestLocationAvailabilityCriteria'
      webTestId: webTest.id
      componentId: appInsights.id
      failedLocationCount: 2
    }
    autoMitigate: true
    actions: [
      {
        actionGroupId: actionGroupId
      }
    ]
  }
}
