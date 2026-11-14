# <#
# Builds the release app bundle and, by default, publishes it to the Google Play
# internal test track with a service account key.
# #>

# param(
#     [string]
#     $ProjectPath = (Get-Location).Path,

#     [string]
#     $KeyFile = 'housekeepr-51a2e-fba925fbcf1d.json',

#     [string]
#     $PackageName = 'com.kianhamidi.housekeepr',

#     [string]
#     $AabPath = 'build\app\outputs\bundle\release\app-release.aab',

#     [string]
#     $Track = 'internal',

#     [string]
#     $ReleaseConfigPath = 'scripts\release-config.json',

#     [switch]
#     $SkipPublish,

#     [switch]
#     $PublishOnly
# )

# function Get-StateFilePath {
#     param(
#         [Parameter(Mandatory = $true)] [string]$RepoRoot
#     )

#     return Join-Path $RepoRoot 'scripts\.build_appbundle_state.json'
# }

# function Get-LocalVersionCode {
#     param(
#         [Parameter(Mandatory = $true)] [string]$RepoRoot
#     )

#     $pubspecPath = Join-Path $RepoRoot 'pubspec.yaml'
#     if (-not (Test-Path $pubspecPath)) { return $null }

#     $versionLine = Select-String -Path $pubspecPath -Pattern '^version:\s*[^\s]+$' | Select-Object -First 1
#     if ($null -eq $versionLine) { return $null }

#     if ($versionLine.Line -match '^version:\s*[^+]+\+(\d+)\s*$') {
#         return $matches[1]
#     }

#     return $null
# }

# function Get-PublishState {
#     param(
#         [Parameter(Mandatory = $true)] [string]$RepoRoot
#     )

#     $statePath = Get-StateFilePath -RepoRoot $RepoRoot
#     if (-not (Test-Path $statePath)) { return $null }

#     try {
#         return Get-Content -Path $statePath -Raw | ConvertFrom-Json
#     } catch {
#         return $null
#     }
# }

# function Set-PublishState {
#     param(
#         [Parameter(Mandatory = $true)] [string]$RepoRoot,
#         [Parameter(Mandatory = $true)] [string]$VersionCode,
#         [Parameter(Mandatory = $true)] [string]$Result,
#         [string]$Message = ''
#     )

#     $statePath = Get-StateFilePath -RepoRoot $RepoRoot
#     $state = @{
#         versionCode = $VersionCode
#         result = $Result
#         message = $Message
#         updatedUtc = (Get-Date).ToUniversalTime().ToString('o')
#     }

#     $state | ConvertTo-Json -Depth 4 | Set-Content -Path $statePath -Encoding UTF8
# }

# function Resolve-RepoPath {
#     param(
#         [Parameter(Mandatory = $true)] [string]$Path,
#         [Parameter(Mandatory = $true)] [string]$BasePath
#     )
#     if ([System.IO.Path]::IsPathRooted($Path)) { $candidate = $Path }
#     else { $candidate = Join-Path $BasePath $Path }

#     if (-not $DryRun -and -not (Test-Path $candidate)) { throw "Path not found: $candidate" }
#     return $candidate
# }

# function Get-ReleaseConfig {
#     param(
#         [Parameter(Mandatory = $true)] [string]$RepoRoot,
#         [Parameter(Mandatory = $true)] [string]$ConfigPath
#     )

#     $defaultNotes = @(
#         @{
#             language = 'en-US'
#             text = 'Minor bug fixes and improvements.'
#         }
#     )

#     $resolvedConfigPath = if ([System.IO.Path]::IsPathRooted($ConfigPath)) { $ConfigPath } else { Join-Path $RepoRoot $ConfigPath }
#     if (-not (Test-Path $resolvedConfigPath)) {
#         return @{
#             status = 'completed'
#             nameTemplate = 'Auto-release {versionCode}'
#             releaseNotes = $defaultNotes
#         }
#     }

#     try {
#         $raw = Get-Content -Path $resolvedConfigPath -Raw | ConvertFrom-Json
#     } catch {
#         throw "Invalid release config JSON at: $resolvedConfigPath"
#     }

#     $notes = @()
#     if ($null -ne $raw.releaseNotes) {
#         foreach ($note in $raw.releaseNotes) {
#             if ($null -ne $note -and -not [string]::IsNullOrWhiteSpace($note.language) -and -not [string]::IsNullOrWhiteSpace($note.text)) {
#                 $notes += @{
#                     language = [string]$note.language
#                     text = [string]$note.text
#                 }
#             }
#         }
#     }
#     if ($notes.Count -eq 0) { $notes = $defaultNotes }

#     $status = if (-not [string]::IsNullOrWhiteSpace($raw.status)) { [string]$raw.status } else { 'completed' }
#     $nameTemplate = if (-not [string]::IsNullOrWhiteSpace($raw.nameTemplate)) { [string]$raw.nameTemplate } else { 'Auto-release {versionCode}' }

#     return @{
#         status = $status
#         nameTemplate = $nameTemplate
#         releaseNotes = $notes
#     }
# }

# if ($DryRun) {
#     Write-Host "--- DRY RUN ENABLED ---" -ForegroundColor Yellow
# }

# if (-not $SkipPublish) {
#     $null = Resolve-RepoPath -Path $KeyFile -BasePath $ProjectPath
# }

# if ($PublishOnly) {
#     $null = Resolve-RepoPath -Path $AabPath -BasePath $ProjectPath

#     $localVersionCode = Get-LocalVersionCode -RepoRoot $ProjectPath
#     if ($null -ne $localVersionCode) {
#         $previousState = Get-PublishState -RepoRoot $ProjectPath
#         if ($null -ne $previousState -and $previousState.result -eq 'duplicate-version' -and $previousState.versionCode -eq $localVersionCode) {
#             Write-Warning "Preflight: local versionCode $localVersionCode previously failed with 'already been used'. Consider incrementing version/build number before re-running -PublishOnly."
#         }
#     }
# }

# function Get-ErrorDetails {
#     param(
#         [Parameter(Mandatory = $true)]
#         [System.Management.Automation.ErrorRecord]$ErrorRecord
#     )
#     if ($null -eq $ErrorRecord) { return 'Unknown error' }
#     $exception = $ErrorRecord.Exception
#     if ($null -eq $exception) { return $ErrorRecord.ToString() }

