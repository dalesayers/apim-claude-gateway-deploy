<#
LEGACY SCRIPT

This script is retained for historical and internal reference only.
Use deploy-standard.ps1 for the supported customer deployment path.
#>

param(
    [string]$ResourceGroup = 'rg-ai-gateway',
    [string]$Location = 'eastus2',
    [string]$ApimName = 'apim-claude-gateway',
    [string]$LogAnalyticsName = 'law-apim-claude-gateway',
    [string]$AppInsightsName = 'appi-apim-claude-gateway',
    [string]$PublisherEmail,
    [string]$PublisherName,
    [switch]$SkipValidation
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$env:AZURE_EXTENSION_DIR = Join-Path $env:TEMP 'azext-empty'
New-Item -ItemType Directory -Force -Path $env:AZURE_EXTENSION_DIR | Out-Null

function Invoke-Az {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    & az @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed: az $($Arguments -join ' ')"
    }
}

function Invoke-AzTsv {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $output = & az @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed: az $($Arguments -join ' ')"
    }

    return ($output | Out-String).Trim()
}

function Test-Az {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    & az @Arguments *>$null
    return $LASTEXITCODE -eq 0
}

function Invoke-AzRestPut {
    param(
        [Parameter(Mandatory)]
        [string]$Uri,
        [Parameter(Mandatory)]
        [object]$Body
    )

    $json = $Body | ConvertTo-Json -Depth 100 -Compress
  $tempFile = Join-Path $env:TEMP ("apim-rest-" + [guid]::NewGuid().ToString() + '.json')
  try {
    Set-Content -Path $tempFile -Value $json -Encoding utf8NoBOM -NoNewline
    Invoke-Az -Arguments @('rest', '--method', 'put', '--uri', $Uri, '--body', "@$tempFile", '--output', 'none')
  }
  finally {
    Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
  }
}

function Ensure-ApiProductLink {
    param(
        [Parameter(Mandatory)]
        [string]$ProductId,
        [Parameter(Mandatory)]
        [string]$ApiId,
        [Parameter(Mandatory)]
        [string]$ResourceGroup,
        [Parameter(Mandatory)]
        [string]$ApimName
    )

    if (-not (Test-Az -Arguments @('apim', 'product', 'api', 'check', '--resource-group', $ResourceGroup, '--service-name', $ApimName, '--product-id', $ProductId, '--api-id', $ApiId))) {
        Invoke-Az -Arguments @('apim', 'product', 'api', 'add', '--resource-group', $ResourceGroup, '--service-name', $ApimName, '--product-id', $ProductId, '--api-id', $ApiId, '--output', 'none')
    }
}

Invoke-Az -Arguments @('config', 'set', 'extension.use_dynamic_install=yes_without_prompt', 'extension.dynamic_install_allow_preview=true', 'core.only_show_errors=true', '--output', 'none')
Invoke-Az -Arguments @('extension', 'add', '--name', 'application-insights', '--allow-preview', 'true', '--output', 'none')

$account = Invoke-AzTsv -Arguments @('account', 'show', '--output', 'json') | ConvertFrom-Json
if (-not $PublisherEmail) {
    $PublisherEmail = $account.user.name
}
if (-not $PublisherName) {
    $PublisherName = if ($account.tenantDisplayName) { $account.tenantDisplayName } else { 'Contoso' }
}

$apiId = 'claude-foundry-gateway'
$apiDisplayName = 'Claude Foundry Gateway'
$operationId = 'messages'
$mockBackendUrl = 'https://mock.placeholder.invalid/anthropic'

