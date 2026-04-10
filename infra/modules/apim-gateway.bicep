targetScope = 'resourceGroup'

@description('API Management service name.')
param apimName string

@description('Claude Foundry backend base URL, for example https://sample-foundry.services.ai.azure.com/anthropic.')
param foundryBackendUrl string

@description('Claude deployment or model name expected by the gateway policy.')
param modelName string

@description('When true, create sample APIM subscriptions for customer testing and onboarding.')
param createApimSubscriptions bool = true

@description('APIM subscriptions created by the template. Scope must be /products/{productId}.')
param apimSubscriptions array = []

var apiId = 'claude-foundry-gateway'
var operationId = 'messages'
var enterpriseProductId = 'claude-enterprise'
var standardProductId = 'claude-standard'
var restrictedProductId = 'claude-restricted'

var enterprisePolicyXml = loadTextContent('../policies/product-enterprise.xml')
var standardPolicyXml = loadTextContent('../policies/product-standard.xml')
var restrictedPolicyXml = loadTextContent('../policies/product-restricted.xml')
var operationPolicyXml = loadTextContent('../policies/operation-base.xml')
var apiPolicyXml = replace(loadTextContent('../policies/api-policy.xml'), '__MODEL_NAME__', modelName)
var allSubscriptionNames = [for subscription in apimSubscriptions: subscription.name]
var subscriptionNames = createApimSubscriptions ? allSubscriptionNames : []

var products = [
	{
		id: enterpriseProductId
		displayName: enterpriseProductId
		description: 'Enterprise tier - 50K TPM, 5M tokens/month'
		policy: enterprisePolicyXml
	}
	{
		id: standardProductId
		displayName: standardProductId
		description: 'Standard tier - 10K TPM, 500K tokens/month'
		policy: standardPolicyXml
	}
	{
		id: restrictedProductId
		displayName: restrictedProductId
		description: 'Restricted tier - 2K TPM, 100K tokens/month'
		policy: restrictedPolicyXml
	}
]

resource apim 'Microsoft.ApiManagement/service@2022-08-01' existing = {
	name: apimName
}

resource api 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
	parent: apim
	name: apiId
	properties: {
		displayName: 'Claude Foundry Gateway'
		subscriptionRequired: true
		path: 'claude'
		protocols: [
			'https'
		]
		serviceUrl: foundryBackendUrl
	}
}

resource operation 'Microsoft.ApiManagement/service/apis/operations@2022-08-01' = {
	parent: api
	name: operationId
	properties: {
		displayName: 'Messages'
		method: 'POST'
		urlTemplate: '/v1/messages'
		description: 'Anthropic-compatible messages endpoint'
		templateParameters: []
		responses: []
	}
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2022-08-01' = {
	parent: api
	name: 'policy'
	properties: {
		format: 'rawxml'
		value: apiPolicyXml
	}
}

resource operationPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2022-08-01' = {
	parent: operation
	name: 'policy'
	properties: {
		format: 'rawxml'
		value: operationPolicyXml
	}
}

resource productResources 'Microsoft.ApiManagement/service/products@2022-08-01' = [for product in products: {
	parent: apim
	name: product.id
	properties: {
		displayName: product.displayName
		description: product.description
		subscriptionRequired: true
		approvalRequired: false
		state: 'published'
	}
}]

resource productApis 'Microsoft.ApiManagement/service/products/apis@2022-08-01' = [for (product, index) in products: {
	parent: productResources[index]
	name: api.name
}]

resource productPolicies 'Microsoft.ApiManagement/service/products/policies@2022-08-01' = [for (product, index) in products: {
	parent: productResources[index]
	name: 'policy'
	properties: {
		format: 'rawxml'
		value: product.policy
	}
}]

resource subscriptions 'Microsoft.ApiManagement/service/subscriptions@2023-05-01-preview' = [for subscription in apimSubscriptions: if (createApimSubscriptions) {
	parent: apim
	name: subscription.name
	properties: {
		displayName: subscription.displayName
		scope: subscription.scope
		state: 'active'
		allowTracing: false
	}
}]

output apiName string = api.name
output operationName string = operation.name
output productNames array = [for product in products: product.id]
output subscriptionNames array = subscriptionNames
