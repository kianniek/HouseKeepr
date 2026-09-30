param(
  [switch]$CheckOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $repoRoot

try {
  $dartFiles = @()

  # Prefer tracked files so formatting does not traverse generated directories.
  $gitCmd = Get-Command git -ErrorAction SilentlyContinue
  if ($null -ne $gitCmd) {
    $dartFiles = @(git ls-files -- '*.dart')
  }

  if ($dartFiles.Count -eq 0) {
    $dartFiles = @(
      Get-ChildItem -Path . -Recurse -File -Filter '*.dart' |
        Where-Object {
          $_.FullName -notmatch '\\(build|\.dart_tool|\.git|Pods|DerivedData)\\'
        } |
        ForEach-Object {
          Resolve-Path -Relative -Path $_.FullName
        }
    )
  }

  if ($dartFiles.Count -eq 0) {
    Write-Host 'No Dart files found to format.'
    exit 0
  }

  $baseArgs = @('format')
  if ($CheckOnly) {
    $baseArgs += @('--output=none', '--set-exit-if-changed')
  }

  # Format in chunks to avoid Windows command-line length limits.
  $chunkSize = 200
  for ($i = 0; $i -lt $dartFiles.Count; $i += $chunkSize) {
    $end = [Math]::Min($i + $chunkSize - 1, $dartFiles.Count - 1)
    $chunk = $dartFiles[$i..$end]

    & dart $baseArgs $chunk
    if ($LASTEXITCODE -ne 0) {
      exit $LASTEXITCODE
    }
  }

  if ($CheckOnly) {
    Write-Host "Formatting check passed for $($dartFiles.Count) Dart files."
  } else {
    Write-Host "Formatted $($dartFiles.Count) Dart files."
  }
}
finally {
  Pop-Location
}