$productPolicies = @{
    'claude-enterprise' = @'
<policies>
  <inbound>
    <base />
    <!--
      PRODUCT: claude-enterprise
      Limits: 50,000 tokens/min | 5,000,000 tokens/month
      counter-key is scoped to APIM Subscription ID so each
      subscriber gets their own independent counter.
    -->
    <llm-token-limit
      counter-key="@(context.Subscription.Id)"
      tokens-per-minute="50000"
      token-quota="5000000"
      token-quota-period="Monthly"
      estimate-prompt-tokens="true"
      remaining-tokens-header-name="x-remaining-tokens"
      remaining-tokens-variable-name="remainingTokens"
      remaining-quota-tokens-header-name="x-remaining-monthly"
      remaining-quota-tokens-variable-name="remainingQuotaTokens" />
  </inbound>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
'@
    'claude-standard' = @'
<policies>
  <inbound>
    <base />
    <!--
      PRODUCT: claude-standard
      Limits: 10,000 tokens/min | 500,000 tokens/month
    -->
    <llm-token-limit
      counter-key="@(context.Subscription.Id)"
      tokens-per-minute="10000"
      token-quota="500000"
      token-quota-period="Monthly"
      estimate-prompt-tokens="true"
      remaining-tokens-header-name="x-remaining-tokens"
      remaining-tokens-variable-name="remainingTokens"
      remaining-quota-tokens-header-name="x-remaining-monthly"
      remaining-quota-tokens-variable-name="remainingQuotaTokens" />
  </inbound>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
'@
    'claude-restricted' = @'
<policies>
  <inbound>
    <base />
    <!--
      PRODUCT: claude-restricted
      Limits: 2,000 tokens/min | 100,000 tokens/month
    -->
    <llm-token-limit
      counter-key="@(context.Subscription.Id)"
      tokens-per-minute="2000"
      token-quota="100000"
      token-quota-period="Monthly"
      estimate-prompt-tokens="true"
      remaining-tokens-header-name="x-remaining-tokens"
      remaining-tokens-variable-name="remainingTokens"
      remaining-quota-tokens-header-name="x-remaining-monthly"
      remaining-quota-tokens-variable-name="remainingQuotaTokens" />
  </inbound>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
'@
}