#     if ($null -ne $ErrorRecord.ErrorDetails -and -not [string]::IsNullOrWhiteSpace($ErrorRecord.ErrorDetails.Message)) {
#         return $ErrorRecord.ErrorDetails.Message
#     }

#     $response = $exception.Response
#     if ($null -ne $response) {
#         try {
#             $content = $response.Content
#             if ($null -ne $content) {
#                 $detailsTask = $content.ReadAsStringAsync()
#                 $details = $detailsTask.GetAwaiter().GetResult()
#                 if (-not [string]::IsNullOrWhiteSpace($details)) { return $details }
#             }
#         } catch { }

#         try {
#             if ($response -is [System.Net.HttpWebResponse]) {
#                 $stream = $response.GetResponseStream()
#                 if ($null -ne $stream) {
#                     $reader = New-Object System.IO.StreamReader($stream)
#                     $details = $reader.ReadToEnd()
#                     $reader.Dispose()
#                     $stream.Dispose()
#                     if (-not [string]::IsNullOrWhiteSpace($details)) { return $details }
#                 }
#             }
#         } catch { }
#     }
#     return $exception.Message
# }

# function Invoke-PlayInternalTrackPublish {
#     param(
#         [Parameter(Mandatory = $true)] [string]$RepoRoot,
#         [Parameter(Mandatory = $true)] [string]$KeyFilePath,
#         [Parameter(Mandatory = $true)] [string]$PackageName,
#         [Parameter(Mandatory = $true)] [string]$AabFilePath,
#         [Parameter(Mandatory = $true)] [string]$Track,
#         [Parameter(Mandatory = $true)] [string]$ReleaseConfigPath,
#         [switch]$DryRun
#     )

#     $resolvedKeyFile = Resolve-RepoPath -Path $KeyFilePath -BasePath $RepoRoot
#     $resolvedAabPath = Resolve-RepoPath -Path $AabFilePath -BasePath $RepoRoot

#     if ($DryRun) {
#         Write-Host "[DRY RUN] Simulating API lifecycle..." -ForegroundColor Yellow
#         return
#     }

#     $token = (& gcloud auth print-access-token --scopes="https://www.googleapis.com/auth/androidpublisher").Trim()
#     if ([string]::IsNullOrWhiteSpace($token)) {
#         throw 'Failed to obtain Google access token for Android Publisher API.'
#     }
#     $headers = @{ Authorization = "Bearer $token"; 'Content-Type' = 'application/json' }
#     $baseUrl = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$PackageName/edits"

#     Write-Host 'Creating Play Console edit...' -ForegroundColor Cyan
#     $editId = $null
#     $committed = $false
#     $releaseConfig = Get-ReleaseConfig -RepoRoot $RepoRoot -ConfigPath $ReleaseConfigPath
#     $releaseStatus = [string]$releaseConfig.status
#     $releaseNotes = $releaseConfig.releaseNotes

#     function Set-TrackRelease {
#         param(
#             [Parameter(Mandatory = $true)] [string]$Status,
#             [Parameter(Mandatory = $true)] [string]$TrackUrl,
#             [Parameter(Mandatory = $true)] [hashtable]$Headers,
#             [Parameter(Mandatory = $true)] [string]$VersionCode,
#             [Parameter(Mandatory = $true)] [string]$ReleaseName,
#             [Parameter(Mandatory = $true)] [object[]]$ReleaseNotes
#         )

#         $trackBody = @{
#             releases = @(
#                 @{
#                     versionCodes = @($VersionCode);
#                     status = $Status;
#                     name = $ReleaseName;
#                     releaseNotes = $ReleaseNotes
#                 }
#             )
#         } | ConvertTo-Json -Depth 5

#         Invoke-RestMethod -Uri $TrackUrl -Method Put -Headers $Headers -Body $trackBody | Out-Null
#     }

#     try {
#         try {
#             $editResponse = Invoke-RestMethod -Uri $baseUrl -Method Post -Headers $headers
#             $editId = $editResponse.id
#         } catch {
#             $details = Get-ErrorDetails -ErrorRecord $_
#             Write-Error "Google API Error (create edit): $details"
#             throw $_
#         }

#         Write-Host "Uploading app bundle from $resolvedAabPath..." -ForegroundColor Cyan
#         $uploadUrl = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/$PackageName/edits/$editId/bundles?uploadType=media"

#         try {
#             [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
#             Add-Type -AssemblyName System.Net.Http

#             $httpClient = New-Object System.Net.Http.HttpClient
#             $httpClient.Timeout = [TimeSpan]::FromMinutes(10)
#             $httpClient.DefaultRequestHeaders.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", $token)

#             $fileStream = [System.IO.File]::OpenRead($resolvedAabPath)
#             try {
#                 $streamContent = New-Object System.Net.Http.StreamContent($fileStream)
#                 $streamContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/octet-stream")

#                 $response = $httpClient.PostAsync($uploadUrl, $streamContent).GetAwaiter().GetResult()
#                 $responseBody = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()

#                 if (-not $response.IsSuccessStatusCode) {
#                     throw "HTTP $([int]$response.StatusCode) ($($response.ReasonPhrase)): $responseBody"
#                 }

#                 $uploadResponse = $responseBody | ConvertFrom-Json
#             }
#             finally {
#                 $fileStream.Dispose()
#                 $httpClient.Dispose()
#             }
#         } catch {
#             $details = Get-ErrorDetails -ErrorRecord $_
#             if ($details -match 'Version code\s+\d+\s+has already been used') {
#                 $duplicateVersionCode = $null
#                 if ($details -match 'Version code\s+(\d+)\s+has already been used') {
#                     $duplicateVersionCode = $matches[1]
#                 }
#                 if (-not [string]::IsNullOrWhiteSpace($duplicateVersionCode)) {
#                     Set-PublishState -RepoRoot $RepoRoot -VersionCode $duplicateVersionCode -Result 'duplicate-version' -Message 'Google Play rejected upload because this versionCode already exists.'
#                 }
#                 Write-Error "Google API Error (upload bundle): $details`nGuidance: This AAB's versionCode is already published in Play Console. Build a new bundle with a higher versionCode (run '.\\scripts\\build_appbundle.ps1' without -PublishOnly), or provide -AabPath to a newer AAB before retrying -PublishOnly."
#             }
#             else {
#                 Write-Error "Google API Error (upload bundle): $details"
#             }
#             throw
#         }

