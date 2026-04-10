targetScope = 'resourceGroup'

@description('Environment name used for naming and tagging.')
param environmentName string

@description('Primary Azure region for deployment.')
param location string

@description('Resource group name for the deployment target.')
param resourceGroupName string

@description('Azure API Management service name.')
param apimName string

@description('Application Insights resource name.')
param appInsightsName string

@description('Log Analytics workspace name.')
param logAnalyticsName string

@description('Publisher email shown on the APIM instance.')
param publisherEmail string

@description('Publisher name shown on the APIM instance.')
param publisherName string

@description('Claude Foundry backend base URL, for example https://sample-foundry.services.ai.azure.com/anthropic.')
param foundryBackendUrl string

@description('Claude deployment or model name expected by the gateway policy.')
param modelName string = 'claude-sonnet-4-6'

@description('When true, create sample APIM subscriptions for customer testing and onboarding.')
param createApimSubscriptions bool = true

@description('Sample APIM subscriptions created by the template. Scope must be /products/{productId}.')
param apimSubscriptions array = [
	{
		name: 'sample-enterprise-prod'
		displayName: 'Sample Enterprise Subscription'
		scope: '/products/claude-enterprise'
	}
	{
		name: 'sample-standard-prod'
		displayName: 'Sample Standard Subscription'
		scope: '/products/claude-standard'
	}
	{
		name: 'sample-restricted-prod'
		displayName: 'Sample Restricted Subscription'
		scope: '/products/claude-restricted'
	}
]

@description('Tags applied to deployed resources.')
param tags object = {}

var normalizedEnvironment = toLower(replace(environmentName, '-', ''))

module monitoring './infra/modules/monitoring.bicep' = {
	name: 'monitoring-${normalizedEnvironment}'
	params: {
		location: location
		logAnalyticsName: logAnalyticsName
		appInsightsName: appInsightsName
		tags: union(tags, {
			Environment: environmentName
			Component: 'Monitoring'
		})
	}
}

module apim './infra/modules/apim-service.bicep' = {
	name: 'apim-${normalizedEnvironment}'
	params: {
		location: location
		apimName: apimName
		publisherEmail: publisherEmail
		publisherName: publisherName
		tags: union(tags, {
			Environment: environmentName
			Component: 'Gateway'
		})
	}
}

module observability './infra/modules/apim-observability.bicep' = {
	name: 'apim-observability-${normalizedEnvironment}'
	params: {
		apimName: apimName
		appInsightsResourceId: monitoring.outputs.appInsightsResourceId
		appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
		logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
	}
}

module gateway './infra/modules/apim-gateway.bicep' = {
	name: 'apim-gateway-${normalizedEnvironment}'
	params: {
		apimName: apimName
		foundryBackendUrl: foundryBackendUrl
		modelName: modelName
		createApimSubscriptions: createApimSubscriptions
		apimSubscriptions: apimSubscriptions
	}
}

output deploymentMode string = 'live-only'
output normalizedEnvironmentName string = normalizedEnvironment
output resourceGroupNameOut string = resourceGroupName
output apimServiceName string = apim.outputs.apimName
output apimGatewayUrl string = apim.outputs.gatewayUrl
output apimPrincipalId string = apim.outputs.principalId
output foundryBackend string = foundryBackendUrl
output model string = modelName
output logAnalyticsWorkspaceId string = monitoring.outputs.logAnalyticsWorkspaceId
output appInsightsResourceId string = monitoring.outputs.appInsightsResourceId
output apiName string = gateway.outputs.apiName
output productNames array = gateway.outputs.productNames
output apimSubscriptionNames array = gateway.outputs.subscriptionNames
output nextStep string = 'Assign the APIM managed identity the Cognitive Services User role on the target Azure AI Foundry resource before sending live traffic, then use one of the created APIM subscriptions to validate POST /claude/v1/messages.'