$apiPolicyXml = @'
<policies>
  <inbound>
    <base />

    <!--
      ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
      SECTION A: AUTHENTICATION
      Use Managed Identity to authenticate to Foundry.
      Requires: APIM system-assigned MI granted
      "Cognitive Services User" role on the Foundry resource.
      ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
    -->
    <authentication-managed-identity resource="https://cognitiveservices.azure.com" />

    <!--
      ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
      SECTION B: REQUIRED ANTHROPIC HEADERS
      anthropic-version is mandatory on every request to the
      Anthropic Messages API. Without it, Foundry returns 400.
      ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
    -->
    <set-header name="anthropic-version" exists-action="override">
      <value>2023-06-01</value>
    </set-header>

    <set-header name="Content-Type" exists-action="override">
      <value>application/json</value>
    </set-header>

    <!--
      ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
      SECTION C: STRIP NATIVE ANTHROPIC RATE LIMIT HEADERS
      Foundry does not pass through Anthropic's native rate
      limit headers. Strip any that callers may have sent
      inbound to prevent confusion. APIM reconstructs them
      outbound from its own tracking data (Section H below).
      ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
    -->
    <set-header name="anthropic-ratelimit-tokens-limit" exists-action="delete" />
    <set-header name="anthropic-ratelimit-tokens-remaining" exists-action="delete" />
    <set-header name="anthropic-ratelimit-tokens-reset" exists-action="delete" />
    <set-header name="anthropic-ratelimit-input-tokens-limit" exists-action="delete" />
    <set-header name="anthropic-ratelimit-input-tokens-remaining" exists-action="delete" />
    <set-header name="anthropic-ratelimit-input-tokens-reset" exists-action="delete" />
    <set-header name="anthropic-ratelimit-output-tokens-limit" exists-action="delete" />
    <set-header name="anthropic-ratelimit-output-tokens-remaining" exists-action="delete" />
    <set-header name="anthropic-ratelimit-output-tokens-reset" exists-action="delete" />
    <set-header name="anthropic-ratelimit-requests-limit" exists-action="delete" />
    <set-header name="anthropic-ratelimit-requests-remaining" exists-action="delete" />
    <set-header name="anthropic-ratelimit-requests-reset" exists-action="delete" />

    <!--
      ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
      SECTION D: CAPTURE TEAM/DEPARTMENT IDENTITY
      x-team-id is a caller-supplied header used for metric
      dimensions and chargeback reporting in App Insights.
      NOTE: This is for OBSERVABILITY only, not enforcement.
      Enforcement uses context.Subscription.Id (Product policy).
      ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
    -->
    <set-variable name="dept"
      value="@(context.Request.Headers.GetValueOrDefault(&quot;x-team-id&quot;, &quot;default&quot;))" />

    <!--
      ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
      SECTION E: PRE-FLIGHT PROMPT TOKEN ESTIMATION
      Estimates input token count from request body before
      the call completes. Used to populate the
      anthropic-ratelimit-tokens-remaining synthetic header
      with a reasonable value on the outbound leg.
      Approximation: ~3.8 characters per token.
      ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
    -->
    <set-variable name="estInputTokens"
      value="@{
        try {
          var body = context.Request.Body.As&lt;JObject&gt;(true);
          var msgs = body[&quot;messages&quot;]?.ToString() ?? &quot;&quot;;
          var sys  = body[&quot;system&quot;]?.ToString() ?? &quot;&quot;;
          return (int)((msgs.Length + sys.Length) / 3.8);
        } catch { return 0; }
      }" />

    <!--
      ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
      SECTION F: TOKEN METRICS EMISSION
      Sends Total Tokens, Prompt Tokens, Completion Tokens
      to Application Insights as custom metrics under the
      ClaudeUsage namespace. Query in Log Analytics:
        customMetrics | where name startswith "ClaudeUsage"
      NOTE: Max 5 custom dimensions per policy (Azure Monitor limit).
      ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
    -->
    <llm-emit-token-metric namespace="ClaudeUsage">
      <dimension name="API ID" />
      <dimension name="Subscription ID" value="@((string)context.Subscription?.Id)" />
      <dimension name="Client IP" value="@(context.Request.IpAddress)" />
      <dimension name="Model" value="claude-sonnet-4-6" />
      <dimension name="Team" value="@((string)context.Variables[&quot;dept&quot;])" />
    </llm-emit-token-metric>

  </inbound>

  <outbound>
    <base />

    <!--
      ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
      SECTION G: EXTRACT ACTUAL TOKEN USAGE FROM RESPONSE
      Claude returns usage in the response body as:
        { "usage": { "input_tokens": N, "output_tokens": N } }
      We extract these to populate headers and for logging.
      Body is read with preserveContent=true so the response
      body is still forwarded to the caller intact.
      ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
    -->
    <set-variable name="inputTokens"
      value="@{
        try {
          var body = context.Response.Body.As&lt;JObject&gt;(true);
          return body?[&quot;usage&quot;]?[&quot;input_tokens&quot;]?.ToString() ?? &quot;0&quot;;
        } catch { return &quot;0&quot;; }
      }" />

    <set-variable name="outputTokens"
      value="@{
        try {
          var body = context.Response.Body.As&lt;JObject&gt;(true);
          return body?[&quot;usage&quot;]?[&quot;output_tokens&quot;]?.ToString() ?? &quot;0&quot;;
        } catch { return &quot;0&quot;; }
      }" />

    <!--
      ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
      SECTION H: SYNTHESIZE ANTHROPIC-COMPATIBLE RATE LIMIT HEADERS
      Foundry strips all anthropic-ratelimit-* headers natively.
      APIM reconstructs them from its own tracking data so that
      callers and SDKs that key off these headers continue to
      work identically to calling Anthropic directly.

      Accuracy note:
        - tokens-limit: exact (hardcoded from product tier)
        - tokens-remaining: approximate (APIM counter, not Anthropic-precise)
        - tokens-reset: approximate (UtcNow + 60s window estimate)
      ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
    -->
    <set-variable name="productTpmLimit"
      value="@(context.Product?.Name == &quot;claude-enterprise&quot; ? &quot;50000&quot; :
               context.Product?.Name == &quot;claude-standard&quot;   ? &quot;10000&quot; : &quot;2000&quot;)" />

    <set-header name="anthropic-ratelimit-requests-limit" exists-action="override">
      <value>@((string)context.Variables[&quot;productTpmLimit&quot;])</value>
    </set-header>

    <set-header name="anthropic-ratelimit-requests-remaining" exists-action="override">
      <value>@(context.Variables.ContainsKey(&quot;remainingTokens&quot;) ? &quot;&quot; + context.Variables[&quot;remainingTokens&quot;] : &quot;unknown&quot;)</value>
    </set-header>

    <set-header name="anthropic-ratelimit-requests-reset" exists-action="override">
      <value>@(DateTimeOffset.UtcNow.AddSeconds(60).ToString(&quot;yyyy-MM-ddTHH:mm:ssZ&quot;))</value>
    </set-header>

    <set-header name="anthropic-ratelimit-tokens-limit" exists-action="override">
      <value>@((string)context.Variables[&quot;productTpmLimit&quot;])</value>
    </set-header>

    <set-header name="anthropic-ratelimit-tokens-remaining" exists-action="override">
      <value>@(context.Variables.ContainsKey(&quot;remainingTokens&quot;) ? &quot;&quot; + context.Variables[&quot;remainingTokens&quot;] : &quot;unknown&quot;)</value>
    </set-header>

    <set-header name="anthropic-ratelimit-tokens-reset" exists-action="override">
      <value>@(DateTimeOffset.UtcNow.AddSeconds(60).ToString(&quot;yyyy-MM-ddTHH:mm:ssZ&quot;))</value>
    </set-header>

    <!--
      ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
      SECTION I: CUSTOM TRANSPARENCY HEADERS
      These are non-standard headers that provide additional
      visibility to callers beyond the Anthropic-compatible set.
      ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
    -->
    <set-header name="x-token-usage" exists-action="override">
      <value>@($&quot;{context.Variables[&quot;inputTokens&quot;]}in/{context.Variables[&quot;outputTokens&quot;]}out&quot;)</value>
    </set-header>

    <set-header name="x-remaining-tokens" exists-action="skip">
      <value>@(context.Variables.ContainsKey(&quot;remainingTokens&quot;) ? &quot;&quot; + context.Variables[&quot;remainingTokens&quot;] : &quot;unknown&quot;)</value>
    </set-header>

    <set-header name="x-remaining-monthly" exists-action="skip">
      <value>@(context.Variables.ContainsKey(&quot;remainingQuotaTokens&quot;) ? &quot;&quot; + context.Variables[&quot;remainingQuotaTokens&quot;] : &quot;unknown&quot;)</value>
    </set-header>

    <set-header name="x-product-tier" exists-action="override">
      <value>@(context.Product?.Name ?? &quot;unknown&quot;)</value>
    </set-header>

    <set-header name="x-gateway" exists-action="override">
      <value>apim-claude-foundry</value>
    </set-header>

    <set-header name="x-gateway-request-id" exists-action="override">
      <value>@(context.RequestId.ToString())</value>
    </set-header>

  </outbound>

  <on-error>
    <choose>

      <when condition="@(context.Response.StatusCode == 429)">
        <return-response>
          <set-status code="429" reason="Too Many Requests" />
          <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
          </set-header>
          <set-header name="Retry-After" exists-action="override">
            <value>60</value>
          </set-header>
          <set-body>@{
            return new JObject(
              new JProperty(&quot;error&quot;, new JObject(
                new JProperty(&quot;type&quot;, &quot;rate_limit_error&quot;),
                new JProperty(&quot;code&quot;, &quot;RateLimitExceeded&quot;),
                new JProperty(&quot;message&quot;,
                  $&quot;Token rate limit exceeded for subscription '{context.Subscription?.Name}'. Retry after 60 seconds.&quot;),
                new JProperty(&quot;department&quot;, context.Variables[&quot;dept&quot;]),
                new JProperty(&quot;product&quot;, context.Product?.Name),
                new JProperty(&quot;gateway&quot;, &quot;apim-claude-foundry&quot;),
                new JProperty(&quot;retry_after_seconds&quot;, 60)
              ))
            ).ToString();
          }</set-body>
        </return-response>
      </when>

      <when condition="@(context.Response.StatusCode == 403)">
        <return-response>
          <set-status code="403" reason="Forbidden" />
          <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
          </set-header>
          <set-body>@{
            return new JObject(
              new JProperty(&quot;error&quot;, new JObject(
                new JProperty(&quot;type&quot;, &quot;quota_exceeded_error&quot;),
                new JProperty(&quot;code&quot;, &quot;MonthlyQuotaExceeded&quot;),
                new JProperty(&quot;message&quot;,
                  $&quot;Monthly token quota exceeded for team '{context.Variables[&quot;dept&quot;]}'. Quota resets at the start of next month.&quot;),
                new JProperty(&quot;department&quot;, context.Variables[&quot;dept&quot;]),
                new JProperty(&quot;product&quot;, context.Product?.Name),
                new JProperty(&quot;gateway&quot;, &quot;apim-claude-foundry&quot;)
              ))
            ).ToString();
          }</set-body>
        </return-response>
      </when>

    </choose>
    <base />

  </on-error>
