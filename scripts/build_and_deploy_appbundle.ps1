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
# STEP TIMING AVERAGES & PROGRESS TRACKING
# ==============================================================================

$script:TIMING_WINDOW_SIZE = 3
$script:DEFAULT_STEP_ESTIMATES = @{
    'activate_service_account' = 2.0
    'fetch_access_token'       = 2.0
    'verify_permissions'       = 2.0
    'increment_version'        = 2.0
    'build_appbundle'          = 60.0
    'create_edit'              = 2.0
    'upload_aab'               = 15.0
    'assign_track'             = 2.0
    'commit_edit'              = 2.0
}
$script:StepTimings = @{}
$script:PipelineProgress = $null

function Get-TimingFilePath {
    param(
        [Parameter(Mandatory = $true)] [string]$RepoRoot
    )

    return Join-Path $RepoRoot 'scripts\.build_appbundle_timings.json'
}

function Get-StepTimingData {
    param(
        [Parameter(Mandatory = $true)] [string]$RepoRoot
    )

    $timingPath = Get-TimingFilePath -RepoRoot $RepoRoot
    $result = @{}
    if (-not (Test-Path $timingPath)) { return $result }

    try {
        $raw = Get-Content -Path $timingPath -Raw | ConvertFrom-Json
        if ($null -ne $raw -and $null -ne $raw.steps) {
            foreach ($prop in $raw.steps.PSObject.Properties) {
                $samples = @()
                if ($null -ne $prop.Value.samples) {
                    $samples = @($prop.Value.samples | ForEach-Object { [double]$_ })
                }
                $avg = if ($samples.Count -gt 0) {
                    [math]::Round((($samples | Measure-Object -Average).Average), 3)
                } elseif ($null -ne $prop.Value.averageSeconds) {
                    [double]$prop.Value.averageSeconds
                } else {
                    0.0
                }
                $result[$prop.Name] = @{
                    label          = [string]$prop.Value.label
                    samples        = $samples
                    averageSeconds = $avg
                }
            }
        }
    } catch {
        return @{}
    }

    return $result
}

function Save-StepTimingData {
    param(
        [Parameter(Mandatory = $true)] [string]$RepoRoot,
        [Parameter(Mandatory = $true)] [hashtable]$Timings
    )

    $timingPath = Get-TimingFilePath -RepoRoot $RepoRoot
    $stepsOut = [ordered]@{}
    foreach ($key in ($Timings.Keys | Sort-Object)) {
        $entry = $Timings[$key]
        $stepsOut[$key] = [ordered]@{
            label          = [string]$entry.label
            samples        = @($entry.samples | ForEach-Object { [double]$_ })
            averageSeconds = [double]$entry.averageSeconds
        }
    }

    $payload = [ordered]@{
        windowSize = $script:TIMING_WINDOW_SIZE
        updatedUtc = (Get-Date).ToUniversalTime().ToString('o')
        steps      = $stepsOut
    }

    $payload | ConvertTo-Json -Depth 5 | Set-Content -Path $timingPath -Encoding UTF8
}

function Update-StepTiming {
    param(
        [Parameter(Mandatory = $true)] [string]$RepoRoot,
        [Parameter(Mandatory = $true)] [string]$StepKey,
        [Parameter(Mandatory = $true)] [string]$Label,
        [Parameter(Mandatory = $true)] [double]$DurationSeconds
    )

    $samples = @()
    if ($script:StepTimings.ContainsKey($StepKey) -and $null -ne $script:StepTimings[$StepKey].samples) {
        $samples = @($script:StepTimings[$StepKey].samples | ForEach-Object { [double]$_ })
    }

    $samples += [math]::Round($DurationSeconds, 3)
    if ($samples.Count -gt $script:TIMING_WINDOW_SIZE) {
        $samples = @($samples[($samples.Count - $script:TIMING_WINDOW_SIZE)..($samples.Count - 1)])
    }

    $avg = [math]::Round((($samples | Measure-Object -Average).Average), 3)
    $script:StepTimings[$StepKey] = @{
        label          = $Label
        samples        = $samples
        averageSeconds = $avg
    }

    try {
        Save-StepTimingData -RepoRoot $RepoRoot -Timings $script:StepTimings
    } catch {
        # Non-fatal: timing persistence failure should not abort build/deploy
    }
}

