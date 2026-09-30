Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $repoRoot

try {
  if (-not (Test-Path -LiteralPath (Join-Path $repoRoot '.git'))) {
    throw 'Not a Git repository. Run this script from a checkout with a .git directory.'
  }

  git config core.hooksPath scripts/hooks
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to configure Git core.hooksPath.'
  }

  Write-Host 'Git hooks configured at scripts/hooks.' -ForegroundColor Green
  Write-Host 'Hooks run automatically for future commits in this checkout.'
}
finally {
  Pop-Location
}