</policies>
'@

$operationPolicyXml = @'
<policies>
  <inbound>
    <base />

    <!--
      ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
      MOCK BACKEND ΓÇö OPTION B (return-response)

      Intercepts the request before it reaches the Foundry
      backend and returns a hardcoded Anthropic Messages API
      shaped response. The API-level outbound policy still
      executes fully against this response.
      ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
    -->
    <return-response>
      <set-status code="200" reason="OK" />
      <set-header name="Content-Type" exists-action="override">
        <value>application/json</value>
      </set-header>
      <set-body>@{
        var requestId = context.RequestId.ToString().Replace("-", "").Substring(0, 12);
        var inputEst  = (int)context.Variables.GetValueOrDefault("estInputTokens", 0);

        return new JObject(
          new JProperty("id",    "msg_mock_" + requestId),
          new JProperty("type",  "message"),
          new JProperty("role",  "assistant"),
          new JProperty("model", "claude-sonnet-4-6"),
          new JProperty("content", new JArray(
            new JObject(
              new JProperty("type", "text"),
              new JProperty("text",
                "This is a mocked Claude response for APIM policy testing. " +
                "Request correlation ID: " + context.RequestId.ToString() + ". " +
                "Product tier: " + (context.Product?.Name ?? "unknown") + ". " +
                "Team: " + context.Variables.GetValueOrDefault("dept", "default").ToString() + ".")
            )
          )),
          new JProperty("stop_reason",   "end_turn"),
          new JProperty("stop_sequence", null),
          new JProperty("usage", new JObject(
            new JProperty("input_tokens",  inputEst > 0 ? inputEst : 42),
            new JProperty("output_tokens", 25)
          ))
        ).ToString();
      }</set-body>
    </return-response>

  </inbound>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