function Initialize-PipelineProgress {
    param(
        [Parameter(Mandatory = $true)] [string]$RepoRoot,
        [Parameter(Mandatory = $true)] [string[]]$PlannedSteps,
        [Parameter(Mandatory = $true)] [System.Diagnostics.Stopwatch]$PipelineStopwatch
    )

    $estimates = @{}
    $totalEst = 0.0
    $calibratedCount = 0

    foreach ($stepKey in $PlannedSteps) {
        if ($script:StepTimings.ContainsKey($stepKey) -and $script:StepTimings[$stepKey].averageSeconds -gt 0) {
            $est = [double]$script:StepTimings[$stepKey].averageSeconds
            $calibratedCount++
        } elseif ($script:DEFAULT_STEP_ESTIMATES.ContainsKey($stepKey)) {
            $est = [double]$script:DEFAULT_STEP_ESTIMATES[$stepKey]
        } else {
            $est = 5.0
        }
        $estimates[$stepKey] = $est
        $totalEst += $est
    }

    $script:PipelineProgress = @{
        repoRoot              = $RepoRoot
        plannedSteps          = $PlannedSteps
        stepEstimates         = $estimates
        totalEstimatedSeconds = $totalEst
        completedSteps        = New-Object 'System.Collections.Generic.HashSet[string]'
        completedWeight       = 0.0
        currentStepKey        = ''
        pipelineStopwatch     = $PipelineStopwatch
        isCalibrated          = ($calibratedCount -gt 0)
    }
}

function Set-CurrentPipelineStep {
    param(
        [string]$StepKey = ''
    )

    if ($null -ne $script:PipelineProgress) {
        $script:PipelineProgress.currentStepKey = $StepKey
    }
}

function Complete-PipelineStep {
    param(
        [string]$StepKey = '',
        [string]$Title = '',
        [double]$ElapsedSeconds = 0.0
    )

    if ([string]::IsNullOrWhiteSpace($StepKey)) { return }

    if ($null -ne $script:PipelineProgress) {
        if (-not $script:PipelineProgress.completedSteps.Contains($StepKey)) {
            [void]$script:PipelineProgress.completedSteps.Add($StepKey)
            if ($script:PipelineProgress.stepEstimates.ContainsKey($StepKey)) {
                $script:PipelineProgress.completedWeight += [double]$script:PipelineProgress.stepEstimates[$StepKey]
            }
        }
        $script:PipelineProgress.currentStepKey = ''

        if (-not [string]::IsNullOrWhiteSpace($script:PipelineProgress.repoRoot)) {
            $label = if (-not [string]::IsNullOrWhiteSpace($Title)) { $Title } else { $StepKey }
            Update-StepTiming -RepoRoot $script:PipelineProgress.repoRoot -StepKey $StepKey -Label $label -DurationSeconds $ElapsedSeconds
        }
    }
}

function Get-PipelineProgressSnapshot {
    param(
        [double]$CurrentStepElapsedSeconds = 0.0,
        [double]$CurrentStepFractionOverride = -1.0
    )

    if ($null -eq $script:PipelineProgress -or $script:PipelineProgress.totalEstimatedSeconds -le 0) {
        return $null
    }

    $p = $script:PipelineProgress
    $curKey = $p.currentStepKey
    $estStep = if (-not [string]::IsNullOrWhiteSpace($curKey) -and $p.stepEstimates.ContainsKey($curKey)) {
        [double]$p.stepEstimates[$curKey]
    } else {
        5.0
    }

    if ($CurrentStepFractionOverride -ge 0) {
        $fraction = [math]::Min(1.0, [math]::Max(0.0, $CurrentStepFractionOverride))
        $currentContribution = $estStep * $fraction
        $currentRemaining = [math]::Max(0.0, $estStep * (1.0 - $fraction))
    } else {
        $currentContribution = [math]::Min($CurrentStepElapsedSeconds, $estStep * 0.95)
        $currentRemaining = [math]::Max(0.0, $estStep - $CurrentStepElapsedSeconds)
    }

    $futureWeight = 0.0
    foreach ($key in $p.plannedSteps) {
        if (-not $p.completedSteps.Contains($key) -and $key -ne $curKey) {
            $futureWeight += [double]$p.stepEstimates[$key]
        }
    }

    $completedSoFar = $p.completedWeight + $currentContribution
    $pct = [math]::Min(99, [math]::Max(0, [math]::Floor(($completedSoFar / $p.totalEstimatedSeconds) * 100)))
    $remainingSeconds = $currentRemaining + $futureWeight
    $totalElapsedSeconds = $p.pipelineStopwatch.Elapsed.TotalSeconds

    return @{
        Percent             = $pct
        RemainingSeconds    = $remainingSeconds
        TotalElapsedSeconds = $totalElapsedSeconds
        CurrentStepEstimate = $estStep
        IsCalibrated        = $p.isCalibrated
    }
}

