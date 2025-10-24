param(
    [string]$TestPath = 'test/integration',
    [string]$FirebaseJson = "$PSScriptRoot\..\firebase.json",
    [switch]$VerboseMode
)

# Robust helper to run Firestore emulator and execute Flutter tests against it.
# Behavior:
# 1. Read host/port from firebase.json under emulators.firestore (fallback to localhost:8080).
# 2. Try `firebase emulators:exec --only firestore "flutter test <path>"` to manage lifecycle.
# 3. If emulators:exec fails because port is in use, assume an emulator is already running and run tests
#    with FIRESTORE_EMULATOR_HOST set to the configured host:port.
# Prereqs: firebase-tools and flutter on PATH, Java for the emulator.

Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if ($VerboseMode) { Write-Host "Script root: $root" }

function Read-EmulatorHostPort {
    param([string]$Path)
    $host = '127.0.0.1'
    $port = 8080
    if (Test-Path $Path) {
        try {
            $json = Get-Content $Path -Raw | ConvertFrom-Json -ErrorAction Stop
            if ($json.emulators -and $json.emulators.firestore) {
                if ($json.emulators.firestore.host) { $host = $json.emulators.firestore.host }
                if ($json.emulators.firestore.port) { $port = [int]$json.emulators.firestore.port }
            }
        }
        catch {
            Write-Warning "Failed to parse firebase.json at $Path: $_"
        }
    }
    else {
        Write-Verbose "firebase.json not found at $Path; using defaults"
    }
    return @{ Host = $host; Port = $port }
}

$ep = Read-EmulatorHostPort -Path $FirebaseJson
$host = $ep.Host
$port = $ep.Port

Write-Host "Using Firestore emulator host: $host`:$port"

# Preferred path: use firebase emulators:exec to manage lifecycle cleanly
$execCmd = "firebase emulators:exec --only firestore \"flutter test $TestPath\""
Write-Host "Running: $execCmd"
try {
    # Run directly so we stream output to the console and inherit environment
    iex $execCmd
    $exit = $LASTEXITCODE
    if ($exit -eq 0) { Exit 0 }
    Write-Warning "firebase emulators:exec exited with code $exit"
}
catch {
    Write-Warning "firebase emulators:exec failed: $_"
}

# If we reach here, emulators:exec didn't work (likely port conflict). Try running tests against an existing emulator.
Write-Host "Attempting to run tests against an already-running emulator at $host:$port"

# Wait briefly for port to be reachable
$maxWait = 30
$i = 0
while (-not (Test-NetConnection -ComputerName $host -Port $port -InformationLevel Quiet) -and $i -lt $maxWait) {
    Start-Sleep -Seconds 1
    $i++
}

if (-not (Test-NetConnection -ComputerName $host -Port $port -InformationLevel Quiet)) {
    Write-Error "Emulator not reachable at $host:$port after waiting $maxWait seconds. Aborting."
    Exit 2
}

# Export emulator env var for Flutter tests
$env:FIRESTORE_EMULATOR_HOST = "$host`:$port"
if ($json -and $json.emulators -and $json.emulators.auth) {
    $authHost = $json.emulators.auth.host
    $authPort = $json.emulators.auth.port
    if ($authHost -and $authPort) { $env:FIREBASE_AUTH_EMULATOR_HOST = "$authHost`:$authPort" }
}

Write-Host "Running flutter test $TestPath (FIRESTORE_EMULATOR_HOST=$env:FIRESTORE_EMULATOR_HOST)"
flutter test $TestPath
$exit = $LASTEXITCODE

Exit $exit