'@

$subscriptions = @(
    @{ name = 'dept-engineering'; displayName = 'Engineering Department'; scope = '/products/claude-enterprise' },
    @{ name = 'app-quinn-prod'; displayName = 'QUINN Production App'; scope = '/products/claude-enterprise' },
    @{ name = 'dept-finance'; displayName = 'Finance Department'; scope = '/products/claude-standard' },
    @{ name = 'dept-support'; displayName = 'Support Department'; scope = '/products/claude-standard' },
    @{ name = 'key-contractors'; displayName = 'External Contractors'; scope = '/products/claude-restricted' }
)

Write-Host "Creating resource group $ResourceGroup in $Location"
Invoke-Az -Arguments @('group', 'create', '--name', $ResourceGroup, '--location', $Location, '--output', 'none')

if (Test-Az -Arguments @('monitor', 'log-analytics', 'workspace', 'show', '--resource-group', $ResourceGroup, '--workspace-name', $LogAnalyticsName, '--output', 'none')) {
  Write-Host 'Log Analytics workspace already exists'
  $lawId = Invoke-AzTsv -Arguments @('monitor', 'log-analytics', 'workspace', 'show', '--resource-group', $ResourceGroup, '--workspace-name', $LogAnalyticsName, '--query', 'id', '--output', 'tsv')
}
else {
  Write-Host 'Provisioning Log Analytics workspace'
  $lawId = Invoke-AzTsv -Arguments @('monitor', 'log-analytics', 'workspace', 'create', '--resource-group', $ResourceGroup, '--workspace-name', $LogAnalyticsName, '--location', $Location, '--query', 'id', '--output', 'tsv')
}

if (Test-Az -Arguments @('monitor', 'app-insights', 'component', 'show', '--app', $AppInsightsName, '--resource-group', $ResourceGroup, '--output', 'none')) {
  Write-Host 'Application Insights component already exists'
}
else {
  Write-Host 'Provisioning Application Insights'
  Invoke-Az -Arguments @('monitor', 'app-insights', 'component', 'create', '--app', $AppInsightsName, '--resource-group', $ResourceGroup, '--location', $Location, '--kind', 'web', '--application-type', 'web', '--workspace', $lawId, '--output', 'none')
}
$appInsightsId = Invoke-AzTsv -Arguments @('monitor', 'app-insights', 'component', 'show', '--app', $AppInsightsName, '--resource-group', $ResourceGroup, '--query', 'id', '--output', 'tsv')
$appInsightsConnectionString = Invoke-AzTsv -Arguments @('monitor', 'app-insights', 'component', 'show', '--app', $AppInsightsName, '--resource-group', $ResourceGroup, '--query', 'connectionString', '--output', 'tsv')

