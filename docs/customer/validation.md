# Customer Validation

After deployment:

1. Confirm the APIM gateway URL from the deployment outputs.
2. Create or list an APIM subscription key for a caller.
3. Send a Claude-compatible request to `POST /claude/v1/messages`.
4. Confirm these response headers are present:
   - `x-gateway`
   - `x-product-tier`
   - `x-token-usage`
   - `anthropic-ratelimit-tokens-limit`
   - `anthropic-ratelimit-tokens-remaining`

Use a real Claude deployment behind the configured Foundry backend URL.