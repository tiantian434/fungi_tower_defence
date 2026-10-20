param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath
)

# Build from the repository, then validate resources from the exported PCK in an
# empty working directory. Keep test saves and logs away from the player package.
$ErrorActionPreference = 'Stop'
$releaseRepo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$releaseEngine = (Resolve-Path -LiteralPath $GodotPath).Path
$releaseOutput = Join-Path $releaseRepo 'exports/Windows'
$releaseDist = Join-Path $releaseRepo 'dist'
$releaseStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$releaseQA = Join-Path $releaseRepo ".artifact_work/release_delivery/$releaseStamp"
New-Item -ItemType Directory -Force -Path $releaseOutput, $releaseDist, $releaseQA | Out-Null

$releaseExecutable = Join-Path $releaseOutput 'Huisheng.exe'
$releasePack = Join-Path $releaseOutput 'Huisheng.pck'
$releaseExportLog = Join-Path $releaseQA 'export.log'
& $releaseEngine --headless --path $releaseRepo --export-release 'Windows Release' $releaseExecutable *> $releaseExportLog
if ($LASTEXITCODE -ne 0) {
    throw "Windows export failed. See $releaseExportLog"
}
foreach ($releaseFile in @($releaseExecutable, $releasePack)) {
    if (!(Test-Path -LiteralPath $releaseFile) -or (Get-Item -LiteralPath $releaseFile).Length -eq 0) {
        throw "Export did not produce a usable file: $releaseFile"
    }
}

$releaseOldDisplayPrefs = [Environment]::GetEnvironmentVariable('FUNGI_DISPLAY_PREFERENCES', 'Process')
try {
    $env:FUNGI_DISPLAY_PREFERENCES = Join-Path $releaseQA 'display.cfg'
    $releaseCheckScript = Join-Path $PSScriptRoot 'verify_export.gd'
    $releaseCheckLog = Join-Path $releaseQA 'package-check.log'
    & $releaseEngine --headless --path $releaseQA --main-pack $releasePack --script $releaseCheckScript -- --qa-directory $releaseQA *> $releaseCheckLog
    if ($LASTEXITCODE -ne 0 -or !(Select-String -LiteralPath $releaseCheckLog -Pattern 'EXPORTED_PACKAGE_CHECK .*"failures":\[\]' -Quiet) -or (Select-String -LiteralPath $releaseCheckLog -Pattern 'SCRIPT ERROR:|ERROR:|Failed loading|Failed to load' -Quiet)) {
        throw "Exported resource validation failed. See $releaseCheckLog"
    }
    # A standard release template ignores editor script switches; start the
    # actual EXE independently as well, without the editor or source directory.
    $releaseLaunchLog = Join-Path $releaseQA 'executable-start.log'
    $releaseProcess = Start-Process -FilePath $releaseExecutable -WorkingDirectory $releaseQA -WindowStyle Hidden -ArgumentList @('--headless', '--quit-after', '12', '--log-file', ('"{0}"' -f $releaseLaunchLog)) -PassThru -Wait
    if ($releaseProcess.ExitCode -ne 0 -or !(Test-Path -LiteralPath $releaseLaunchLog)) {
        throw "Release executable did not start successfully. See $releaseLaunchLog"
    }
    if (Select-String -LiteralPath $releaseLaunchLog -Pattern 'SCRIPT ERROR:|ERROR:|Failed loading|Failed to load' -Quiet) {
        throw "Release executable reported an error. See $releaseLaunchLog"
    }
}
finally {
    [Environment]::SetEnvironmentVariable('FUNGI_DISPLAY_PREFERENCES', $releaseOldDisplayPrefs, 'Process')
}

Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'README玩家说明.md') -Destination (Join-Path $releaseOutput '游玩说明.md') -Force
$releaseVersionMatch = Select-String -LiteralPath (Join-Path $releaseRepo 'project.godot') -Pattern '^config/version="([^"]+)"$'
$releaseVersion = $releaseVersionMatch.Matches[0].Groups[1].Value
$releaseArchive = Join-Path $releaseDist "Huisheng-$releaseVersion-Windows.zip"
$releaseFiles = @($releaseExecutable, $releasePack, (Join-Path $releaseOutput '游玩说明.md'))
Compress-Archive -LiteralPath $releaseFiles -DestinationPath $releaseArchive -CompressionLevel Optimal -Force
$releaseUnpacked = Join-Path $releaseQA 'unpacked'
Expand-Archive -LiteralPath $releaseArchive -DestinationPath $releaseUnpacked
foreach ($releaseFile in $releaseFiles) {
    $releaseCopy = Join-Path $releaseUnpacked (Split-Path -Leaf $releaseFile)
    if ((Get-FileHash -LiteralPath $releaseFile -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $releaseCopy -Algorithm SHA256).Hash) {
        throw "Archive extraction changed file contents: $releaseCopy"
    }
}
try {
    $env:FUNGI_DISPLAY_PREFERENCES = Join-Path $releaseQA 'unpacked-display.cfg'
    $releaseUnpackedLog = Join-Path $releaseQA 'unpacked-start.log'
    $releaseProcess = Start-Process -FilePath (Join-Path $releaseUnpacked 'Huisheng.exe') -WorkingDirectory $releaseUnpacked -WindowStyle Hidden -ArgumentList @('--headless', '--quit-after', '12', '--log-file', ('"{0}"' -f $releaseUnpackedLog)) -PassThru -Wait
    if ($releaseProcess.ExitCode -ne 0 -or !(Test-Path -LiteralPath $releaseUnpackedLog) -or (Select-String -LiteralPath $releaseUnpackedLog -Pattern 'SCRIPT ERROR:|ERROR:|Failed loading|Failed to load' -Quiet)) {
        throw "Extracted release executable did not start cleanly. See $releaseUnpackedLog"
    }
}
finally {
    [Environment]::SetEnvironmentVariable('FUNGI_DISPLAY_PREFERENCES', $releaseOldDisplayPrefs, 'Process')
}
$releaseManifest = [ordered]@{
    version = $releaseVersion
    built_at = (Get-Date).ToString('o')
    source_commit = (& git -C $releaseRepo rev-parse HEAD)
    source_has_local_changes = [bool](& git -C $releaseRepo status --porcelain)
    validation_log = $releaseCheckLog
    files = @($releaseFiles | ForEach-Object {
        [ordered]@{ name = (Split-Path -Leaf $_); bytes = (Get-Item -LiteralPath $_).Length; sha256 = (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash }
    })
    archive_sha256 = (Get-FileHash -LiteralPath $releaseArchive -Algorithm SHA256).Hash
}
$releaseManifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $releaseQA 'build-manifest.json') -Encoding UTF8
Write-Output "Windows package: $releaseArchive"
Write-Output "Validation and hashes: $releaseQA"