if (-not (Test-Az -Arguments @('apim', 'show', '--resource-group', $ResourceGroup, '--name', $ApimName, '--output', 'none'))) {
    Write-Host 'Provisioning API Management (Developer tier). This is the long-running step.'
    Invoke-Az -Arguments @('apim', 'create', '--name', $ApimName, '--resource-group', $ResourceGroup, '--location', $Location, '--publisher-email', $PublisherEmail, '--publisher-name', $PublisherName, '--sku-name', 'Developer', '--output', 'none')
}

$apimId = Invoke-AzTsv -Arguments @('apim', 'show', '--resource-group', $ResourceGroup, '--name', $ApimName, '--query', 'id', '--output', 'tsv')

Write-Host 'Enabling APIM system-assigned managed identity'
Invoke-Az -Arguments @('resource', 'update', '--ids', $apimId, '--set', 'identity.type=SystemAssigned', '--output', 'none')

Write-Host 'Linking Application Insights to APIM via logger resource'
$loggerUri = "https://management.azure.com$apimId/loggers/appinsights-logger?api-version=2022-08-01"
Invoke-AzRestPut -Uri $loggerUri -Body @{
    properties = @{
        loggerType = 'applicationInsights'
        description = 'Application Insights logger for Claude gateway'
        resourceId = $appInsightsId
        credentials = @{
            connectionString = $appInsightsConnectionString
        }
    }
}

Write-Host 'Configuring APIM diagnostic settings to Log Analytics'
Invoke-Az -Arguments @(
    'monitor', 'diagnostic-settings', 'create',
    '--name', 'apim-to-log-analytics',
    '--resource', $apimId,
    '--workspace', $lawId,
    '--logs', '[{"category":"GatewayLogs","enabled":true}]',
    '--metrics', '[{"category":"AllMetrics","enabled":true}]',
    '--output', 'none'
)

if (-not (Test-Az -Arguments @('apim', 'api', 'show', '--resource-group', $ResourceGroup, '--service-name', $ApimName, '--api-id', $apiId, '--output', 'none'))) {
    Write-Host 'Creating Claude Foundry Gateway API'
    Invoke-Az -Arguments @(
        'apim', 'api', 'create',
        '--resource-group', $ResourceGroup,
        '--service-name', $ApimName,
        '--api-id', $apiId,
        '--display-name', $apiDisplayName,
        '--path', 'claude',
        '--api-type', 'http',
        '--service-url', $mockBackendUrl,
        '--protocols', 'https',
        '--subscription-required', 'true',
        '--output', 'none'
    )
}

if (-not (Test-Az -Arguments @('apim', 'api', 'operation', 'show', '--resource-group', $ResourceGroup, '--service-name', $ApimName, '--api-id', $apiId, '--operation-id', $operationId, '--output', 'none'))) {
    Write-Host 'Creating POST /v1/messages operation'
    Invoke-Az -Arguments @(
        'apim', 'api', 'operation', 'create',
        '--resource-group', $ResourceGroup,
        '--service-name', $ApimName,
        '--api-id', $apiId,
        '--operation-id', $operationId,
        '--display-name', 'Messages',
        '--method', 'POST',
        '--url-template', '/v1/messages',
        '--description', 'Anthropic-compatible messages endpoint',
        '--output', 'none'
    )
}

$productDefinitions = @(
    @{ id = 'claude-enterprise'; name = 'claude-enterprise'; description = 'Enterprise tier - 50K TPM, 5M tokens/month' },
    @{ id = 'claude-standard'; name = 'claude-standard'; description = 'Standard tier - 10K TPM, 500K tokens/month' },
    @{ id = 'claude-restricted'; name = 'claude-restricted'; description = 'Restricted tier - 2K TPM, 100K tokens/month' }
)

