# Customer Troubleshooting

## 401 or 403 from Foundry

Confirm the APIM managed identity has `Cognitive Services User` on the target Foundry resource.

## 401 from APIM

Confirm the caller is sending a valid `Ocp-Apim-Subscription-Key` for an active APIM subscription.

## 429 from APIM

The caller exceeded the configured product token limit. Move the caller to a different product or adjust the product policy in the repo.

## Missing metrics

Confirm the APIM logger and diagnostics deployed successfully and that the Application Insights component is workspace-based.