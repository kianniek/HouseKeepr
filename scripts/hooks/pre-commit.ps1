Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host '==> Running pre-commit checks...' -ForegroundColor Cyan

$branch = (git branch --show-current).Trim()
if ($branch -in @('main', 'testing')) {
  Write-Host "[ERROR] Direct commits to '$branch' are prohibited. Use a topic branch and open a pull request." -ForegroundColor Red
  exit 1
}

$stagedFiles = @(
  git diff --cached --name-only --diff-filter=ACMR |
    Where-Object { $_ -like '*.dart' }
)

if ($stagedFiles.Count -eq 0) {
  Write-Host 'No staged Dart files found. Skipping Flutter checks.' -ForegroundColor Yellow
  exit 0
}

Write-Host '-> Formatting staged Dart files...' -ForegroundColor Cyan
& dart format @stagedFiles
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

foreach ($file in $stagedFiles) {
  git add -- $file
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}

Write-Host '-> Running Flutter analyze...' -ForegroundColor Cyan
& flutter analyze
if ($LASTEXITCODE -ne 0) {
  Write-Host '[ERROR] Flutter analyze found issues.' -ForegroundColor Red
  exit $LASTEXITCODE
}

Write-Host '-> Running Flutter tests...' -ForegroundColor Cyan
& flutter test --suppress-analytics
if ($LASTEXITCODE -ne 0) {
  Write-Host '[ERROR] Flutter tests failed.' -ForegroundColor Red
  exit $LASTEXITCODE
}

Write-Host 'All pre-commit checks passed.' -ForegroundColor Green
exit 0