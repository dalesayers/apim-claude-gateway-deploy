# Azure APIM Claude Gateway
## Standard Mode Deployment Guide

**Purpose:** Define the recommended customer deployment process for a private GitHub repo using Azure CLI and Bicep, with the minimum required inputs and no mock backend path.

**Audience:** Customer platform teams deploying the gateway against their own Azure API Management and Azure AI Foundry Claude environment.

---

## Standard Mode Principles

Standard mode is intentionally conservative. The customer is prompted only for the values required to deploy the gateway into their environment.

Standard mode does **not** prompt for:

- product names
- subscription display names
- token-per-minute limits
- monthly quotas
- custom policy layout

Those values should ship as supported defaults in the repo. This keeps the deployment path simple and reduces the chance of policy drift or broken deployments.

The repo can ship a small default APIM subscription set so customers have a ready-to-test package immediately after deployment.

---

## Customer Inputs in Standard Mode

The customer should provide only these values:

| Input | Required | Example |
|---|---|---|
| Azure subscription ID | Yes | `00000000-0000-0000-0000-000000000000` |
| Azure location | Yes | `eastus2` |
| Resource group name | Yes | `rg-ai-gateway-sample-prod` |
| Environment name | Yes | `sample-prod` |
| APIM name | Yes | `apim-sample-claude-gateway` |
| Application Insights name | Yes | `appi-sample-claude-gateway` |
| Log Analytics name | Yes | `law-sample-claude-gateway` |
| Publisher email | Yes | `platformops@example.com` |
| Publisher name | Yes | `Sample Customer` |
| Foundry backend URL | Yes | `https://<your-foundry-resource>.services.ai.azure.com/anthropic` |
| Model name | Usually | `claude-sonnet-4-6` |

---

## Values That Should Stay as Defaults

These should remain fixed in the repo unless the customer explicitly asks for advanced customization:

| Setting | Recommended Default |
|---|---|
| Enterprise product name | `claude-enterprise` |
| Standard product name | `claude-standard` |
| Restricted product name | `claude-restricted` |
| Enterprise sample subscription | `sample-enterprise-prod` |
| Standard sample subscription | `sample-standard-prod` |
| Restricted sample subscription | `sample-restricted-prod` |
| Enterprise TPM | `50000` |
| Standard TPM | `10000` |
| Restricted TPM | `2000` |
| Enterprise monthly quota | `5000000` |
| Standard monthly quota | `500000` |
| Restricted monthly quota | `100000` |

If customers need to change those values later, expose them through an advanced parameter file rather than the primary onboarding flow.

---

## Repo Flow for Standard Mode

The expected repo flow is:

1. Customer clones the private repo.
2. Customer copies `main.customer.example.bicepparam` to `main.customer.bicepparam`.
3. Customer fills in the environment-specific values.
4. Customer replaces `foundryBackendUrl` with their own Claude-capable Azure AI Foundry endpoint.
5. Customer runs `deploy-standard.ps1`.
6. Customer grants APIM managed identity access to Azure AI Foundry.
7. Customer validates the gateway with one of the shipped sample APIM subscriptions.
8. Customer optionally replaces the sample subscription set with application-specific subscriptions later.

---

## Example Parameter File

Reference file:

`main.customer.example.bicepparam`

Recommended customer copy:

```text
main.customer.bicepparam
```

Example values:

```bicep
using './main.bicep'

// Replace with the customer's own Claude-capable Azure AI Foundry endpoint.
param environmentName = 'sample-prod'
param location = 'eastus2'
param resourceGroupName = 'rg-ai-gateway-sample-prod'
param apimName = 'apim-sample-claude-gateway'
param appInsightsName = 'appi-sample-claude-gateway'
param logAnalyticsName = 'law-sample-claude-gateway'
param publisherEmail = 'platformops@example.com'
param publisherName = 'Sample Customer'
param foundryBackendUrl = 'https://replace-with-your-foundry-resource.services.ai.azure.com/anthropic'
param modelName = 'claude-sonnet-4-6'
param tags = {
  Environment: 'prod'
  Owner: 'Sample Customer'
  Workload: 'ClaudeGateway'
}
```

Do not leave the placeholder URL in place. The deployment is intended to target the customer's own Claude-capable Azure AI Foundry backend.

---

## Example Deployment Commands

### Option 1: Use the wrapper script

```powershell
.\deploy-standard.ps1 \
  -SubscriptionId "<subscription-id>" \
  -ParametersFile ".\main.customer.bicepparam"
```

### Option 2: Use Azure CLI directly

```powershell
az login
az account set --subscription "<subscription-id>"
az group create --name "rg-ai-gateway-sample-prod" --location "eastus2"
az deployment group what-if --resource-group "rg-ai-gateway-sample-prod" --parameters ".\main.customer.bicepparam"
az deployment group create --resource-group "rg-ai-gateway-sample-prod" --parameters ".\main.customer.bicepparam"
```

---

## Post-Deployment Requirement

After deployment, the customer must assign the APIM managed identity the `Cognitive Services User` role on the Azure AI Foundry resource.

Example:

```powershell
$apimPrincipalId = az apim show \
  --name "apim-sample-claude-gateway" \
  --resource-group "rg-ai-gateway-sample-prod" \
  --query identity.principalId -o tsv

az role assignment create \
  --assignee $apimPrincipalId \
  --role "Cognitive Services User" \
  --scope "/subscriptions/<sub-id>/resourceGroups/<foundry-rg>/providers/Microsoft.CognitiveServices/accounts/<foundry-name>"
```

---

## Recommendation on Prompting

For this repo, standard mode should prompt only for the environment values listed above.

That is the right amount of prompting.

One of those required environment values is the customer's own Foundry backend URL. The repo should never imply that a shared or packaged backend is included.

Prompting for product names, APIM subscription naming, token limits, and monthly quotas during initial customer onboarding is too much information for most deployments. It is better handled later as an advanced customization option.

For the default package, ship exactly three sample subscriptions aligned to the three product tiers:

- `sample-enterprise-prod`
- `sample-standard-prod`
- `sample-restricted-prod`

---

## Recommendation for the Private Repo

The current live-only repo layout is:

- `main.bicep`
- `infra/modules/*`
- `infra/policies/*`
- `main.customer.example.bicepparam`
- `deploy-standard.ps1`
- `README.md` with a 5-minute quickstart
- `docs/customer/deployment.md`
- `docs/customer/validation.md`
- `docs/customer/troubleshooting.md`
- `docs/internal/runbook.md`

That gives the customer one supported path while still keeping room for future advanced mode.

The template should deploy products, policies, and a minimal three-subscription sample set. Customers can rotate keys or replace the sample subscriptions after onboarding.

---

*Last updated: April 9, 2026*
