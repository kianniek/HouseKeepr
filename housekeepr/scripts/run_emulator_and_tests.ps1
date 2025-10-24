param()

# Start the Firebase emulator and run Flutter tests on Windows PowerShell
# Requires: firebase-tools installed and available on PATH, or set FIREBASE_CLI_TOKEN in CI

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "Starting Firestore emulator..."

# Write emulator output to a temp log via cmd redirection to avoid Start-Process redirect limitations
$logFile = "$env:TEMP\firebase-emulator.log"
if (Test-Path $logFile) { Remove-Item $logFile -ErrorAction SilentlyContinue }

# Start the emulator in background using cmd so we can redirect both stdout and stderr to the log file
$startArgs = "/c firebase emulators:start --only firestore --project=demo-project > `"$logFile`" 2>&1"
$proc = Start-Process -FilePath "cmd" -ArgumentList $startArgs -WindowStyle Hidden -PassThru

# Wait briefly for the emulator to produce log output
Start-Sleep -Seconds 1

$retry = 0
$max = 60
while (-not (Test-Path $logFile) -and $retry -lt $max) {
    Start-Sleep -Seconds 1
    $retry++
}

$retry = 0
while ($retry -lt $max) {
    if (Test-Path $logFile) {
        try {
            if (Select-String -Pattern "All emulators ready" -Path $logFile -SimpleMatch -Quiet) {
                Write-Host "Firestore emulator started."
                break
            }
        } catch {
            # ignore read race
        }
    }
    Start-Sleep -Seconds 1
    $retry++
}

if (-not (Test-Path $logFile) -or -not (Select-String -Pattern "All emulators ready" -Path $logFile -SimpleMatch -Quiet)) {
    Write-Error "Firestore emulator failed to start. Showing log if present:"
    if (Test-Path $logFile) { Get-Content $logFile -TotalCount 200 | ForEach-Object { Write-Error $_ } }
    # try to stop process if started
    if ($proc -and -not $proc.HasExited) { $proc.Kill() | Out-Null }
    Exit 1
}

# Set emulator env vars for tests
$env:FIRESTORE_EMULATOR_HOST = "localhost:8080"
$env:FIREBASE_AUTH_EMULATOR_HOST = "localhost:9099"

# Run flutter test in the current project root
Write-Host "Running flutter test in $root"
$devices = flutter devices --machine | Out-String
if ($devices -match '"platformType"\W*:\W*"(android|ios)"') {
    Write-Host "Device found — running integration tests."
    flutter test integration_test
} else {
    Write-Host "No Android/iOS device found — running unit/widget tests only."
    flutter test
}
$exit = $LASTEXITCODE

# Teardown emulator
if ($proc -and -not $proc.HasExited) {
    try {
        Write-Host "Stopping emulator (pid $($proc.Id))"
        $proc | Stop-Process -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "Failed to stop emulator process: $_"
    }
}

Exit $exit