function Format-DurationShort {
    param([double]$Seconds)
    $clamped = [math]::Max(0, [math]::Round($Seconds))
    $ts = [TimeSpan]::FromSeconds($clamped)
    if ($ts.TotalHours -ge 1) {
        return "{0:hh\:mm\:ss}" -f $ts
    }
    return "{0:mm\:ss}" -f $ts
}

function Format-OverallProgressBar {
    param(
        [hashtable]$Snapshot
    )

    if ($null -eq $Snapshot) { return '' }

    $barWidth = 24
    try {
        $winWidth = [Console]::WindowWidth
        if ($winWidth -gt 0 -and $winWidth -lt 72) {
            $barWidth = [math]::Max(10, $winWidth - 48)
        }
    } catch { }

    $pct = [int]$Snapshot.Percent
    $filled = [math]::Floor(($pct / 100) * $barWidth)
    $empty = $barWidth - $filled
    $bar = ($SYM_BLOCK * $filled) + ($SYM_SHADE * $empty)

    $elapsedStr = Format-DurationShort -Seconds $Snapshot.TotalElapsedSeconds
    $etaPrefix = if ($Snapshot.IsCalibrated) { "~" } else { "~" }
    $etaStr = if ($Snapshot.RemainingSeconds -le 0.5) { "${etaPrefix}00:00+" } else { "$etaPrefix$(Format-DurationShort -Seconds $Snapshot.RemainingSeconds)" }
    $pctPadded = $pct.ToString().PadLeft(3)

    return "${ESC}[90mOverall [${ESC}[32m$bar${ESC}[90m] ${ESC}[37m$pctPadded%${ESC}[90m | Elapsed $elapsedStr | ETA $etaStr${ESC}[0m"
}

function Write-LiveProgressLines {
    param(
        [Parameter(Mandatory = $true)] [string]$Line1,
        [string]$Line2 = '',
        [bool]$IsRedraw = $false
    )

    if ([Console]::IsOutputRedirected) { return }

    if ([string]::IsNullOrWhiteSpace($Line2)) {
        [Console]::Write("`r${ESC}[2K$Line1")
    } elseif ($IsRedraw) {
        [Console]::Write("${ESC}[1A`r${ESC}[2K$Line1`n${ESC}[2K$Line2")
    } else {
        [Console]::Write("`r${ESC}[2K$Line1`n${ESC}[2K$Line2")
    }
}