foreach ($product in $productDefinitions) {
    if (-not (Test-Az -Arguments @('apim', 'product', 'show', '--resource-group', $ResourceGroup, '--service-name', $ApimName, '--product-id', $product.id, '--output', 'none'))) {
        Write-Host "Creating product $($product.id)"
        Invoke-Az -Arguments @(
            'apim', 'product', 'create',
            '--resource-group', $ResourceGroup,
            '--service-name', $ApimName,
            '--product-id', $product.id,
            '--product-name', $product.name,
            '--description', $product.description,
            '--subscription-required', 'true',
            '--state', 'published',
            '--output', 'none'
        )
    }

    Ensure-ApiProductLink -ProductId $product.id -ApiId $apiId -ResourceGroup $ResourceGroup -ApimName $ApimName

    $productPolicyUri = "https://management.azure.com$apimId/products/$($product.id)/policies/policy?api-version=2022-08-01"
    Invoke-AzRestPut -Uri $productPolicyUri -Body @{
        properties = @{
            format = 'rawxml'
            value = $productPolicies[$product.id]
        }
    }
}

Write-Host 'Applying API policy'
$apiPolicyUri = "https://management.azure.com$apimId/apis/$apiId/policies/policy?api-version=2022-08-01"
Invoke-AzRestPut -Uri $apiPolicyUri -Body @{
    properties = @{
        format = 'rawxml'
        value = $apiPolicyXml
    }
}

Write-Host 'Applying mock operation policy'
$operationPolicyUri = "https://management.azure.com$apimId/apis/$apiId/operations/$operationId/policies/policy?api-version=2022-08-01"
Invoke-AzRestPut -Uri $operationPolicyUri -Body @{
    properties = @{
        format = 'rawxml'
        value = $operationPolicyXml
    }
}

foreach ($subscription in $subscriptions) {
    Write-Host "Ensuring subscription $($subscription.name)"
    $subscriptionUri = "https://management.azure.com$apimId/subscriptions/$($subscription.name)?api-version=2023-05-01-preview"
    Invoke-AzRestPut -Uri $subscriptionUri -Body @{
        properties = @{
            displayName = $subscription.displayName
            scope = $subscription.scope
            state = 'active'
            allowTracing = $false
        }
    }
}

$gatewayUrl = Invoke-AzTsv -Arguments @('apim', 'show', '--resource-group', $ResourceGroup, '--name', $ApimName, '--query', 'gatewayUrl', '--output', 'tsv')
$validationSecretsUri = "https://management.azure.com$apimId/subscriptions/dept-finance/listSecrets?api-version=2023-05-01-preview"
$validationKey = Invoke-AzTsv -Arguments @('rest', '--method', 'post', '--uri', $validationSecretsUri, '--query', 'primaryKey', '--output', 'tsv')

$result = [ordered]@{
    subscriptionName = $account.name
    resourceGroup = $ResourceGroup
    location = $Location
    apimName = $ApimName
    gatewayUrl = $gatewayUrl
    appInsights = $AppInsightsName
    logAnalytics = $LogAnalyticsName
    validationSubscription = 'dept-finance'
}

if (-not $SkipValidation) {
    Write-Host 'Running mock validation request through APIM'
    $requestBody = @'
{
  "model": "claude-sonnet-4-6",
  "max_tokens": 100,
  "messages": [
    {
      "role": "user",
      "content": "Hello, this is a policy test. Please confirm you are working."
    }
  ]
}
'@

    $headers = @{
        'Ocp-Apim-Subscription-Key' = $validationKey
        'x-team-id' = 'engineering'
        'Content-Type' = 'application/json'
    }

    $response = Invoke-WebRequest -Uri "$gatewayUrl/claude/v1/messages" -Method Post -Headers $headers -Body $requestBody
    $body = $response.Content | ConvertFrom-Json

    $result.validation = [ordered]@{
        statusCode = [int]$response.StatusCode
        responseId = $body.id
        model = $body.model
        xGateway = $response.Headers['x-gateway']
        xProductTier = $response.Headers['x-product-tier']
        xTokenUsage = $response.Headers['x-token-usage']
        ratelimitTokensLimit = $response.Headers['anthropic-ratelimit-tokens-limit']
        ratelimitTokensRemaining = $response.Headers['anthropic-ratelimit-tokens-remaining']
        gatewayRequestId = $response.Headers['x-gateway-request-id']
    }
}

$result | ConvertTo-Json -Depth 10
