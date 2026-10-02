param(
    [Parameter(Mandatory = $true)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version,
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9_][A-Za-z0-9_.-]*$')][string]$Repository = 'plachenko/OnTheFly',
    [string]$NotesFile,
    [string]$TargetCommitish,
    [switch]$Build,
    [string]$GodotPath,
    [switch]$Publish,
    [string]$Token = $(if ($env:GH_TOKEN) { $env:GH_TOKEN } else { $env:GITHUB_TOKEN })
)
$ErrorActionPreference = 'Stop'
$workspaceRoot = if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Food_Truck_Drive')) { $PSScriptRoot } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..')) }
$buildDirectory = Join-Path $workspaceRoot 'OnTheFly_Windows'
$projectDirectory = if (Test-Path -LiteralPath (Join-Path $workspaceRoot 'Food_Truck_Drive\project.godot')) { Join-Path $workspaceRoot 'Food_Truck_Drive' } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')) }
$outputDirectory = Join-Path $workspaceRoot ('Releases\v' + $Version)
$stageDirectory = Join-Path $outputDirectory ('stage-' + [guid]::NewGuid().ToString('N'))
$archive = Join-Path $outputDirectory 'OnTheFly_Windows.zip'
$checksum = $archive + '.sha256'
$files = @('OnTheFly.exe', 'README.txt', 'release_manifest.json', 'Launch_OnTheFly.cmd', 'Update_Game.ps1', 'updater_config.json')
$buildExe = Join-Path $buildDirectory 'OnTheFly.exe'
function Get-PackageSource([string]$Name) {
    if ($Name -eq 'OnTheFly.exe') { return $buildExe }
    $source = Join-Path $buildDirectory $Name
    if (Test-Path -LiteralPath $source) { return $source }
    if ($Name -eq 'README.txt') { return (Join-Path $projectDirectory 'README.txt') }
    return (Join-Path $projectDirectory ('tools\updater\' + $Name))
}
if ($Build) {
    if (-not $GodotPath) { $GodotPath = Join-Path $projectDirectory '.godot\export_runtime\GodotExport.exe' }
    if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw 'Supply -GodotPath pointing to a Godot editor with Windows export templates.' }
    # Export to a fresh path so building never replaces a running game.
    $exportDirectory = Join-Path $outputDirectory ('build-' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($exportDirectory) | Out-Null
    $buildExe = Join-Path $exportDirectory 'OnTheFly.exe'
    $buildProcess = Start-Process -FilePath $GodotPath -ArgumentList @('--headless', '--path', ('"{0}"' -f $projectDirectory), '--export-release', '"Windows Desktop"', ('"{0}"' -f $buildExe)) -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $exportDirectory 'export.log') -RedirectStandardError (Join-Path $exportDirectory 'export.errors.log')
    if ($buildProcess.ExitCode -ne 0) { throw "Godot export failed. See $exportDirectory\export.errors.log. No release was published." }
    Write-Host "Built $buildExe"
}
$reusePackage = -not $Build -and (Test-Path -LiteralPath $archive) -and (Test-Path -LiteralPath $checksum)
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
Write-Host "SHA-256 $hash"
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
    foreach ($file in @($archive, $checksum)) {
        $assetName = [uri]::EscapeDataString([IO.Path]::GetFileName($file))
        $contentType = if ($file.EndsWith('.zip')) { 'application/zip' } else { 'text/plain' }
        $asset = Invoke-RestMethod -Uri ($uploadUrl + '?name=' + $assetName) -Method Post -Headers $headers -ContentType $contentType -InFile $file -TimeoutSec 600
        if ($asset.state -ne 'uploaded') { throw 'GitHub did not finish uploading the asset.' }
    }
    $published = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases/$($release.id)" -Method Patch -Headers $headers -ContentType 'application/json' -Body '{"draft":false,"make_latest":"true"}' -TimeoutSec 30
    Write-Host "Published $($published.html_url)"
} catch {
    Write-Warning "Upload failed; the draft release is preserved at $($release.html_url). Complete or remove it before retrying this version."
    throw
}