function Clear-LiveProgressLines {
    param(
        [bool]$HasSecondLine = $false,
        [bool]$HadOutput = $false
    )

    if ([Console]::IsOutputRedirected -or -not $HadOutput) { return }

    if ($HasSecondLine) {
        [Console]::Write("`r${ESC}[2K${ESC}[1A`r${ESC}[2K")
    } else {
        [Console]::Write("`r${ESC}[2K")
    }
}

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
        [string]$WorkingDirectory = (Get-Location).Path,
        [string]$StepKey = ''
    )

    Set-CurrentPipelineStep -StepKey $StepKey
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
    $i = 0
    $hasSecondLine = $false
    try {
        [void]$proc.Start()
        $proc.BeginOutputReadLine()
        $proc.BeginErrorReadLine()

        while (-not $proc.WaitForExit(80)) {
            $frame = $SPINNER_FRAMES[$i % $SPINNER_FRAMES.Count]
            $elapsed = "{0:mm\:ss}" -f $sw.Elapsed
            $snapshot = Get-PipelineProgressSnapshot -CurrentStepElapsedSeconds $sw.Elapsed.TotalSeconds
            $estSuffix = if ($null -ne $snapshot -and -not [string]::IsNullOrWhiteSpace($StepKey)) {
                " / ~$(Format-DurationShort -Seconds $snapshot.CurrentStepEstimate)"
            } else { '' }
            $line1 = "${ESC}[36m$frame${ESC}[0m $Title ${ESC}[90m[$elapsed$estSuffix]${ESC}[0m"
            $line2 = Format-OverallProgressBar -Snapshot $snapshot
            $hasSecondLine = -not [string]::IsNullOrWhiteSpace($line2)
            Write-LiveProgressLines -Line1 $line1 -Line2 $line2 -IsRedraw ($i -gt 0)
            $i++
        }
        $proc.WaitForExit()
    }
    finally {
        Clear-LiveProgressLines -HasSecondLine $hasSecondLine -HadOutput ($i -gt 0)
        [Console]::Write("${ESC}[?25h")
        Unregister-Event -SourceIdentifier $outEvent.Name -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier $errEvent.Name -ErrorAction SilentlyContinue
    }

    $sw.Stop()
    $elapsedFinal = "{0:mm\:ss}" -f $sw.Elapsed

    if ($proc.ExitCode -eq 0) {
        Complete-PipelineStep -StepKey $StepKey -Title $Title -ElapsedSeconds $sw.Elapsed.TotalSeconds
        Write-StepStatus -State 'ok' -Message $Title -Detail $elapsedFinal
        return $outBuilder.ToString()
    }
    else {
        Set-CurrentPipelineStep -StepKey ''
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
        [hashtable]$Variables = @{},
        [string]$StepKey = ''
    )

    Set-CurrentPipelineStep -StepKey $StepKey
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $ps = [powershell]::Create()
    foreach ($key in $Variables.Keys) {
        [void]$ps.Runspace.SessionStateProxy.SetVariable($key, $Variables[$key])
    }
    [void]$ps.AddScript($Action)
    $asyncResult = $ps.BeginInvoke()

    [Console]::Write("${ESC}[?25l")
    $i = 0
    $hasSecondLine = $false
    try {
        while (-not $asyncResult.IsCompleted) {
            $frame = $SPINNER_FRAMES[$i % $SPINNER_FRAMES.Count]
            $elapsed = "{0:mm\:ss}" -f $sw.Elapsed
            $snapshot = Get-PipelineProgressSnapshot -CurrentStepElapsedSeconds $sw.Elapsed.TotalSeconds
            $estSuffix = if ($null -ne $snapshot -and -not [string]::IsNullOrWhiteSpace($StepKey)) {
                " / ~$(Format-DurationShort -Seconds $snapshot.CurrentStepEstimate)"
            } else { '' }
            $line1 = "${ESC}[36m$frame${ESC}[0m $Title ${ESC}[90m[$elapsed$estSuffix]${ESC}[0m"
            $line2 = Format-OverallProgressBar -Snapshot $snapshot
            $hasSecondLine = -not [string]::IsNullOrWhiteSpace($line2)
            Write-LiveProgressLines -Line1 $line1 -Line2 $line2 -IsRedraw ($i -gt 0)
            Start-Sleep -Milliseconds 80
            $i++
        }

        $result = $ps.EndInvoke($asyncResult)
        if ($ps.HadErrors) {
            throw $ps.Streams.Error[0]
        }

        $sw.Stop()
        Clear-LiveProgressLines -HasSecondLine $hasSecondLine -HadOutput ($i -gt 0)
        $hasSecondLine = $false
        $i = 0
        Complete-PipelineStep -StepKey $StepKey -Title $Title -ElapsedSeconds $sw.Elapsed.TotalSeconds
        Write-StepStatus -State 'ok' -Message $Title -Detail ("{0:mm\:ss}" -f $sw.Elapsed)
        return $result
    }
    catch {
        $sw.Stop()
        Clear-LiveProgressLines -HasSecondLine $hasSecondLine -HadOutput ($i -gt 0)
        $hasSecondLine = $false
        $i = 0
        Set-CurrentPipelineStep -StepKey ''
        Write-StepStatus -State 'fail' -Message $Title -Detail ("{0:mm\:ss}" -f $sw.Elapsed)
        throw
    }
    finally {
        Clear-LiveProgressLines -HasSecondLine $hasSecondLine -HadOutput ($i -gt 0)
        [Console]::Write("${ESC}[?25h")
        $ps.Dispose()
    }
}

