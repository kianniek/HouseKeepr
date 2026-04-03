# Run Flutter with device/mode selection and env defines
# Usage: .\run_flutter_with_env.ps1

$projectPath = "C:\Users\kiann\Documents\Coding Projects\HouseKeepr\housekeepr"

Push-Location $projectPath

try {
  $devicesJson = flutter devices --machine | Out-String
  $devices = $devicesJson | ConvertFrom-Json

  if (-not $devices -or $devices.Count -eq 0) {
    Write-Error "No Flutter devices detected. Run 'flutter devices' to troubleshoot."
    exit 1
  }

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

  flutter run -d $deviceId --$mode --dart-define-from-file=.env
}
finally {
  Pop-Location
}
