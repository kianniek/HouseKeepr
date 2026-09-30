Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$branch = (git branch --show-current).Trim()
$lastCommitHash = (git log -1 --format='%h').Trim()
$lastCommitMessage = (git log -1 --format='%s').Trim()

Write-Host ''
Write-Host '--------------------------------------------------' -ForegroundColor DarkGray
Write-Host 'Commit successfully created.' -ForegroundColor Green
Write-Host "  Branch: $branch" -ForegroundColor Yellow
Write-Host "  Hash:   $lastCommitHash" -ForegroundColor DarkGray
Write-Host "  Msg:    $lastCommitMessage" -ForegroundColor Gray
Write-Host '--------------------------------------------------' -ForegroundColor DarkGray

if ($branch -like 'feature/*' -or $branch -like 'fix/*' -or $branch -like 'hotfix/*') {
  Write-Host "Tip: push with 'git push -u origin $branch' and open a pull request into testing." -ForegroundColor Cyan
}