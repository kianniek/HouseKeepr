<#
Builds the release app bundle and, by default, publishes it to the Google Play
internal test track with a service account key.
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

$ErrorActionPreference = 'Stop'

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

if ($DryRun) {
    Write-Host "--- DRY RUN ENABLED ---" -ForegroundColor Yellow
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
            Write-Warning "Preflight: local versionCode $localVersionCode previously failed with 'already been used'. Consider incrementing version/build number before re-running -PublishOnly."
        }
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

function Invoke-PlayInternalTrackPublish {
    param(
        [Parameter(Mandatory = $true)] [string]$RepoRoot,
        [Parameter(Mandatory = $true)] [string]$KeyFilePath,
        [Parameter(Mandatory = $true)] [string]$PackageName,
        [Parameter(Mandatory = $true)] [string]$AabFilePath,
        [Parameter(Mandatory = $true)] [string]$Track,
        [Parameter(Mandatory = $true)] [string]$ReleaseConfigPath,
        [switch]$DryRun
    )

    $resolvedKeyFile = Resolve-RepoPath -Path $KeyFilePath -BasePath $RepoRoot
    $resolvedAabPath = Resolve-RepoPath -Path $AabFilePath -BasePath $RepoRoot

    if ($DryRun) {
        Write-Host "[DRY RUN] Simulating API lifecycle..." -ForegroundColor Yellow
        return
    }

    $token = (& gcloud auth print-access-token --scopes="https://www.googleapis.com/auth/androidpublisher").Trim()
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw 'Failed to obtain Google access token for Android Publisher API.'
    }
    $headers = @{ Authorization = "Bearer $token"; 'Content-Type' = 'application/json' }
    $baseUrl = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$PackageName/edits"

    Write-Host 'Creating Play Console edit...' -ForegroundColor Cyan
    $editId = $null
    $committed = $false
    $releaseConfig = Get-ReleaseConfig -RepoRoot $RepoRoot -ConfigPath $ReleaseConfigPath
    $releaseStatus = [string]$releaseConfig.status
    $releaseNotes = $releaseConfig.releaseNotes

    function Set-TrackRelease {
        param(
            [Parameter(Mandatory = $true)] [string]$Status,
            [Parameter(Mandatory = $true)] [string]$TrackUrl,
            [Parameter(Mandatory = $true)] [hashtable]$Headers,
            [Parameter(Mandatory = $true)] [string]$VersionCode,
            [Parameter(Mandatory = $true)] [string]$ReleaseName,
            [Parameter(Mandatory = $true)] [object[]]$ReleaseNotes
        )

        $trackBody = @{
            releases = @(
                @{
                    versionCodes = @($VersionCode);
                    status = $Status;
                    name = $ReleaseName;
                    releaseNotes = $ReleaseNotes
                }
            )
        } | ConvertTo-Json -Depth 5

        Invoke-RestMethod -Uri $TrackUrl -Method Put -Headers $Headers -Body $trackBody | Out-Null
    }

    try {
        try {
            $editResponse = Invoke-RestMethod -Uri $baseUrl -Method Post -Headers $headers
            $editId = $editResponse.id
        } catch {
            $details = Get-ErrorDetails -ErrorRecord $_
            Write-Error "Google API Error (create edit): $details"
            throw $_
        }

        Write-Host "Uploading app bundle from $resolvedAabPath..." -ForegroundColor Cyan
        $uploadUrl = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/$PackageName/edits/$editId/bundles?uploadType=media"
        try {
            $uploadResponse = Invoke-RestMethod -Uri $uploadUrl -Method Post -Headers @{ Authorization = "Bearer $token" } -ContentType 'application/octet-stream' -InFile $resolvedAabPath
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
                Write-Error "Google API Error (upload bundle): $details`nGuidance: This AAB's versionCode is already published in Play Console. Build a new bundle with a higher versionCode (run '.\\scripts\\build_appbundle.ps1' without -PublishOnly), or provide -AabPath to a newer AAB before retrying -PublishOnly."
            }
            else {
                Write-Error "Google API Error (upload bundle): $details"
            }
            throw
        }

        $versionCode = $uploadResponse.versionCode
        $releaseName = ([string]$releaseConfig.nameTemplate) -replace '\{versionCode\}', [string]$versionCode
        Write-Host "Assigning version $versionCode to track '$Track'..." -ForegroundColor Cyan
        $trackUrl = "$baseUrl/$editId/tracks/$Track"
        try {
            Set-TrackRelease -Status $releaseStatus -TrackUrl $trackUrl -Headers $headers -VersionCode $versionCode -ReleaseName $releaseName -ReleaseNotes $releaseNotes
        } catch {
            $details = Get-ErrorDetails -ErrorRecord $_
            Write-Error "Google API Error (update track '$Track'): $details"
            throw
        }

        Write-Host 'Committing edit...' -ForegroundColor Cyan
        try {
            Invoke-RestMethod -Uri "$baseUrl/${editId}:commit" -Method Post -Headers $headers | Out-Null
        } catch {
            $details = Get-ErrorDetails -ErrorRecord $_

            if ($details -match 'Only releases with status draft may be created on draft app' -and $releaseStatus -ne 'draft') {
                Write-Host "Commit rejected for status '$releaseStatus'. Retrying with release status 'draft' for draft app..." -ForegroundColor Yellow
                $releaseStatus = 'draft'

                try {
                    Set-TrackRelease -Status $releaseStatus -TrackUrl $trackUrl -Headers $headers -VersionCode $versionCode -ReleaseName $releaseName -ReleaseNotes $releaseNotes
                } catch {
                    $retryTrackDetails = Get-ErrorDetails -ErrorRecord $_
                    Write-Error "Google API Error (update track '$Track' retry as 'draft'): $retryTrackDetails"
                    throw
                }

                try {
                    Invoke-RestMethod -Uri "$baseUrl/${editId}:commit" -Method Post -Headers $headers | Out-Null
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
        Set-PublishState -RepoRoot $RepoRoot -VersionCode ([string]$versionCode) -Result 'success' -Message "Published to track '$Track' with status '$releaseStatus'."
    }
    finally {
        if (-not $committed -and -not [string]::IsNullOrWhiteSpace($editId)) {
            Write-Host "Cleaning up uncommitted edit $editId..." -ForegroundColor Yellow
            try { Invoke-RestMethod -Uri "$baseUrl/$editId" -Method Delete -Headers $headers | Out-Null } catch { }
        }
    }
    Write-Host "Upload successful. Version $versionCode is now in the $Track track (status: $releaseStatus)." -ForegroundColor Green
}

Push-Location $ProjectPath
try {
    # --- PRE-BUILD PERMISSION CHECK ---
    if (-not $SkipPublish -and -not $DryRun) {
        Write-Host "Verifying Google Play API permissions before starting build..." -ForegroundColor Cyan
        
        $resolvedKey = Resolve-RepoPath -Path $KeyFile -BasePath $ProjectPath
        & gcloud auth activate-service-account --key-file="$resolvedKey" | Out-Null
        
        $token = (& gcloud auth print-access-token --scopes="https://www.googleapis.com/auth/androidpublisher").Trim()
        if ([string]::IsNullOrWhiteSpace($token)) {
            throw 'Failed to obtain Google access token for Android Publisher API.'
        }
        $headers = @{ Authorization = "Bearer $token"; 'Content-Type' = 'application/json' }
        
        try {
            $appCheckUrl = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$PackageName/edits"
            $appEdit = Invoke-RestMethod -Uri $appCheckUrl -Method Post -Headers $headers
            Write-Host "Permission Check Passed: Successfully created edit session $($appEdit.id)" -ForegroundColor Green
            
            # Clean up the test edit session immediately
            Invoke-RestMethod -Uri "$appCheckUrl/$($appEdit.id)" -Method Delete -Headers $headers | Out-Null
        } catch {
            $details = Get-ErrorDetails -ErrorRecord $_
            Write-Host "FATAL: Service account cannot access this app package." -ForegroundColor Red
            Write-Host "Error Details: $details" -ForegroundColor Gray
            exit 1
        }
    }

    if ($DryRun) {
        Write-Host "[DRY RUN] Skipping Flutter Build..." -ForegroundColor Yellow
    }
    elseif ($PublishOnly) {
        Write-Host "PublishOnly mode: skipping build and using existing AAB at $AabPath" -ForegroundColor Cyan
    }
    else {
        Write-Host "Incrementing version..." -ForegroundColor Cyan
        & pubversion patch
        if ($LASTEXITCODE -ne 0) { throw 'pubversion patch failed.' }
        
        Start-Sleep -Seconds 1
        
        Write-Host "Building Flutter App Bundle..." -ForegroundColor Cyan
        & flutter build appbundle --release --obfuscate --split-debug-info=./debug_info --dart-define-from-file=.env
        if ($LASTEXITCODE -ne 0) { throw 'flutter build appbundle failed.' }
    }

    if (-not $SkipPublish) {
        Invoke-PlayInternalTrackPublish `
            -RepoRoot $ProjectPath `
            -KeyFilePath $KeyFile `
            -PackageName $PackageName `
            -AabFilePath $AabPath `
            -Track $Track `
            -ReleaseConfigPath $ReleaseConfigPath `
            -DryRun:$DryRun
    }
}
finally {
    Pop-Location
}