#         $versionCode = $uploadResponse.versionCode
#         $releaseName = ([string]$releaseConfig.nameTemplate) -replace '\{versionCode\}', [string]$versionCode
#         Write-Host "Assigning version $versionCode to track '$Track'..." -ForegroundColor Cyan
#         $trackUrl = "$baseUrl/$editId/tracks/$Track"
#         try {
#             Set-TrackRelease -Status $releaseStatus -TrackUrl $trackUrl -Headers $headers -VersionCode $versionCode -ReleaseName $releaseName -ReleaseNotes $releaseNotes
#         } catch {
#             $details = Get-ErrorDetails -ErrorRecord $_
#             Write-Error "Google API Error (update track '$Track'): $details"
#             throw
#         }

#         Write-Host 'Committing edit...' -ForegroundColor Cyan
#         try {
#             Invoke-RestMethod -Uri "$baseUrl/${editId}:commit" -Method Post -Headers $headers | Out-Null
#         } catch {
#             $details = Get-ErrorDetails -ErrorRecord $_

#             if ($details -match 'Only releases with status draft may be created on draft app' -and $releaseStatus -ne 'draft') {
#                 Write-Host "Commit rejected for status '$releaseStatus'. Retrying with release status 'draft' for draft app..." -ForegroundColor Yellow
#                 $releaseStatus = 'draft'

#                 try {
#                     Set-TrackRelease -Status $releaseStatus -TrackUrl $trackUrl -Headers $headers -VersionCode $versionCode -ReleaseName $releaseName -ReleaseNotes $releaseNotes
#                 } catch {
#                     $retryTrackDetails = Get-ErrorDetails -ErrorRecord $_
#                     Write-Error "Google API Error (update track '$Track' retry as 'draft'): $retryTrackDetails"
#                     throw
#                 }

#                 try {
#                     Invoke-RestMethod -Uri "$baseUrl/${editId}:commit" -Method Post -Headers $headers | Out-Null
#                 } catch {
#                     $retryCommitDetails = Get-ErrorDetails -ErrorRecord $_
#                     Write-Error "Google API Error (commit edit '$editId' retry as 'draft'): $retryCommitDetails"
#                     throw
#                 }
#             }
#             else {
#                 Write-Error "Google API Error (commit edit '$editId'): $details"
#                 throw
#             }
#         }
#         $committed = $true
#         Set-PublishState -RepoRoot $RepoRoot -VersionCode ([string]$versionCode) -Result 'success' -Message "Published to track '$Track' with status '$releaseStatus'."
#     }
#     finally {
#         if (-not $committed -and -not [string]::IsNullOrWhiteSpace($editId)) {
#             Write-Host "Cleaning up uncommitted edit $editId..." -ForegroundColor Yellow
#             try { Invoke-RestMethod -Uri "$baseUrl/$editId" -Method Delete -Headers $headers | Out-Null } catch { }
#         }
#     }
#     Write-Host "Upload successful. Version $versionCode is now in the $Track track (status: $releaseStatus)." -ForegroundColor Green
#     Write-Host "Go to Play Console to review and promote to production: https://play.google.com/console/u/0/developers/8646365400814343333/app/4972211643642403605/tracks/internal-testing" -ForegroundColor Cyan
# }

# Push-Location $ProjectPath
# try {
#     # --- PRE-BUILD PERMISSION CHECK ---
#     if (-not $SkipPublish -and -not $DryRun) {
#         Write-Host "Verifying Google Play API permissions before starting build..." -ForegroundColor Cyan
        
#         $resolvedKey = Resolve-RepoPath -Path $KeyFile -BasePath $ProjectPath
#         & gcloud auth activate-service-account --key-file="$resolvedKey" | Out-Null
        
#         $token = (& gcloud auth print-access-token --scopes="https://www.googleapis.com/auth/androidpublisher").Trim()
#         if ([string]::IsNullOrWhiteSpace($token)) {
#             throw 'Failed to obtain Google access token for Android Publisher API.'
#         }
#         $headers = @{ Authorization = "Bearer $token"; 'Content-Type' = 'application/json' }
        
#         try {
#             $appCheckUrl = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$PackageName/edits"
#             $appEdit = Invoke-RestMethod -Uri $appCheckUrl -Method Post -Headers $headers
#             Write-Host "Permission Check Passed: Successfully created edit session $($appEdit.id)" -ForegroundColor Green
            
#             # Clean up the test edit session immediately
#             Invoke-RestMethod -Uri "$appCheckUrl/$($appEdit.id)" -Method Delete -Headers $headers | Out-Null
#         } catch {
#             $details = Get-ErrorDetails -ErrorRecord $_
#             Write-Host "FATAL: Service account cannot access this app package." -ForegroundColor Red
#             Write-Host "Error Details: $details" -ForegroundColor Gray
#             exit 1
#         }
#     }

#     if ($DryRun) {
#         Write-Host "[DRY RUN] Skipping Flutter Build..." -ForegroundColor Yellow
#     }
#     elseif ($PublishOnly) {
#         Write-Host "PublishOnly mode: skipping build and using existing AAB at $AabPath" -ForegroundColor Cyan
#     }
#     else {
#         Write-Host "Incrementing version..." -ForegroundColor Cyan
#         & pubversion patch
#         if ($LASTEXITCODE -ne 0) { throw 'pubversion patch failed.' }
        
#         Start-Sleep -Seconds 1
        
#         Write-Host "Building Flutter App Bundle..." -ForegroundColor Cyan
#         & flutter build appbundle --release --obfuscate --split-debug-info=./debug_info --dart-define-from-file=.env
#         if ($LASTEXITCODE -ne 0) { throw 'flutter build appbundle failed.' }
#     }

#     if (-not $SkipPublish) {
#         Invoke-PlayInternalTrackPublish `
#             -RepoRoot $ProjectPath `
#             -KeyFilePath $KeyFile `
#             -PackageName $PackageName `
#             -AabFilePath $AabPath `
#             -Track $Track `
#             -ReleaseConfigPath $ReleaseConfigPath `
#             -DryRun:$DryRun
#     }
# }
# finally {
#     Pop-Location
# }
<#
.SYNOPSIS
    Builds the release app bundle and publishes it to the Google Play internal test track.

.EXAMPLE
    # Build and publish to the default 'internal' track
    C:\Users\kiann\Documents\CodingProjects\HouseKeepr\scripts\build_and_deploy_appbundle.ps1

