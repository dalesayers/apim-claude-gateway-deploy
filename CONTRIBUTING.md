# Contributing

## Scope

This repository is a customer deployment package for an Azure API Management Claude gateway backed by Azure AI Foundry. Changes should stay focused on deployment reliability, policy correctness, customer handoff clarity, and documentation accuracy.

## Expected Workflow

1. Create a branch from `main`.
2. Make focused changes.
3. Validate the package locally before opening a pull request.
4. Open a pull request into `main`.
5. Merge only after review.

## Local Validation

Recommended checks before merging:

```powershell
az bicep build --file .\main.bicep
.\deploy-standard.ps1 -SubscriptionId "<subscription-id>" -ParametersFile .\main.customer.bicepparam -ResourceGroupName "<resource-group>" -Location "<location>" -WhatIfOnly -Force
```

## Guardrails

- Do not commit customer secrets.
- Do not commit `main.customer.bicepparam`.
- Do not commit generated `main.json` output unless there is a specific reason to version compiled ARM.
- Keep the package live-only; do not reintroduce mock backend code into the deployment repo.
- Keep APIM product policies and API policy behavior aligned with the validated customer deployment path.

## Documentation

If you change deployment behavior, also update the relevant files under `docs/customer` and `docs/internal`.

## Pull Request Guidance

- Keep pull requests small and easy to review.
- Call out any policy behavior changes explicitly.
- Call out any parameter, naming, quota, or workflow changes explicitly.
