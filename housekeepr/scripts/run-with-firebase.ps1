<#
Convenience wrapper: load FIREBASE_* env vars from `.env.local` (via set-firebase-env.ps1)
and then run `flutter run` with any provided arguments.

Usage (from repo root):
  .\scripts\run-with-firebase.ps1
  .\scripts\run-with-firebase.ps1 -DeviceId chrome
  .\scripts\run-with-firebase.ps1 -- -d chrome  # pass args to flutter

Notes:
- The script will attempt to dot-source `scripts/set-firebase-env.ps1` to set
  environment variables in this process. If `.env.local` is missing you'll see
  a warning, but the script will continue and call `flutter run` anyway.
#>

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]
    $FlutterArgs
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir '..')
Push-Location $repoRoot
try {
    $setScript = Join-Path $repoRoot 'scripts\set-firebase-env.ps1'
    if (Test-Path $setScript) {
        Write-Host "Sourcing $setScript to set FIREBASE_* env vars..." -ForegroundColor Cyan
        # dot-source the set script so it runs in this process and updates Env:
        . $setScript
    }
    else {
        Write-Host "Warning: $setScript not found. Skipping env setup." -ForegroundColor Yellow
    }

    # Build flutter run command
    $cmd = 'flutter'
    $flutterArgsList = @('run')
    if ($FlutterArgs) { $flutterArgsList += $FlutterArgs }

    Write-Host "Running: $cmd $($flutterArgsList -join ' ')" -ForegroundColor Green
    & $cmd @flutterArgsList
    $exitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}

# Exit with the same code as flutter
if ($null -ne $exitCode) { exit $exitCode }
