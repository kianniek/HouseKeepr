# Script to build Flutter application for all platforms

# Set the environment variables from .env file
# Assuming .env file is in the root of the project
$env:BUILD_ARGS = "--dart-define-from-file=.env"
$env:BUILD_WEB_BASE_HREF = '/housekeepr/'

Write-Host "Starting Flutter build process..."

# 1. Build for Android App Bundle
Write-Host "Building for Android App Bundle..."
flutter build appbundle $env:BUILD_ARGS

# 2. Build for Web
Write-Host "Building for Web..."
flutter build web $env:BUILD_ARGS --base-href=$env:BUILD_WEB_BASE_HREF

Write-Host "Build process completed."