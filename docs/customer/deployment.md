# Customer Deployment

Use `main.customer.bicepparam` and `deploy-standard.ps1` for the supported deployment flow.

## Steps

1. Sign in with Azure CLI.
2. Copy `main.customer.example.bicepparam` to `main.customer.bicepparam`.
3. Replace `foundryBackendUrl` with the customer's own Claude-capable Azure AI Foundry endpoint.
4. Do not leave the sample placeholder URL in place.
5. Run the wrapper script.
6. Assign `Cognitive Services User` to the APIM managed identity on the target Foundry resource.
7. Test the gateway using one of the sample APIM subscriptions created by the template:
	- `sample-enterprise-prod`
	- `sample-standard-prod`
	- `sample-restricted-prod`

## Notes

- The template creates products, sample APIM subscriptions, and the tested policies by default.
- The shipped sample subscriptions are tier-aligned and intentionally neutral:
	- `sample-enterprise-prod`
	- `sample-standard-prod`
	- `sample-restricted-prod`
- Product names and token policies ship as repo defaults.
- The customer must supply their own real Claude-capable Azure AI Foundry backend URL; the example parameter file ships with a placeholder only.
- If you use GitHub Actions, the workflows in `.github/workflows` call the same `deploy-standard.ps1` script used locally.