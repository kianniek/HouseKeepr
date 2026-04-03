# Build Flutter app bundle for release with obfuscation and debug info splitting
# Usage: .\build_appbundle.ps1

$projectPath = "C:\Users\kiann\Documents\Coding Projects\HouseKeepr\housekeepr"

Push-Location $projectPath

pubversion patch
flutter build appbundle --release --obfuscate --split-debug-info=./debug_info --dart-define-from-file=.env

Pop-Location