# Run Flutter with device/mode selection and env defines
# Usage: .\run_flutter_with_env.ps1 [-stepbystep]

Param(
    [Alias("h", "help", "s")]
    [Switch]$stepbystep
)

$projectPath = (Get-Location).Path
Push-Location $projectPath

try {
    $devicesJson = flutter devices --machine | Out-String
    $devices = $devicesJson | ConvertFrom-Json

    if (-not $devices -or $devices.Count -eq 0) {
        Write-Error "No Flutter devices detected. Run 'flutter devices' to troubleshoot."
        exit 1
    }

    $deviceId = ""
    $mode = "debug"

    if ($stepbystep) {
        # --- INTERACTIVE MODE ---
        Write-Host "Available Flutter devices:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $devices.Count; $i++) {
            $device = $devices[$i]
            $index = $i + 1
            Write-Host ("[{0}] {1} ({2}) - {3}" -f $index, $device.name, $device.id, $device.platform)
        }

        $selection = Read-Host "Select device number"
        if (-not [int]::TryParse($selection, [ref]$null)) {
            Write-Error "Invalid selection. Enter a device number."
            exit 1
        }

        $selectionIndex = [int]$selection - 1
        if ($selectionIndex -lt 0 -or $selectionIndex -ge $devices.Count) {
            Write-Error "Selection out of range."
            exit 1
        }

        $deviceId = $devices[$selectionIndex].id

        $modeInput = Read-Host "Select build mode (debug/release) [debug]"
        $mode = if ([string]::IsNullOrWhiteSpace($modeInput)) { "debug" } else { $modeInput.ToLowerInvariant() }

        if ($mode -ne "debug" -and $mode -ne "release") {
            Write-Error "Invalid mode. Use 'debug' or 'release'."
            exit 1
        }
    }
    else {
        # --- DEFAULT AUTO-RUN MODE ---
        # get available device based on preference (e.g. web, then mobile, then desktop)
        $platformPreference = @("web", "android", "ios", "windows", "linux", "macos")
        $device = $null
        foreach ($platform in $platformPreference) {
            $device = $devices | Where-Object { $_.platform -eq $platform } | Select-Object -First 1
            if ($device) {
                break
            }
        }

        Write-Host "No device specified. Auto-selecting based on platform preference: $($platformPreference -join ', ')." -ForegroundColor Yellow

        if (-not $device) {
            $device = $devices[0]
        }
        $deviceId = $device.id
        Write-Host "Auto-selecting device: $($device.name) ($($deviceId))" -ForegroundColor Green
        Write-Host "Mode: debug" -ForegroundColor Green
    }

    # Define the string
    $string = "Happy coding!"

    # Define an array of rainbow colors supported by Write-Host
    $rainbow = @("Red", "DarkMagenta", "Yellow", "Green", "Blue", "Cyan")

    # Initialize a counter to cycle through the colors
    $colorIndex = 0

    # Loop through each character in the string
    foreach ($char in $string.ToCharArray()) {
        # Print the character with the current color, keeping it on the same line
        Write-Host $char -ForegroundColor $rainbow[$colorIndex] -NoNewline
        
        # Move to the next color, looping back to 0 if we reach the end of the array
        $colorIndex = ($colorIndex + 1) % $rainbow.Count
    }

    # Print a final newline so the prompt resets correctly
    Write-Host ""

    Write-Host "Selected device: $deviceId" -ForegroundColor Green
    # Write-host "Cleaning Flutter build..." -ForegroundColor Yellow
    # flutter clean
    Write-Host "Ensuring .env file exists..." -ForegroundColor Yellow
    if (-not (Test-Path -Path ".env")) {
        Write-Error "No .env file found in project root. Create a .env file with your environment variables."
        exit 1
    } else {
        Write-Host ".env file found." -ForegroundColor Green
    }
    # Write-Host "Running flutter pub get..." -ForegroundColor Yellow
    # flutter pub get
    Write-Host "Running: flutter run -d $deviceId --$mode --dart-define-from-file=.env" -ForegroundColor Yellow
    flutter run -d $deviceId --$mode --dart-define-from-file=.env
}
finally {
    Pop-Location
}