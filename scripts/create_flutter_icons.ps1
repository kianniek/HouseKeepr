$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$repoRoot = Resolve-Path (Join-Path $scriptDir '..')
Push-Location $repoRoot

Write-Host "Running flutter pub get..."
& flutter pub get
if ($LASTEXITCODE -ne 0) {
	Write-Error "flutter pub get failed with exit code $LASTEXITCODE"
	Pop-Location
	exit $LASTEXITCODE
}

Write-Host "Running dart run flutter_launcher_icons..."
& dart run flutter_launcher_icons
if ($LASTEXITCODE -ne 0) {
	Write-Error "dart run flutter_launcher_icons failed with exit code $LASTEXITCODE"
	Pop-Location
	exit $LASTEXITCODE
}

Pop-Location
Write-Host "Done."

