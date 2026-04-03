# Installs the pre-commit hook from scripts/pre-commit into .git/hooks
$hookSource = Join-Path $PSScriptRoot 'pre-commit'
$hookTarget = Join-Path $PSScriptRoot '..\.git\hooks\pre-commit'
if (Test-Path $hookTarget) {
  Write-Host "Backing up existing pre-commit hook to pre-commit.bak"
  Move-Item -Path $hookTarget -Destination ($hookTarget + '.bak') -Force
}
Copy-Item -Path $hookSource -Destination $hookTarget -Force
Write-Host "Pre-commit hook installed to .git/hooks/pre-commit"
Write-Host "If you're on Windows, ensure Git Bash or WSL honors the hook execution permissions."