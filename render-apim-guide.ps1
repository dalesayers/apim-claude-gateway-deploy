param(
  [string]$MarkdownPath = (Join-Path $PSScriptRoot '..\apim-claude-foundry-gateway-setup.md'),
  [string]$HtmlPath = (Join-Path $PSScriptRoot '..\apim-claude-foundry-gateway-setup.html'),
  [string]$DocumentTitle = 'Azure APIM AI Gateway for Claude on Microsoft Foundry',
  [string]$PdfPath,
  [string]$BrowserPath = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
)

$ErrorActionPreference = 'Stop'

$rendered = ConvertFrom-Markdown -Path $markdownPath

$htmlDocument = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>$DocumentTitle</title>
  <style>
    :root {
      color-scheme: light;
      --bg: #ffffff;
      --fg: #1f2328;
      --muted: #59636e;
      --border: #d0d7de;
      --code-bg: #f6f8fa;
      --table-head: #f3f4f6;
      --link: #0969da;
    }
    body {
      margin: 0;
      background: var(--bg);
      color: var(--fg);
      font-family: Segoe UI, Arial, sans-serif;
      line-height: 1.6;
    }
    main {
      max-width: 980px;
      margin: 0 auto;
      padding: 40px 24px 64px;
    }
    h1, h2, h3, h4 {
      line-height: 1.25;
    }
    h1 {
      margin-top: 0;
    }
    a {
      color: var(--link);
    }
    pre, code {
      font-family: Consolas, 'Courier New', monospace;
    }
    pre {
      background: var(--code-bg);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 16px;
      overflow-x: auto;
    }
    code {
      background: var(--code-bg);
      padding: 0.1em 0.3em;
      border-radius: 4px;
    }
    pre code {
      background: transparent;
      padding: 0;
    }
    table {
      border-collapse: collapse;
      width: 100%;
      margin: 16px 0;
    }
    th, td {
      border: 1px solid var(--border);
      padding: 8px 10px;
      text-align: left;
      vertical-align: top;
    }
    th {
      background: var(--table-head);
    }
    blockquote {
      border-left: 4px solid var(--border);
      margin-left: 0;
      padding-left: 16px;
      color: var(--muted);
    }
  </style>
</head>
<body>
  <main>
$($rendered.Html)
  </main>
</body>
</html>
"@

Set-Content -Path $htmlPath -Value $htmlDocument -Encoding utf8
Write-Host "Generated: $htmlPath"

if ($PdfPath) {
  if (-not (Test-Path $BrowserPath)) {
    throw "Browser executable not found: $BrowserPath"
  }

  $htmlUri = 'file:///' + (($HtmlPath -replace '\\', '/') -replace ' ', '%20')
  & $BrowserPath --headless --disable-gpu --print-to-pdf-no-header --print-to-pdf="$PdfPath" $htmlUri | Out-Null

  if ($LASTEXITCODE -ne 0) {
    throw "PDF generation failed for: $PdfPath"
  }

  Write-Host "Generated: $PdfPath"
}