.EXAMPLE
    # Skip build (publish existing AAB only)
    C:\Users\kiann\Documents\CodingProjects\HouseKeepr\scripts\build_and_deploy_appbundle.ps1 -PublishOnly

.EXAMPLE
    # Skip publish (build AAB only)
    C:\Users\kiann\Documents\CodingProjects\HouseKeepr\scripts\build_and_deploy_appbundle.ps1 -SkipPublish

.EXAMPLE
    # Simulate execution without building or uploading
    C:\Users\kiann\Documents\CodingProjects\HouseKeepr\scripts\build_and_deploy_appbundle.ps1 -DryRun

.EXAMPLE
    # Publish to a different Play Console track (e.g., alpha, beta, production)
    C:\Users\kiann\Documents\CodingProjects\HouseKeepr\scripts\build_and_deploy_appbundle.ps1 -Track alpha

.EXAMPLE
    # Publish a specific AAB file directly without rebuilding
    C:\Users\kiann\Documents\CodingProjects\HouseKeepr\scripts\build_and_deploy_appbundle.ps1 -PublishOnly -AabPath "build\app\outputs\bundle\release\app-release.aab"

.EXAMPLE
    # Run from outside the repository root with custom key and config paths
    C:\Users\kiann\Documents\CodingProjects\HouseKeepr\scripts\build_and_deploy_appbundle.ps1 -ProjectPath "C:\Users\kiann\Documents\CodingProjects\HouseKeepr" -KeyFile "my-service-account.json" -ReleaseConfigPath "scripts\release-config.json"
#>

<#
.SYNOPSIS
    Builds the release app bundle and publishes it to the Google Play internal test track.

.EXAMPLE
    # Build and publish to the default 'internal' track
    C:\Users\kiann\Documents\CodingProjects\HouseKeepr\scripts\build_and_deploy_appbundle.ps1

.EXAMPLE
    # Skip build (publish existing AAB only)
    C:\Users\kiann\Documents\CodingProjects\HouseKeepr\scripts\build_and_deploy_appbundle.ps1 -PublishOnly

.EXAMPLE
    # Skip publish (build AAB only)
    C:\Users\kiann\Documents\CodingProjects\HouseKeepr\scripts\build_and_deploy_appbundle.ps1 -SkipPublish

.EXAMPLE
    # Simulate execution without building or uploading
    C:\Users\kiann\Documents\CodingProjects\HouseKeepr\scripts\build_and_deploy_appbundle.ps1 -DryRun

.EXAMPLE
    # Publish to a different Play Console track (e.g., alpha, beta, production)
    C:\Users\kiann\Documents\CodingProjects\HouseKeepr\scripts\build_and_deploy_appbundle.ps1 -Track alpha

.EXAMPLE
    # Publish a specific AAB file directly without rebuilding
    C:\Users\kiann\Documents\CodingProjects\HouseKeepr\scripts\build_and_deploy_appbundle.ps1 -PublishOnly -AabPath "build\app\outputs\bundle\release\app-release.aab"

.EXAMPLE
    # Run from outside the repository root with custom key and config paths
    C:\Users\kiann\Documents\CodingProjects\HouseKeepr\scripts\build_and_deploy_appbundle.ps1 -ProjectPath "C:\Users\kiann\Documents\CodingProjects\HouseKeepr" -KeyFile "my-service-account.json" -ReleaseConfigPath "scripts\release-config.json"
#>

param(
    [string]
    $ProjectPath = (Get-Location).Path,

    [string]
    $KeyFile = 'housekeepr-51a2e-fba925fbcf1d.json',

    [string]
    $PackageName = 'com.kianhamidi.housekeepr',

    [string]
    $AabPath = 'build\app\outputs\bundle\release\app-release.aab',

    [string]
    $Track = 'internal',

    [string]
    $ReleaseConfigPath = 'scripts\release-config.json',

    [switch]
    $SkipPublish,

    [switch]
    $PublishOnly,

    [switch]
    $DryRun
)

# Ensure UTF-8 console output and encoding-safe symbols across PS 5.1 and PS 7+
$ESC = [char]27
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$SYM_OK      = [string][char]0x2714 # ✔
$SYM_FAIL    = [string][char]0x2716 # ✖
$SYM_WARN    = [string][char]0x26A0 # ⚠
$SYM_INFO    = [string][char]0x2139 # ℹ
$SYM_UP      = [string][char]0x2191 # ↑
$SYM_BLOCK   = [string][char]0x2588 # █
$SYM_SHADE   = [string][char]0x2591 # ░
$SPINNER_FRAMES = @(
    ([string][char]0x280B), ([string][char]0x2819), ([string][char]0x2839),
    ([string][char]0x2838), ([string][char]0x283C), ([string][char]0x2834),
    ([string][char]0x2826), ([string][char]0x2827), ([string][char]0x2807),
    ([string][char]0x280F)
)

# ==============================================================================
# TERMINAL UI & PROCESS HELPERS
# ==============================================================================

function Write-StepStatus {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('ok', 'fail', 'warn', 'info')]
        [string]$State,
        [Parameter(Mandatory = $true)] [string]$Message,
        [string]$Detail = ''
    )

    $icon = switch ($State) {
        'ok'   { "${ESC}[32m${SYM_OK}${ESC}[0m" }
        'fail' { "${ESC}[31m${SYM_FAIL}${ESC}[0m" }
        'warn' { "${ESC}[33m${SYM_WARN}${ESC}[0m" }
        'info' { "${ESC}[36m${SYM_INFO}${ESC}[0m" }
    }
    $suffix = if (-not [string]::IsNullOrWhiteSpace($Detail)) { " ${ESC}[90m($Detail)${ESC}[0m" } else { '' }
    [Console]::Write("`r${ESC}[2K$icon $Message$suffix`n")
}

