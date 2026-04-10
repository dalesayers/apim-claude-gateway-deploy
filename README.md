# Azure APIM Claude Gateway

Customer-deployable Azure API Management gateway package for a Claude-compatible endpoint backed by the customer's own Azure AI Foundry deployment.

## Intended Use

This repository is designed for customer platform teams that want to deploy a controlled Claude-compatible gateway on Azure using Bicep and Azure CLI.

The package intentionally ships with:

- fixed APIM product names and token policies
- a minimal sample APIM subscription set for onboarding
- tested APIM policy XML for authentication, rate limiting, observability, and Anthropic-compatible response headers

The package intentionally does not ship with:

- a shared backend model deployment
- a mock backend path in the repo
- customer-specific secrets or parameter values

## What deploys

- Log Analytics workspace
- Application Insights component linked to the workspace
- API Management Developer tier with system-assigned managed identity
- APIM logger and diagnostics wired to Application Insights and Log Analytics
- Claude gateway API at `POST /claude/v1/messages`
- Three default products with fixed token and quota policies:
  - `claude-enterprise`
  - `claude-standard`
  - `claude-restricted`
- Sample APIM subscriptions for customer onboarding and validation

Default sample subscriptions:

- `sample-enterprise-prod`
- `sample-standard-prod`
- `sample-restricted-prod`

The template creates sample APIM subscriptions so a customer can onboard and validate against their own Azure AI Foundry backend without hand-creating test subscriptions first.

## Required Customer Inputs

Before deployment, the customer must provide:

- Azure subscription ID
- Azure region
- resource group name
- APIM name
- Application Insights name
- Log Analytics workspace name
- publisher name and email
- their own Claude-capable Azure AI Foundry backend URL

The example parameter file includes a placeholder for `foundryBackendUrl`. It must be replaced before deployment.

## Quickstart

1. Copy `main.customer.example.bicepparam` to `main.customer.bicepparam`.
2. Fill in the environment-specific values.
3. Replace `foundryBackendUrl` with the customer's own Claude-capable Azure AI Foundry endpoint.
4. Do not leave the sample placeholder URL in place.
5. Run:

```powershell
.\deploy-standard.ps1 -SubscriptionId "<subscription-id>" -ParametersFile ".\main.customer.bicepparam"
```

6. Grant the APIM managed identity `Cognitive Services User` on the target Azure AI Foundry resource.
7. Use one of the created APIM subscriptions to validate `POST /claude/v1/messages` through the APIM gateway.

## Handoff Files

Primary deployment and handoff files:

- `main.bicep`
- `main.customer.example.bicepparam`
- `deploy-standard.ps1`
- `docs/customer/deployment.md`
- `docs/customer/validation.md`
- `docs/customer/troubleshooting.md`

Repository-only support files:

- `.github/workflows/bicep-whatif.yml`
- `.github/workflows/bicep-deploy.yml`
- `docs/internal/runbook.md`

## Automation

The repo includes GitHub Actions workflows under `.github/workflows`:

- `bicep-whatif.yml`: manual or pull request `what-if`
- `bicep-deploy.yml`: manual deployment using the same wrapper script

Both workflows expect these repository or environment secrets:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

## Customer Validation

This repo does not include a mock backend path. Customers must provide their own Azure AI Foundry Claude backend URL and validate against their own deployment using the created APIM products, subscriptions, and policies.

## Files Not Committed

The following files are intentionally ignored because they are local or generated artifacts:

- `main.customer.bicepparam`
- `main.json`

## Repository Governance

- `main` should stay protected and receive changes through pull requests.
- Customer-specific parameter values should never be committed.
- Workflow changes should be reviewed carefully because they control deployment behavior.

See `CONTRIBUTING.md` for the expected change process.

## Layout

- `main.bicep`: deployment entry point
- `infra/modules`: modular resource definitions
- `infra/policies`: APIM policy XML loaded by Bicep
- `docs/customer`: customer-facing deployment and validation notes
- `docs/internal`: operator runbook notes