function Send-AabWithProgress {
    param(
        [Parameter(Mandatory = $true)] [string]$UploadUrl,
        [Parameter(Mandatory = $true)] [string]$FilePath,
        [Parameter(Mandatory = $true)] [string]$Token,
        [string]$StepKey = 'upload_aab'
    )

    Set-CurrentPipelineStep -StepKey $StepKey
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
    $i = 0
    $hasSecondLine = $false
    try {
        $streamContent = New-Object System.Net.Http.StreamContent($fileStream)
        $streamContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/octet-stream")

        $uploadTask = $httpClient.PostAsync($UploadUrl, $streamContent)

        $barWidth = 28
        while (-not $uploadTask.Wait(80)) {
            $sentBytes = $fileStream.Position
            $fraction = if ($totalBytes -gt 0) { [math]::Min(1.0, ($sentBytes / $totalBytes)) } else { 0.0 }
            $pct = [math]::Min(100, [math]::Floor($fraction * 100))
            $filled = [math]::Floor(($pct / 100) * $barWidth)
            $empty = $barWidth - $filled
            $bar = ($SYM_BLOCK * $filled) + ($SYM_SHADE * $empty)
            $sentMB = "{0:N1}" -f ($sentBytes / 1MB)

            $statusText = if ($pct -ge 100) { "Finalizing on Google Play..." } else { "$sentMB / $totalMB MB" }
            $line1 = "${ESC}[36m${SYM_UP}${ESC}[0m Uploading AAB [${ESC}[36m$bar${ESC}[0m] $pct% ${ESC}[90m($statusText)${ESC}[0m"
            $snapshot = Get-PipelineProgressSnapshot -CurrentStepElapsedSeconds $sw.Elapsed.TotalSeconds -CurrentStepFractionOverride $fraction
            $line2 = Format-OverallProgressBar -Snapshot $snapshot
            $hasSecondLine = -not [string]::IsNullOrWhiteSpace($line2)
            Write-LiveProgressLines -Line1 $line1 -Line2 $line2 -IsRedraw ($i -gt 0)
            $i++
        }

        $response = $uploadTask.GetAwaiter().GetResult()
        $responseBody = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()

        Clear-LiveProgressLines -HasSecondLine $hasSecondLine -HadOutput ($i -gt 0)
        $hasSecondLine = $false
        $i = 0

        if (-not $response.IsSuccessStatusCode) {
            Set-CurrentPipelineStep -StepKey ''
            Write-StepStatus -State 'fail' -Message "Uploading AAB ($totalMB MB)" -Detail ("{0:mm\:ss}" -f $sw.Elapsed)
            throw "HTTP $([int]$response.StatusCode) ($($response.ReasonPhrase)): $responseBody"
        }

        $sw.Stop()
        Complete-PipelineStep -StepKey $StepKey -Title "Uploading AAB" -ElapsedSeconds $sw.Elapsed.TotalSeconds
        Write-StepStatus -State 'ok' -Message "Uploaded AAB ($totalMB MB)" -Detail ("{0:mm\:ss}" -f $sw.Elapsed)
        return ($responseBody | ConvertFrom-Json)
    }
    finally {
        Clear-LiveProgressLines -HasSecondLine $hasSecondLine -HadOutput ($i -gt 0)
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
        $token = (Invoke-StepWithSpinner -Title "Fetching Google Play access token" -StepKey "fetch_access_token" -FilePath "gcloud" -ArgumentList @("auth", "print-access-token", "--scopes=https://www.googleapis.com/auth/androidpublisher")).Trim()
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
            $editResponse = Invoke-ActionWithSpinner -Title "Creating Play Console edit" -StepKey "create_edit" -Variables @{
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
            $uploadResponse = Send-AabWithProgress -UploadUrl $uploadUrl -FilePath $resolvedAabPath -Token $token -StepKey "upload_aab"
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
            Invoke-ActionWithSpinner -Title "Assigning version $versionCode to '$Track' track" -StepKey "assign_track" -Variables @{
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
            Invoke-ActionWithSpinner -Title "Committing Play Console edit" -StepKey "commit_edit" -Variables @{
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

$script:StepTimings = Get-StepTimingData -RepoRoot $ProjectPath
$plannedSteps = @()
if (-not $DryRun) {
    if (-not $SkipPublish) {
        $plannedSteps += @('activate_service_account', 'fetch_access_token', 'verify_permissions')
    }
    if (-not $PublishOnly) {
        $plannedSteps += @('increment_version', 'build_appbundle')
    }
    if (-not $SkipPublish) {
        $plannedSteps += @('create_edit', 'upload_aab', 'assign_track', 'commit_edit')
    }
}
if ($plannedSteps.Count -gt 0) {
    Initialize-PipelineProgress -RepoRoot $ProjectPath -PlannedSteps $plannedSteps -PipelineStopwatch $pipelineStopwatch
}

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

        $null = Invoke-StepWithSpinner -Title "Activating service account" -StepKey "activate_service_account" -FilePath "gcloud" -ArgumentList @(
            "auth", "activate-service-account", "--key-file=$resolvedKey"
        )

        $cachedAccessToken = (Invoke-StepWithSpinner -Title "Fetching Google Play access token" -StepKey "fetch_access_token" -FilePath "gcloud" -ArgumentList @(
            "auth", "print-access-token", "--scopes=https://www.googleapis.com/auth/androidpublisher"
        )).Trim()

        if ([string]::IsNullOrWhiteSpace($cachedAccessToken)) {
            throw 'Failed to obtain Google access token for Android Publisher API.'
        }

        $headers = @{ Authorization = "Bearer $cachedAccessToken"; 'Content-Type' = 'application/json' }
        $appCheckUrl = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$PackageName/edits"

        try {
            Invoke-ActionWithSpinner -Title "Verifying Google Play API permissions" -StepKey "verify_permissions" -Variables @{
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
        $null = Invoke-StepWithSpinner -Title "Incrementing patch version" -StepKey "increment_version" -FilePath "pubversion" -ArgumentList @("patch")

        Start-Sleep -Seconds 1

        # $flutterBuildArgs = @(
        #     "build", "appbundle", "--release", "--split-debug-info=./debug_info", "--dart-define-from-file=.env"#, "--obfuscate"
        # )
        $flutterBuildArgs = @(
            "build", "appbundle", "--release", "--dart-define-from-file=.env", "--no-validate-deferred-components"
        )
        $null = Invoke-StepWithSpinner -Title "Building release App Bundle" -StepKey "build_appbundle" -FilePath "flutter" -ArgumentList $flutterBuildArgs
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

        $pipelineStopwatch.Stop()
        if (-not $DryRun) {
            $totalTime = Format-DurationShort -Seconds $pipelineStopwatch.Elapsed.TotalSeconds
            $fullBar = $SYM_BLOCK * 24
            Write-Host "${ESC}[90mOverall [${ESC}[32m$fullBar${ESC}[90m] ${ESC}[32m100%${ESC}[90m | Completed in $totalTime${ESC}[0m`n"
        }
    }
    else {
        $pipelineStopwatch.Stop()
        $totalTime = Format-DurationShort -Seconds $pipelineStopwatch.Elapsed.TotalSeconds
        $fullBar = $SYM_BLOCK * 24
        Write-Host "`n${ESC}[90mOverall [${ESC}[32m$fullBar${ESC}[90m] ${ESC}[32m100%${ESC}[90m | Completed in $totalTime${ESC}[0m"
        Write-Host "${ESC}[32m${SYM_OK} Build completed in $totalTime (publish skipped).${ESC}[0m`n"
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