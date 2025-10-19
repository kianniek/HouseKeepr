<#
Load a `.env.local` file in the repository root and export any FIREBASE_* keys
to the current PowerShell environment. This is intended to make local development
convenient without committing credentials.

*** IMPORTANT USAGE NOTE ***
You MUST dot-source this script (prefix with `. `) for the environment
variables to persist in your current session.

Usage (in PowerShell):
  Set-Location (Join-Path $PSScriptRoot '..')
  . .\scripts\set-firebase-env.ps1

The script looks for a file named `.env.local` in the repository root.
Lines beginning with `#` are ignored. Keys and values are split on the first `=`.
Only entries with keys that start with `FIREBASE_` will be exported as environment
variables in the current session.
#>

$scriptDir = $PSScriptRoot
# The repository root is one level up from the script directory.
$repoRoot = Resolve-Path (Join-Path $scriptDir '..')
$envFile = Join-Path $repoRoot '.env'

if (-Not (Test-Path $envFile)) {
    Write-Host "No .env.local file found at $envFile. Create one from .env.local.example and re-run." -ForegroundColor Yellow
    return
}

Write-Host "Loading .env.local from $envFile" -ForegroundColor Cyan

foreach ($raw in Get-Content $envFile) {
    $line = $raw.Trim()
    # Ignore blank lines or comments
    if ($line -eq '' -or $line.StartsWith('#')) { continue }

    # Split on the first '=', max 2 parts
    $split = $line -split '=', 2
    if ($split.Count -lt 2) { continue }
    
    $key = $split[0].Trim()
    $val = $split[1].Trim()

    # Handle values enclosed in single or double quotes
    if (($val.StartsWith("'") -and $val.EndsWith("'")) -or ($val.StartsWith('"') -and $val.EndsWith('"'))) {
        $val = $val.Substring(1, $val.Length - 2)
    }

    if ($key -like 'FIREBASE_*') {
        # CRITICAL FIX: The indentation on these two lines is now standard.
        Write-Host "Setting $key" -ForegroundColor Green
        Set-Item -Path Env:$key -Value $val
    }
} 

Write-Host "Done. Environment variables set in this session." -ForegroundColor Cyan