# Build Flutter app bundle for release with obfuscation and debug info splitting
# Usage: .\build_appbundle.ps1

$projectPath = "C:\Users\kiann\Documents\Coding Projects\HouseKeepr\housekeepr"

Push-Location $projectPath

flutter run -d R3CT600ACNF `
  --release `
  --dart-define-from-file=.env

Pop-Location