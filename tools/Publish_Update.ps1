param(
    [Parameter(Mandatory = $true)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version,
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9_][A-Za-z0-9_.-]*$')][string]$Repository = 'plachenko/OnTheFly',
    [string]$NotesFile,
    [string]$TargetCommitish,
    [switch]$Build,
    [switch]$Android,
    [string]$GodotPath,
    [string]$AndroidSigningConfig,
    [string]$CityFile,
    [switch]$Publish,
    [string]$Token = $(if ($env:GH_TOKEN) { $env:GH_TOKEN } else { $env:GITHUB_TOKEN })
)
$ErrorActionPreference = 'Stop'
if ($CityFile -and -not $Build) { throw '-CityFile requires -Build so the chosen city can be included in the game.' }
$workspaceRoot = if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Food_Truck_Drive')) { $PSScriptRoot } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..')) }
$buildDirectory = Join-Path $workspaceRoot 'OnTheFly_Windows'
$projectDirectory = if (Test-Path -LiteralPath (Join-Path $workspaceRoot 'Food_Truck_Drive\project.godot')) { Join-Path $workspaceRoot 'Food_Truck_Drive' } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')) }
$outputDirectory = Join-Path $workspaceRoot ('Releases\v' + $Version)
$stageDirectory = Join-Path $outputDirectory ('stage-' + [guid]::NewGuid().ToString('N'))
$archive = Join-Path $outputDirectory 'OnTheFly_Windows.zip'
$checksum = $archive + '.sha256'
$apk = Join-Path $outputDirectory 'OnTheFly.apk'
$apkChecksum = $apk + '.sha256'
$apkManifest = Join-Path $outputDirectory 'OnTheFly_Android.json'
$files = @('OnTheFly.exe', 'README.txt', 'release_manifest.json', 'Launch_OnTheFly.cmd', 'Update_Game.ps1', 'updater_config.json')
$buildExe = Join-Path $buildDirectory 'OnTheFly.exe'
function Get-PackageSource([string]$Name) {
    if ($Name -eq 'OnTheFly.exe') { return $buildExe }
    if ($Name -eq 'README.txt') { return (Join-Path $projectDirectory 'README.txt') }
    return (Join-Path $projectDirectory ('tools\updater\' + $Name))
}
if ($Publish -and [string]::IsNullOrWhiteSpace($Token)) { throw 'Publishing requires GH_TOKEN or GITHUB_TOKEN with write access to the release repository.' }
if ($NotesFile -and -not (Test-Path -LiteralPath $NotesFile -PathType Leaf)) { throw 'Notes file does not exist.' }
if ($Publish) {
    $preflightHeaders = @{ 'Authorization' = "Bearer $Token"; 'Accept' = 'application/vnd.github+json'; 'User-Agent' = 'OnTheFly-Publisher'; 'X-GitHub-Api-Version' = '2022-11-28' }
    try {
        $currentRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases/latest" -Headers $preflightHeaders -TimeoutSec 30
        if ($currentRelease.tag_name -notmatch '^v?(\d+\.\d+\.\d+)$') { throw 'Latest release does not have a supported version tag.' }
        if ([version]$Version -le [version]$Matches[1]) { throw 'Choose a version newer than the latest release so clients can detect the update.' }
    } catch {
        if (-not $_.Exception.Response -or [int]$_.Exception.Response.StatusCode -ne 404) { throw }
    }
}
if ($Build) {
    if (-not $GodotPath) {
        $androidEditor = Join-Path $workspaceRoot '.runtime\android_release_export\godot.exe'
        $GodotPath = if ($Android -and (Test-Path -LiteralPath $androidEditor)) { $androidEditor } else { Join-Path $projectDirectory '.godot\export_runtime\GodotExport.exe' }
    }
    if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw 'Supply -GodotPath pointing to a Godot editor with Windows export templates.' }
    # Export to a fresh path so building never replaces a running game.
    $exportDirectory = Join-Path $outputDirectory ('build-' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($exportDirectory) | Out-Null
    $buildExe = Join-Path $exportDirectory 'OnTheFly.exe'
    $cityArguments = @('--headless', '--path', ('"{0}"' -f $projectDirectory), '--script', 'res://tools/bake_city.gd')
    if ($CityFile) {
        $resolvedCity = (Resolve-Path -LiteralPath $CityFile).Path
        $cityArguments += @('--', '--city-file', ('"{0}"' -f $resolvedCity))
    }
    if (-not $CityFile) { $cityArguments += @('--') }
    foreach ($citySize in @(0,1)) {
        $sizeArguments = $cityArguments + @('--map-size', [string]$citySize)
        $cityProcess = Start-Process -FilePath $GodotPath -ArgumentList $sizeArguments -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $exportDirectory "city-bake-$citySize.log") -RedirectStandardError (Join-Path $exportDirectory "city-bake-$citySize.errors.log")
        if ($cityProcess.ExitCode -ne 0) { throw "City bake failed. See $exportDirectory\city-bake-$citySize.errors.log. No release was published." }
    }
    foreach ($citySize in @(0,1)) {
        $gridArguments = @('--headless', '--path', ('"{0}"' -f $projectDirectory), '--script', 'res://tools/bake_city.gd', '--', '--map-size', [string]$citySize, '--original-grid')
        $gridProcess = Start-Process -FilePath $GodotPath -ArgumentList $gridArguments -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $exportDirectory "grid-bake-$citySize.log") -RedirectStandardError (Join-Path $exportDirectory "grid-bake-$citySize.errors.log")
        if ($gridProcess.ExitCode -ne 0) { throw "Original grid bake failed. No release was published." }
    }
    $projectFile = Join-Path $projectDirectory 'project.godot'
    $originalProject = [IO.File]::ReadAllBytes($projectFile)
    $presetsFile = Join-Path $projectDirectory 'export_presets.cfg'
    $originalPresets = if ($Android) { [IO.File]::ReadAllBytes($presetsFile) } else { $null }
    try {
        $projectText = [IO.File]::ReadAllText($projectFile)
        if ($projectText -notmatch '(?m)^config/version="[^"]*"') { throw 'project.godot is missing config/version.' }
        $projectText = [regex]::Replace($projectText, '(?m)^config/version="[^"]*"', ('config/version="' + $Version + '"'))
        if ($projectText -notmatch '(?m)^config/update_repository=') { throw 'project.godot is missing config/update_repository.' }
        $projectText = [regex]::Replace($projectText, '(?m)^config/update_repository="[^"]*"', ('config/update_repository="' + $Repository + '"'))
        [IO.File]::WriteAllText($projectFile, $projectText, (New-Object Text.UTF8Encoding($false)))
        $buildProcess = Start-Process -FilePath $GodotPath -ArgumentList @('--headless', '--path', ('"{0}"' -f $projectDirectory), '--export-release', '"Windows Desktop"', ('"{0}"' -f $buildExe)) -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $exportDirectory 'export.log') -RedirectStandardError (Join-Path $exportDirectory 'export.errors.log')
        if ($buildProcess.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $buildExe)) { throw "Godot export failed. See $exportDirectory\export.errors.log. No release was published." }
        if ($Android) {
            $parts = $Version.Split('.') | ForEach-Object { [long]$_ }
            if ($parts[1] -gt 999 -or $parts[2] -gt 999) { throw 'Android releases require minor and patch version components below 1000.' }
            $androidCode = $parts[0] * 1000000 + $parts[1] * 1000 + $parts[2]
            if ($androidCode -lt 1 -or $androidCode -gt 2100000000) { throw 'Version cannot be represented as an Android version code.' }
            $presetsText = [IO.File]::ReadAllText($presetsFile)
            if ($presetsText -notmatch '(?m)^version/code=(\d+)') { throw 'Android export preset is missing version/code.' }
            if ($androidCode -le [long]$Matches[1]) { throw 'Android version code must increase above the existing preset code.' }
            $presetsText = [regex]::Replace($presetsText, '(?m)^version/code=\d+', ('version/code=' + $androidCode))
            $presetsText = [regex]::Replace($presetsText, '(?m)^version/name="[^"]*"', ('version/name="' + $Version + '"'))
            [IO.File]::WriteAllText($presetsFile, $presetsText, (New-Object Text.UTF8Encoding($false)))
            $builtApk = Join-Path $exportDirectory 'OnTheFly.apk'
            $signingEnvironment = @('GODOT_ANDROID_KEYSTORE_RELEASE_PATH', 'GODOT_ANDROID_KEYSTORE_RELEASE_USER', 'GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD')
            $previousSigning = @{}
            foreach ($name in $signingEnvironment) { $previousSigning[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
            try {
                $localSigning = Join-Path $workspaceRoot '.runtime\signing\android-release.json'
                if (-not $AndroidSigningConfig -and -not $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH -and (Test-Path -LiteralPath $localSigning)) { $AndroidSigningConfig = $localSigning }
                if ($AndroidSigningConfig) {
                    $signing = Get-Content -LiteralPath $AndroidSigningConfig -Raw | ConvertFrom-Json
                    if (-not $signing.keystore -or -not $signing.alias -or -not $signing.password) { throw 'Android signing configuration needs keystore, alias, and password fields.' }
                    $keystorePath = [string]$signing.keystore
                    if (-not [IO.Path]::IsPathRooted($keystorePath)) { $keystorePath = Join-Path ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($AndroidSigningConfig))) $keystorePath }
                    if (-not (Test-Path -LiteralPath $keystorePath -PathType Leaf)) { throw 'Android release keystore file does not exist.' }
                    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $keystorePath
                    $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = [string]$signing.alias
                    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = [string]$signing.password
                }
                $androidProcess = Start-Process -FilePath $GodotPath -ArgumentList @('--headless', '--path', ('"{0}"' -f $projectDirectory), '--export-release', 'Android', ('"{0}"' -f $builtApk)) -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $exportDirectory 'android-export.log') -RedirectStandardError (Join-Path $exportDirectory 'android-export.errors.log')
            } finally {
                foreach ($name in $signingEnvironment) { [Environment]::SetEnvironmentVariable($name, $previousSigning[$name], 'Process') }
                $signing = $null
            }
            if ($androidProcess.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $builtApk)) { throw "Android export failed. See $exportDirectory\android-export.errors.log. No release was published." }
        }
    } finally {
        [IO.File]::WriteAllBytes($projectFile, $originalProject)
        if ($null -ne $originalPresets) { [IO.File]::WriteAllBytes($presetsFile, $originalPresets) }
    }
    $smokeLog = Join-Path $exportDirectory 'smoke.log'
    $smokeProcess = Start-Process -FilePath $buildExe -ArgumentList @('--headless', '--', '--release-smoke-test') -WindowStyle Hidden -PassThru -RedirectStandardOutput $smokeLog -RedirectStandardError (Join-Path $exportDirectory 'smoke.errors.log')
    if (-not $smokeProcess.WaitForExit(90000)) { $smokeProcess.Kill(); throw 'Release smoke test timed out. No release was published.' }
    $smokeProcess.Refresh()
    if ($smokeProcess.ExitCode -ne 0 -or -not (Select-String -LiteralPath $smokeLog -SimpleMatch 'RELEASE SMOKE PASS' -Quiet)) { throw "Release smoke test failed. See $exportDirectory\smoke.errors.log. No release was published." }
    if ($Android) {
        Copy-Item -LiteralPath $builtApk -Destination $apk -Force
        $androidHash = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
        "$androidHash  OnTheFly.apk" | Set-Content -LiteralPath $apkChecksum -Encoding ASCII
        @{ version = $Version; version_code = $androidCode; platform = 'android-arm64'; repository = $Repository; sha256 = $androidHash } | ConvertTo-Json | Set-Content -LiteralPath $apkManifest -Encoding UTF8
    }
    Write-Host "Built $buildExe"
}
$reusePackage = -not $Build -and (Test-Path -LiteralPath $archive) -and (Test-Path -LiteralPath $checksum)
if (-not $Build -and -not $reusePackage) { throw 'No prepared release exists for this version. Run with -Build first; an installed executable cannot be relabeled as a new release.' }
if (-not $reusePackage) {
foreach ($file in $files) {
    $source = Get-PackageSource $file
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Build is missing $file." }
}
[IO.Directory]::CreateDirectory($stageDirectory) | Out-Null
try {
    foreach ($file in $files) {
        $source = Get-PackageSource $file
        Copy-Item -LiteralPath $source -Destination (Join-Path $stageDirectory $file)
    }
    @{ version = $Version; platform = 'windows-x64' } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stageDirectory 'release_manifest.json') -Encoding UTF8
    @{ repository = $Repository; auto_check = $true } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stageDirectory 'updater_config.json') -Encoding UTF8
    Compress-Archive -LiteralPath @($files | ForEach-Object { Join-Path $stageDirectory $_ }) -DestinationPath $archive -CompressionLevel Optimal -Force
    $hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  OnTheFly_Windows.zip" | Set-Content -LiteralPath $checksum -Encoding ASCII
} finally {
    $resolvedStage = [IO.Path]::GetFullPath($stageDirectory)
    $resolvedOutput = [IO.Path]::GetFullPath($outputDirectory)
    if ($resolvedStage.StartsWith($resolvedOutput + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedStage)) { Remove-Item -LiteralPath $resolvedStage -Recurse -Force }
}
} else {
    $hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    $expectedHash = ((Get-Content -LiteralPath $checksum -Raw).Trim() -split '\s+')[0]
    if ($hash -ne $expectedHash) { throw 'The prepared package changed. Rebuild and test it before publishing.' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($archive)
    try {
        foreach ($name in @('release_manifest.json', 'updater_config.json')) {
            $entry = $zip.GetEntry($name)
            if (-not $entry) { throw "Prepared package is missing $name." }
            $reader = New-Object IO.StreamReader($entry.Open())
            try { $data = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
            if ($name -eq 'release_manifest.json' -and $data.version -ne $Version) { throw 'Prepared package has the wrong version.' }
            if ($name -eq 'updater_config.json' -and $data.repository -ne $Repository) { throw 'Prepared package points to another repository. Use -Build with the correct -Repository.' }
        }
    } finally { $zip.Dispose() }
    Write-Host 'Reusing the exact prepared package.'
}
Write-Host "Prepared $archive"
if ($Android) {
    foreach ($required in @($apk, $apkChecksum, $apkManifest)) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw 'Android package is missing. Run with -Build -Android first.' }
    }
    $androidData = Get-Content -LiteralPath $apkManifest -Raw | ConvertFrom-Json
    $actualAndroidHash = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
    $expectedAndroidHash = ((Get-Content -LiteralPath $apkChecksum -Raw).Trim() -split '\s+')[0]
    if ($androidData.version -ne $Version -or $androidData.repository -ne $Repository -or $actualAndroidHash -ne $androidData.sha256 -or $actualAndroidHash -ne $expectedAndroidHash) { throw 'Prepared Android package changed or belongs to another version/repository. Rebuild it before publishing.' }
    Write-Host "Prepared $apk (Android version code $($androidData.version_code))"
}
Write-Host "SHA-256 $hash"
Write-Host 'Clients discover published stable releases through this repository. Running clients with update notifications check every five minutes; older launchers check when opened.'
if (-not $Publish) { Write-Host 'To upload this release, run again with -Publish and GH_TOKEN or GITHUB_TOKEN set.'; return }
if ([string]::IsNullOrWhiteSpace($Token)) { throw 'Publishing requires GH_TOKEN or GITHUB_TOKEN with write access to the release repository.' }
$notes = "OnTheFly $Version"
if ($NotesFile) { $notes = Get-Content -LiteralPath $NotesFile -Raw }
$headers = @{ 'Authorization' = "Bearer $Token"; 'Accept' = 'application/vnd.github+json'; 'User-Agent' = 'OnTheFly-Publisher'; 'X-GitHub-Api-Version' = '2022-11-28' }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$body = @{ tag_name = "v$Version"; name = "OnTheFly $Version"; body = $notes; draft = $true; prerelease = $false }
if ($TargetCommitish) { $body.target_commitish = $TargetCommitish }
$release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases" -Method Post -Headers $headers -ContentType 'application/json' -Body ($body | ConvertTo-Json) -TimeoutSec 30
try {
    $uploadUrl = ($release.upload_url -split '\{')[0]
    $uploadFiles = @($archive, $checksum)
    if ($Android) { $uploadFiles += @($apk, $apkChecksum, $apkManifest) }
    foreach ($file in $uploadFiles) {
        $assetName = [uri]::EscapeDataString([IO.Path]::GetFileName($file))
        $contentType = if ($file.EndsWith('.zip')) { 'application/zip' } elseif ($file.EndsWith('.apk')) { 'application/vnd.android.package-archive' } elseif ($file.EndsWith('.json')) { 'application/json' } else { 'text/plain' }
        $asset = Invoke-RestMethod -Uri ($uploadUrl + '?name=' + $assetName) -Method Post -Headers $headers -ContentType $contentType -InFile $file -TimeoutSec 600
        if ($asset.state -ne 'uploaded') { throw 'GitHub did not finish uploading the asset.' }
    }
    $published = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases/$($release.id)" -Method Patch -Headers $headers -ContentType 'application/json' -Body '{"draft":false,"make_latest":"true"}' -TimeoutSec 30
    Write-Host "Published $($published.html_url)"
    $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases/latest" -Headers $headers -TimeoutSec 30
    if ($latest.tag_name -ne "v$Version") { throw 'Release was published, but the client update feed does not report it as latest. Check the repository releases page.' }
    Write-Host "Client update feed now advertises v$Version."
} catch {
    Write-Warning "Release operation failed. Inspect $($release.html_url) before retrying; the release may be a draft or already published."
    throw
}
