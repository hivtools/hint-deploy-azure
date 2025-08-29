@description('Specifies the name of the App Configuration store.')
param configStoreName string = 'hint-app-config'

@description('Specifies the Azure location where the app configuration store should be created.')
param location string = resourceGroup().location

@description('Specifies the names of the key-value resources. The name is a combination of key and label with $ as delimiter. The label is optional.')
param keyValueNames array = [
  'worker-config'
]

@description('Specifies the values of the key-value resources. It\'s optional')
param keyValueValues array = [
  loadTextContent('../config/workers.json')
]

resource configStore 'Microsoft.AppConfiguration/configurationStores@2024-05-01' = {
  name: configStoreName
  location: location
  sku: {
    name: 'free'
  }
}

resource configStoreKeyValue 'Microsoft.AppConfiguration/configurationStores/keyValues@2024-05-01' = [for (item, i) in keyValueNames: {
  parent: configStore
  name: item
  properties: {
    value: keyValueValues[i]
    contentType: 'application/json'
  }
}]

output reference_key_value_value string = configStoreKeyValue[0].properties.value
output reference_key_value_object object = {
  name: configStoreKeyValue[0].name
  properties: configStoreKeyValue[0].properties
}

output configInfo object = {
  configStoreName: configStoreName
}
