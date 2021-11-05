// Usage: az deployment group create --resource-group jmn-dev-wa --template-file main.bicep --location westeurope --parameters environment=dev
param environment string = 'dev'
param projectName string = 'jmn'
param location string = 'westeurope'
param dnsZone string = 'segeswebsites.net'
param webAppName string = '${projectName}-${environment}-wa'

targetScope = 'resourceGroup'

// App service plan
resource asp 'Microsoft.Web/serverfarms@2020-12-01' = {
  name: '${projectName}-${environment}-asp'
  location:location
    sku:{
    name:'S1'
    tier:'Standard'
  }
}

// Web App
resource webApp 'Microsoft.Web/sites@2020-06-01' = {
  name: webAppName
  dependsOn: [
    asp
  ]
  location: location
  properties: {
    serverFarmId: asp.id
    httpsOnly:true
  }
}

// Zone
resource existingDnsZone 'Microsoft.Network/dnsZones@2018-05-01' existing = {
  name: dnsZone
}

// CName Record
resource cnameRecord 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  name: '${webAppName}.${dnsZone}'
  parent: existingDnsZone
  dependsOn: [
    existingDnsZone
  ]
  properties: {
    TTL: 3600
    CNAMERecord: {
      cname:  webApp.properties.defaultHostName
    }
  }
}

// Certificate
resource certificates 'Microsoft.Web/certificates@2021-02-01' =  {  
  name: dnsZone
  location: location
  dependsOn: [
    cnameRecord
  ]
  properties: {
    canonicalName: '${webAppName}.${dnsZone}'
    serverFarmId: asp.id
  }
}
// ERROR: \"Message\": \"Properties.CanonicalName is invalid.  Certificate creation requires hostname jmn-dev-wa.segeswebsites.net added to an App Service in the serverFarm...

// Host name binding
resource extDNSBinding 'Microsoft.Web/sites/hostNameBindings@2021-02-01' = {
  name: '${webAppName}.${dnsZone}'
  parent: webApp
  dependsOn: [
    certificates
  ]
  properties: {
    siteName: webApp.name
    hostNameType: 'Verified'
    sslState: 'SniEnabled'
    customHostNameDnsRecordType: 'CName'
    thumbprint: certificates.properties.thumbprint
  }
}


