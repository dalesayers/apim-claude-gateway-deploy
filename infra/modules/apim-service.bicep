targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('API Management service name.')
param apimName string

@description('Publisher email shown in APIM.')
param publisherEmail string

@description('Publisher name shown in APIM.')
param publisherName string

@description('Tags applied to the APIM service.')
param tags object = {}

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
	name: apimName
	location: location
	tags: tags
	identity: {
		type: 'SystemAssigned'
	}
	sku: {
		name: 'Developer'
		capacity: 1
	}
	properties: {
		publisherEmail: publisherEmail
		publisherName: publisherName
	}
}

output apimName string = apim.name
output gatewayUrl string = apim.properties.gatewayUrl
output principalId string = apim.identity.principalId
output resourceId string = apim.id