function Invoke-StepWithSpinner {
    param(
        [Parameter(Mandatory = $true)] [string]$Title,
        [Parameter(Mandatory = $true)] [string]$FilePath,
        [string[]]$ArgumentList = @(),
        [string]$WorkingDirectory = (Get-Location).Path
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $cmd = Get-Command $FilePath -ErrorAction Stop
    $resolvedSource = $cmd.Source
    $ext = [System.IO.Path]::GetExtension($resolvedSource).ToLowerInvariant()

    $formattedArgs = ($ArgumentList | ForEach-Object {
        if ($_ -match '\s') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
    }) -join ' '

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    if ($ext -eq '.ps1') {
        $psi.FileName = (Get-Process -Id $PID).Path
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$resolvedSource`" $formattedArgs"
    }
    elseif ($ext -in @('.cmd', '.bat')) {
        $psi.FileName = 'cmd.exe'
        $psi.Arguments = "/c `"`"$resolvedSource`" $formattedArgs`""
    }
    else {
        $psi.FileName = $resolvedSource
        $psi.Arguments = $formattedArgs
    }

    $psi.WorkingDirectory = $WorkingDirectory
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi

    $outBuilder = New-Object System.Text.StringBuilder
    $errBuilder = New-Object System.Text.StringBuilder

    $outEvent = Register-ObjectEvent -InputObject $proc -EventName OutputDataReceived -Action {
        if ($null -ne $EventArgs.Data) { [void]$Event.MessageData.AppendLine($EventArgs.Data) }
    } -MessageData $outBuilder

    $errEvent = Register-ObjectEvent -InputObject $proc -EventName ErrorDataReceived -Action {
        if ($null -ne $EventArgs.Data) { [void]$Event.MessageData.AppendLine($EventArgs.Data) }
    } -MessageData $errBuilder

    [Console]::Write("${ESC}[?25l")
    try {
        [void]$proc.Start()
        $proc.BeginOutputReadLine()
        $proc.BeginErrorReadLine()

        $i = 0
        while (-not $proc.WaitForExit(80)) {
            $frame = $SPINNER_FRAMES[$i % $SPINNER_FRAMES.Count]
            $elapsed = "{0:mm\:ss}" -f $sw.Elapsed
            [Console]::Write("`r${ESC}[2K${ESC}[36m$frame${ESC}[0m $Title ${ESC}[90m[$elapsed]${ESC}[0m")
            $i++
        }
        $proc.WaitForExit()
    }
    finally {
        [Console]::Write("${ESC}[?25h")
        Unregister-Event -SourceIdentifier $outEvent.Name -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier $errEvent.Name -ErrorAction SilentlyContinue
    }

    $sw.Stop()
    $elapsedFinal = "{0:mm\:ss}" -f $sw.Elapsed

    if ($proc.ExitCode -eq 0) {
        Write-StepStatus -State 'ok' -Message $Title -Detail $elapsedFinal
        return $outBuilder.ToString()
    }
    else {
        Write-StepStatus -State 'fail' -Message "$Title (Exit code $($proc.ExitCode))" -Detail $elapsedFinal
        $combinedLogs = ($outBuilder.ToString() + "`n" + $errBuilder.ToString()).Trim()
        if (-not [string]::IsNullOrWhiteSpace($combinedLogs)) {
            Write-Host "`n${ESC}[31m--- Captured Output ($Title) ---${ESC}[0m"
            Write-Host $combinedLogs -ForegroundColor Gray
            Write-Host "${ESC}[31m--------------------------------${ESC}[0m`n"
        }
        throw "$Title failed with exit code $($proc.ExitCode)."
    }
}

function Invoke-ActionWithSpinner {
    param(
        [Parameter(Mandatory = $true)] [string]$Title,
        [Parameter(Mandatory = $true)] [scriptblock]$Action,
        [hashtable]$Variables = @{}
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $ps = [powershell]::Create()
    foreach ($key in $Variables.Keys) {
        [void]$ps.Runspace.SessionStateProxy.SetVariable($key, $Variables[$key])
    }
    [void]$ps.AddScript($Action)
    $asyncResult = $ps.BeginInvoke()

    [Console]::Write("${ESC}[?25l")
    try {
        $i = 0
        while (-not $asyncResult.IsCompleted) {
            $frame = $SPINNER_FRAMES[$i % $SPINNER_FRAMES.Count]
            $elapsed = "{0:mm\:ss}" -f $sw.Elapsed
            [Console]::Write("`r${ESC}[2K${ESC}[36m$frame${ESC}[0m $Title ${ESC}[90m[$elapsed]${ESC}[0m")
            Start-Sleep -Milliseconds 80
            $i++
        }

        $result = $ps.EndInvoke($asyncResult)
        if ($ps.HadErrors) {
            throw $ps.Streams.Error[0]
        }

        $sw.Stop()
        Write-StepStatus -State 'ok' -Message $Title -Detail ("{0:mm\:ss}" -f $sw.Elapsed)
        return $result
    }
    catch {
        $sw.Stop()
        Write-StepStatus -State 'fail' -Message $Title -Detail ("{0:mm\:ss}" -f $sw.Elapsed)
        throw
    }
    finally {
        [Console]::Write("${ESC}[?25h")
        $ps.Dispose()
    }
}

function Send-AabWithProgress {
    param(
        [Parameter(Mandatory = $true)] [string]$UploadUrl,
        [Parameter(Mandatory = $true)] [string]$FilePath,
        [Parameter(Mandatory = $true)] [string]$Token
    )

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Add-Type -AssemblyName System.Net.Http

    $fileInfo = Get-Item -Path $FilePath
    $totalBytes = $fileInfo.Length
    $totalMB = [math]::Round($totalBytes / 1MB, 1)

    $httpClient = New-Object System.Net.Http.HttpClient
    $httpClient.Timeout = [TimeSpan]::FromMinutes(10)
    $httpClient.DefaultRequestHeaders.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", $Token)

    $fileStream = [System.IO.File]::OpenRead($FilePath)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    [Console]::Write("${ESC}[?25l")
    try {
        $streamContent = New-Object System.Net.Http.StreamContent($fileStream)
        $streamContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/octet-stream")

        $uploadTask = $httpClient.PostAsync($UploadUrl, $streamContent)

        $barWidth = 28
        while (-not $uploadTask.Wait(80)) {
            $sentBytes = $fileStream.Position
            $pct = if ($totalBytes -gt 0) { [math]::Min(100, [math]::Floor(($sentBytes / $totalBytes) * 100)) } else { 0 }
            $filled = [math]::Floor(($pct / 100) * $barWidth)
            $empty = $barWidth - $filled
            $bar = ($SYM_BLOCK * $filled) + ($SYM_SHADE * $empty)
            $sentMB = "{0:N1}" -f ($sentBytes / 1MB)

            $statusText = if ($pct -ge 100) { "Finalizing on Google Play..." } else { "$sentMB / $totalMB MB" }
            [Console]::Write("`r${ESC}[2K${ESC}[36m${SYM_UP}${ESC}[0m Uploading AAB [${ESC}[36m$bar${ESC}[0m] $pct% ${ESC}[90m($statusText)${ESC}[0m")
        }

        $response = $uploadTask.GetAwaiter().GetResult()
        $responseBody = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()

        if (-not $response.IsSuccessStatusCode) {
            Write-StepStatus -State 'fail' -Message "Uploading AAB ($totalMB MB)" -Detail ("{0:mm\:ss}" -f $sw.Elapsed)
            throw "HTTP $([int]$response.StatusCode) ($($response.ReasonPhrase)): $responseBody"
        }

        Write-StepStatus -State 'ok' -Message "Uploaded AAB ($totalMB MB)" -Detail ("{0:mm\:ss}" -f $sw.Elapsed)
        return ($responseBody | ConvertFrom-Json)
    }
    finally {
        [Console]::Write("${ESC}[?25h")
        $fileStream.Dispose()
        $httpClient.Dispose()
    }
}

# ==============================================================================
# STATE, CONFIG & PATH HELPERS
# ==============================================================================

function Get-StateFilePath {
    param(
        [Parameter(Mandatory = $true)] [string]$RepoRoot
    )

    return Join-Path $RepoRoot 'scripts\.build_appbundle_state.json'
}

function Get-LocalVersionCode {
    param(
        [Parameter(Mandatory = $true)] [string]$RepoRoot
    )

    $pubspecPath = Join-Path $RepoRoot 'pubspec.yaml'
    if (-not (Test-Path $pubspecPath)) { return $null }

    $versionLine = Select-String -Path $pubspecPath -Pattern '^version:\s*[^\s]+$' | Select-Object -First 1
    if ($null -eq $versionLine) { return $null }

    if ($versionLine.Line -match '^version:\s*[^+]+\+(\d+)\s*$') {
        return $matches[1]
    }

    return $null
}

function Get-PublishState {
    param(
        [Parameter(Mandatory = $true)] [string]$RepoRoot
    )

    $statePath = Get-StateFilePath -RepoRoot $RepoRoot
    if (-not (Test-Path $statePath)) { return $null }

    try {
        return Get-Content -Path $statePath -Raw | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Set-PublishState {
    param(
        [Parameter(Mandatory = $true)] [string]$RepoRoot,
        [Parameter(Mandatory = $true)] [string]$VersionCode,
        [Parameter(Mandatory = $true)] [string]$Result,
        [string]$Message = ''
    )

    $statePath = Get-StateFilePath -RepoRoot $RepoRoot
    $state = @{
        versionCode = $VersionCode
        result = $Result
        message = $Message
        updatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    }

    $state | ConvertTo-Json -Depth 4 | Set-Content -Path $statePath -Encoding UTF8
}

function Resolve-RepoPath {
    param(
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $true)] [string]$BasePath
    )
    if ([System.IO.Path]::IsPathRooted($Path)) { $candidate = $Path }
    else { $candidate = Join-Path $BasePath $Path }

    if (-not $DryRun -and -not (Test-Path $candidate)) { throw "Path not found: $candidate" }
    return $candidate
}

function Get-ReleaseConfig {
    param(
        [Parameter(Mandatory = $true)] [string]$RepoRoot,
        [Parameter(Mandatory = $true)] [string]$ConfigPath
    )

    $defaultNotes = @(
        @{
            language = 'en-US'
            text = 'Minor bug fixes and improvements.'
        }
    )

    $resolvedConfigPath = if ([System.IO.Path]::IsPathRooted($ConfigPath)) { $ConfigPath } else { Join-Path $RepoRoot $ConfigPath }
    if (-not (Test-Path $resolvedConfigPath)) {
        return @{
            status = 'completed'
            nameTemplate = 'Auto-release {versionCode}'
            releaseNotes = $defaultNotes
        }
    }

    try {
        $raw = Get-Content -Path $resolvedConfigPath -Raw | ConvertFrom-Json
    } catch {
        throw "Invalid release config JSON at: $resolvedConfigPath"
    }

    $notes = @()
    if ($null -ne $raw.releaseNotes) {
        foreach ($note in $raw.releaseNotes) {
            if ($null -ne $note -and -not [string]::IsNullOrWhiteSpace($note.language) -and -not [string]::IsNullOrWhiteSpace($note.text)) {
                $notes += @{
                    language = [string]$note.language
                    text = [string]$note.text
                }
            }
        }
    }
    if ($notes.Count -eq 0) { $notes = $defaultNotes }

    $status = if (-not [string]::IsNullOrWhiteSpace($raw.status)) { [string]$raw.status } else { 'completed' }
    $nameTemplate = if (-not [string]::IsNullOrWhiteSpace($raw.nameTemplate)) { [string]$raw.nameTemplate } else { 'Auto-release {versionCode}' }

    return @{
        status = $status
        nameTemplate = $nameTemplate
        releaseNotes = $notes
    }
}

function Get-ErrorDetails {
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    if ($null -eq $ErrorRecord) { return 'Unknown error' }
    $exception = $ErrorRecord.Exception
    if ($null -eq $exception) { return $ErrorRecord.ToString() }

    if ($null -ne $ErrorRecord.ErrorDetails -and -not [string]::IsNullOrWhiteSpace($ErrorRecord.ErrorDetails.Message)) {
        return $ErrorRecord.ErrorDetails.Message
    }

    $response = $exception.Response
    if ($null -ne $response) {
        try {
            $content = $response.Content
            if ($null -ne $content) {
                $detailsTask = $content.ReadAsStringAsync()
                $details = $detailsTask.GetAwaiter().GetResult()
                if (-not [string]::IsNullOrWhiteSpace($details)) { return $details }
            }
        } catch { }

        try {
            if ($response -is [System.Net.HttpWebResponse]) {
                $stream = $response.GetResponseStream()
                if ($null -ne $stream) {
                    $reader = New-Object System.IO.StreamReader($stream)
                    $details = $reader.ReadToEnd()
                    $reader.Dispose()
                    $stream.Dispose()
                    if (-not [string]::IsNullOrWhiteSpace($details)) { return $details }
                }
            }
        } catch { }
    }
    return $exception.Message
}

# ==============================================================================
# GOOGLE PLAY PUBLISH WORKFLOW
# ==============================================================================

function Invoke-PlayInternalTrackPublish {
    param(
        [Parameter(Mandatory = $true)] [string]$RepoRoot,
        [Parameter(Mandatory = $true)] [string]$KeyFilePath,
        [Parameter(Mandatory = $true)] [string]$PackageName,
        [Parameter(Mandatory = $true)] [string]$AabFilePath,
        [Parameter(Mandatory = $true)] [string]$Track,
        [Parameter(Mandatory = $true)] [string]$ReleaseConfigPath,
        [string]$AccessToken = '',
        [switch]$DryRun
    )

    $null = Resolve-RepoPath -Path $KeyFilePath -BasePath $RepoRoot
    $resolvedAabPath = Resolve-RepoPath -Path $AabFilePath -BasePath $RepoRoot

    if ($DryRun) {
        Write-StepStatus -State 'warn' -Message "Simulating Play Console API lifecycle (Dry Run)"
        return
    }

    $token = $AccessToken
    if ([string]::IsNullOrWhiteSpace($token)) {
        $token = (Invoke-StepWithSpinner -Title "Fetching Google Play access token" -FilePath "gcloud" -ArgumentList @("auth", "print-access-token", "--scopes=https://www.googleapis.com/auth/androidpublisher")).Trim()
    }
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw 'Failed to obtain Google access token for Android Publisher API.'
    }

    $headers = @{ Authorization = "Bearer $token"; 'Content-Type' = 'application/json' }
    $baseUrl = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$PackageName/edits"

    $editId = $null
    $committed = $false
    $releaseConfig = Get-ReleaseConfig -RepoRoot $RepoRoot -ConfigPath $ReleaseConfigPath
    $releaseStatus = [string]$releaseConfig.status
    $releaseNotes = $releaseConfig.releaseNotes

    $setTrackReleaseScript = {
        param([string]$Status, [string]$TrackUrl, [hashtable]$Headers, [string]$VersionCode, [string]$ReleaseName, [object[]]$ReleaseNotes)

        $trackBody = @{
            releases = @(
                @{
                    versionCodes = @($VersionCode)
                    status = $Status
                    name = $ReleaseName
                    releaseNotes = $ReleaseNotes
                }
            )
        } | ConvertTo-Json -Depth 5

        Invoke-RestMethod -Uri $TrackUrl -Method Put -Headers $Headers -Body $trackBody | Out-Null
    }

    try {
        try {
            $editResponse = Invoke-ActionWithSpinner -Title "Creating Play Console edit" -Variables @{
                baseUrl = $baseUrl
                headers = $headers
            } -Action {
                Invoke-RestMethod -Uri $baseUrl -Method Post -Headers $headers
            }
            $editId = $editResponse.id
        } catch {
            $details = Get-ErrorDetails -ErrorRecord $_
            Write-Error "Google API Error (create edit): $details"
            throw
        }

        $uploadUrl = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/$PackageName/edits/$editId/bundles?uploadType=media"

        try {
            $uploadResponse = Send-AabWithProgress -UploadUrl $uploadUrl -FilePath $resolvedAabPath -Token $token
        } catch {
            $details = Get-ErrorDetails -ErrorRecord $_
            if ($details -match 'Version code\s+\d+\s+has already been used') {
                $duplicateVersionCode = $null
                if ($details -match 'Version code\s+(\d+)\s+has already been used') {
                    $duplicateVersionCode = $matches[1]
                }
                if (-not [string]::IsNullOrWhiteSpace($duplicateVersionCode)) {
                    Set-PublishState -RepoRoot $RepoRoot -VersionCode $duplicateVersionCode -Result 'duplicate-version' -Message 'Google Play rejected upload because this versionCode already exists.'
                }
                Write-Error "Google API Error (upload bundle): $details`nGuidance: This AAB's versionCode is already published in Play Console. Build a new bundle with a higher versionCode (run without -PublishOnly), or provide -AabPath to a newer AAB before retrying -PublishOnly."
            }
            else {
                Write-Error "Google API Error (upload bundle): $details"
            }
            throw
        }

        $versionCode = [string]$uploadResponse.versionCode
        $releaseName = ([string]$releaseConfig.nameTemplate) -replace '\{versionCode\}', $versionCode
        $trackUrl = "$baseUrl/$editId/tracks/$Track"

        try {
            Invoke-ActionWithSpinner -Title "Assigning version $versionCode to '$Track' track" -Variables @{
                fn = $setTrackReleaseScript
                status = $releaseStatus
                trackUrl = $trackUrl
                headers = $headers
                versionCode = $versionCode
                releaseName = $releaseName
                releaseNotes = $releaseNotes
            } -Action {
                & $fn -Status $status -TrackUrl $trackUrl -Headers $headers -VersionCode $versionCode -ReleaseName $releaseName -ReleaseNotes $releaseNotes
            }
        } catch {
            $details = Get-ErrorDetails -ErrorRecord $_
            Write-Error "Google API Error (update track '$Track'): $details"
            throw
        }

        try {
            Invoke-ActionWithSpinner -Title "Committing Play Console edit" -Variables @{
                commitUrl = "$baseUrl/${editId}:commit"
                headers = $headers
            } -Action {
                Invoke-RestMethod -Uri $commitUrl -Method Post -Headers $headers | Out-Null
            }
        } catch {
            $details = Get-ErrorDetails -ErrorRecord $_

            if ($details -match 'Only releases with status draft may be created on draft app' -and $releaseStatus -ne 'draft') {
                Write-StepStatus -State 'warn' -Message "App is in draft state; retrying release with status 'draft'"
                $releaseStatus = 'draft'

                try {
                    Invoke-ActionWithSpinner -Title "Assigning version $versionCode as draft" -Variables @{
                        fn = $setTrackReleaseScript
                        status = $releaseStatus
                        trackUrl = $trackUrl
                        headers = $headers
                        versionCode = $versionCode
                        releaseName = $releaseName
                        releaseNotes = $releaseNotes
                    } -Action {
                        & $fn -Status $status -TrackUrl $trackUrl -Headers $headers -VersionCode $versionCode -ReleaseName $releaseName -ReleaseNotes $releaseNotes
                    }
                } catch {
                    $retryTrackDetails = Get-ErrorDetails -ErrorRecord $_
                    Write-Error "Google API Error (update track '$Track' retry as 'draft'): $retryTrackDetails"
                    throw
                }

                try {
                    Invoke-ActionWithSpinner -Title "Committing draft edit" -Variables @{
                        commitUrl = "$baseUrl/${editId}:commit"
                        headers = $headers
                    } -Action {
                        Invoke-RestMethod -Uri $commitUrl -Method Post -Headers $headers | Out-Null
                    }
                } catch {
                    $retryCommitDetails = Get-ErrorDetails -ErrorRecord $_
                    Write-Error "Google API Error (commit edit '$editId' retry as 'draft'): $retryCommitDetails"
                    throw
                }
            }
            else {
                Write-Error "Google API Error (commit edit '$editId'): $details"
                throw
            }
        }

        $committed = $true
        Set-PublishState -RepoRoot $RepoRoot -VersionCode $versionCode -Result 'success' -Message "Published to track '$Track' with status '$releaseStatus'."
    }
    finally {
        if (-not $committed -and -not [string]::IsNullOrWhiteSpace($editId)) {
            try {
                Invoke-ActionWithSpinner -Title "Cleaning up uncommitted edit ($editId)" -Variables @{
                    deleteUrl = "$baseUrl/$editId"
                    headers = $headers
                } -Action {
                    Invoke-RestMethod -Uri $deleteUrl -Method Delete -Headers $headers | Out-Null
                }
            } catch { }
        }
    }

    Write-Host ""
    Write-Host "${ESC}[32m${SYM_OK} Version $versionCode is live on '$Track' (status: $releaseStatus)!${ESC}[0m"
    Write-Host "   ${ESC}[36mhttps://play.google.com/console/u/0/developers/8646365400814343333/app/4972211643642403605/tracks/internal-testing${ESC}[0m`n"
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

$pipelineStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-Host "`n${ESC}[1mHousekeepr Build & Deploy Pipeline${ESC}[0m`n"

if ($DryRun) {
    Write-StepStatus -State 'warn' -Message "DRY RUN ENABLED"
}

if (-not $SkipPublish) {
    $null = Resolve-RepoPath -Path $KeyFile -BasePath $ProjectPath
}

if ($PublishOnly) {
    $null = Resolve-RepoPath -Path $AabPath -BasePath $ProjectPath

    $localVersionCode = Get-LocalVersionCode -RepoRoot $ProjectPath
    if ($null -ne $localVersionCode) {
        $previousState = Get-PublishState -RepoRoot $ProjectPath
        if ($null -ne $previousState -and $previousState.result -eq 'duplicate-version' -and $previousState.versionCode -eq $localVersionCode) {
            Write-StepStatus -State 'warn' -Message "Preflight: local versionCode $localVersionCode previously failed with 'already been used'. Consider incrementing version/build number before re-running -PublishOnly."
        }
    }
}

Push-Location $ProjectPath
try {
    $cachedAccessToken = ''

    # --- PRE-BUILD PERMISSION CHECK ---
    if (-not $SkipPublish -and -not $DryRun) {
        $resolvedKey = Resolve-RepoPath -Path $KeyFile -BasePath $ProjectPath

        $null = Invoke-StepWithSpinner -Title "Activating service account" -FilePath "gcloud" -ArgumentList @(
            "auth", "activate-service-account", "--key-file=$resolvedKey"
        )

        $cachedAccessToken = (Invoke-StepWithSpinner -Title "Fetching Google Play access token" -FilePath "gcloud" -ArgumentList @(
            "auth", "print-access-token", "--scopes=https://www.googleapis.com/auth/androidpublisher"
        )).Trim()

        if ([string]::IsNullOrWhiteSpace($cachedAccessToken)) {
            throw 'Failed to obtain Google access token for Android Publisher API.'
        }

        $headers = @{ Authorization = "Bearer $cachedAccessToken"; 'Content-Type' = 'application/json' }
        $appCheckUrl = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$PackageName/edits"

        try {
            Invoke-ActionWithSpinner -Title "Verifying Google Play API permissions" -Variables @{
                appCheckUrl = $appCheckUrl
                headers = $headers
            } -Action {
                $appEdit = Invoke-RestMethod -Uri $appCheckUrl -Method Post -Headers $headers
                Invoke-RestMethod -Uri "$appCheckUrl/$($appEdit.id)" -Method Delete -Headers $headers | Out-Null
            }
        } catch {
            $details = Get-ErrorDetails -ErrorRecord $_
            Write-Host "`n${ESC}[31mFATAL: Service account cannot access package '$PackageName'.${ESC}[0m"
            Write-Host "Error Details: $details" -ForegroundColor Gray
            exit 1
        }
    }

    # --- BUILD PHASE ---
    if ($DryRun) {
        Write-StepStatus -State 'warn' -Message "Skipping Flutter build (Dry Run)"
    }
    elseif ($PublishOnly) {
        Write-StepStatus -State 'info' -Message "PublishOnly mode: using existing AAB" -Detail $AabPath
    }
    else {
        $null = Invoke-StepWithSpinner -Title "Incrementing patch version" -FilePath "pubversion" -ArgumentList @("patch")

        Start-Sleep -Seconds 1

        $null = Invoke-StepWithSpinner -Title "Building release App Bundle" -FilePath "flutter" -ArgumentList @(
            "build", "appbundle", "--release", "--obfuscate", "--split-debug-info=./debug_info", "--dart-define-from-file=.env"
        )
    }

    # --- PUBLISH PHASE ---
    if (-not $SkipPublish) {
        Invoke-PlayInternalTrackPublish `
            -RepoRoot $ProjectPath `
            -KeyFilePath $KeyFile `
            -PackageName $PackageName `
            -AabFilePath $AabPath `
            -Track $Track `
            -ReleaseConfigPath $ReleaseConfigPath `
            -AccessToken $cachedAccessToken `
            -DryRun:$DryRun
    }
    else {
        $pipelineStopwatch.Stop()
        $totalTime = "{0:mm\:ss}" -f $pipelineStopwatch.Elapsed
        Write-Host "`n${ESC}[32m${SYM_OK} Build completed in $totalTime (publish skipped).${ESC}[0m`n"
    }
}
catch {
    $pipelineStopwatch.Stop()
    Write-Host "`n${ESC}[31m${SYM_FAIL} Pipeline failed: $($_.Exception.Message)${ESC}[0m`n"
    exit 1
}
finally {
    [Console]::Write("${ESC}[?25h") # Always ensure cursor is visible on exit/Ctrl+C
    Pop-Location
}