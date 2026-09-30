param(
  [Parameter(Mandatory = $true)]
  [string]$CommitMsgFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $CommitMsgFile)) {
  Write-Host '[ERROR] Commit message file not found.' -ForegroundColor Red
  exit 1
}

$lines = @(
  Get-Content -LiteralPath $CommitMsgFile -Encoding UTF8 |
    Where-Object { $_ -notmatch '^\s*#' }
)

if ($lines.Count -eq 0 -or [string]::IsNullOrWhiteSpace(($lines -join '').Trim())) {
  Write-Host '[ERROR] Commit message cannot be empty.' -ForegroundColor Red
  exit 1
}

$header = $lines[0].Trim()
if ($header -match '^Merge branch' -or $header -match '^Merge pull request' -or $header -match '^Revert "') {
  exit 0
}

$pattern = '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(([a-zA-Z0-9_.\-/]+)\))?(!)?:\s+(.+)$'
if ($header -notmatch $pattern) {
  Write-Host 'Commit rejected: use Conventional Commits, for example:' -ForegroundColor Red
  Write-Host '  feat(auth): add refresh token handling' -ForegroundColor Green
  Write-Host 'Allowed types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert' -ForegroundColor Yellow
  exit 1
}

$subject = $Matches[5]
if ($header.Length -gt 72) {
  Write-Host "[ERROR] Commit header is too long ($($header.Length) characters); keep it under 72." -ForegroundColor Red
  exit 1
}

if ($subject.EndsWith('.')) {
  Write-Host "[ERROR] Do not end the commit subject with a period '.'." -ForegroundColor Red
  exit 1
}

if ($subject -cmatch '^[A-Z]') {
  Write-Host '[WARNING] Conventional Commit subjects should start with lowercase.' -ForegroundColor Yellow
}

Write-Host 'Commit message follows Conventional Commits format.' -ForegroundColor Green
exit 0