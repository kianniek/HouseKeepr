<#
Build the Flutter web app including `.env` Dart defines.

Usage:
  .\build_web_with_env.ps1
  .\build_web_with_env.ps1 -BaseHref '/housekeepr/' -Mode release

Parameters:
  -ProjectPath: Path to repo root containing `pubspec.yaml`. Defaults to current directory.
  -BaseHref: Value passed to `--base-href` (default: '/housekeepr/').
  -Mode: Build mode (release or debug). Default: 'release'.
  -DryRun: Show commands without executing.

This script will use `--dart-define-from-file=.env` so ensure a `.env` file exists
in the project root (or pass a different ProjectPath).
#>

param(
    [string]$ProjectPath = (Get-Location).Path,
    [string]$BaseHref = '/housekeepr/',
    [ValidateSet('release','debug')] [string]$Mode = 'release',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

Push-Location $ProjectPath
try {
    if (-not (Test-Path 'pubspec.yaml')) {
        Write-Error 'pubspec.yaml not found in ProjectPath. Run this from the Flutter project root or pass -ProjectPath.'
        exit 1
    }

    if (-not (Test-Path '.env')) {
        Write-Warning "No .env file found at $ProjectPath. The build will still run but no defines will be provided."
    }

    $pubGetCmd = 'flutter pub get'
    $buildCmd = "flutter build web --$Mode --base-href=$BaseHref --dart-define-from-file=.env"

    if ($DryRun) {
        Write-Host "[DRY RUN] $pubGetCmd"
        Write-Host "[DRY RUN] $buildCmd"
        return
    }

    Write-Host 'Running flutter pub get...' -ForegroundColor Cyan
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }

    Write-Host "Building Flutter web (mode: $Mode) with base-href '$BaseHref'..." -ForegroundColor Cyan
    & flutter build web --$Mode --base-href=$BaseHref --dart-define-from-file=.env
    if ($LASTEXITCODE -ne 0) { throw 'flutter build web failed.' }

    Write-Host 'Flutter web build completed. Output: build/web' -ForegroundColor Green
}
finally {
    Pop-Location
}
