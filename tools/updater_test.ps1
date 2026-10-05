$ErrorActionPreference = 'Stop'
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
. (Join-Path $PSScriptRoot 'updater\Update_Game.ps1') -LibraryOnly
$testRoot = Join-Path $workspace ('Food_Truck_Drive\.godot\updater-test-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($testRoot) | Out-Null
$script:InstallRoot = Join-Path $testRoot 'installed'
$payload = Join-Path $testRoot 'payload'
[IO.Directory]::CreateDirectory($script:InstallRoot) | Out-Null
[IO.Directory]::CreateDirectory($payload) | Out-Null
function Check([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Expect-Failure([scriptblock]$Action) {
    $failed = $false
    try { & $Action } catch { $failed = $true }
    Check $failed 'Expected update to be rejected'
}
try {
    Check ((ConvertTo-Repository 'https://github.com/plachenko/OnTheFly.git') -eq 'plachenko/OnTheFly') 'Repository URL normalization failed'
    Expect-Failure { ConvertTo-Repository 'https://evil.example/owner/repo' }
    Check (Test-NewRelease 'v0.4.1' ([version]'0.4.0')) 'Newer release comparison failed'
    Check (-not (Test-NewRelease 'v0.4.0' ([version]'0.4.0'))) 'Same version must not reinstall'
    Check (-not (Test-NewRelease 'v0.3.9' ([version]'0.4.0'))) 'Downgrades must be rejected'
    Expect-Failure { Test-NewRelease 'v0.4.1-beta' ([version]'0.4.0') }
    [IO.File]::WriteAllBytes((Join-Path $script:InstallRoot 'OnTheFly.exe'), [byte[]](77,90,1,2))
    '{"version":"0.4.0","platform":"windows-x64"}' | Set-Content -LiteralPath (Join-Path $script:InstallRoot 'release_manifest.json')
    'original readme' | Set-Content -LiteralPath (Join-Path $script:InstallRoot 'README.txt')
    '{"repository":"player/custom","auto_check":false}' | Set-Content -LiteralPath (Join-Path $script:InstallRoot 'updater_config.json')
    [IO.File]::WriteAllBytes((Join-Path $payload 'OnTheFly.exe'), [byte[]](77,90,3,4))
    '{"version":"0.4.1","platform":"windows-x64"}' | Set-Content -LiteralPath (Join-Path $payload 'release_manifest.json')
    'new readme' | Set-Content -LiteralPath (Join-Path $payload 'README.txt')
    'new launcher' | Set-Content -LiteralPath (Join-Path $payload 'Update_Game.ps1')
    'new command' | Set-Content -LiteralPath (Join-Path $payload 'Launch_OnTheFly.cmd')
    '{"repository":"publisher/default"}' | Set-Content -LiteralPath (Join-Path $payload 'updater_config.json')
    $zipPath = Join-Path $testRoot 'update.zip'
    Compress-Archive -LiteralPath @(Get-ChildItem -LiteralPath $payload | ForEach-Object FullName) -DestinationPath $zipPath
    $hash = (Get-FileHash -LiteralPath $zipPath).Hash
    $oldHash = (Get-FileHash -LiteralPath (Join-Path $script:InstallRoot 'OnTheFly.exe')).Hash
    Expect-Failure { Install-GamePackage $zipPath ('0' * 64) '0.4.1' }
    Check ((Get-FileHash -LiteralPath (Join-Path $script:InstallRoot 'OnTheFly.exe')).Hash -eq $oldHash) 'Bad checksum changed installation'
    Expect-Failure { Install-GamePackage $zipPath $hash '0.4.2' }
    Check ((Get-InstalledVersion) -eq [version]'0.4.0') 'Manifest mismatch changed installation'
    $locked = [IO.File]::Open((Join-Path $script:InstallRoot 'README.txt'), [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
    try { Expect-Failure { Install-GamePackage $zipPath $hash '0.4.1' } } finally { $locked.Dispose() }
    Check ((Get-FileHash -LiteralPath (Join-Path $script:InstallRoot 'OnTheFly.exe')).Hash -eq $oldHash) 'Rollback failed to restore executable'
    Install-GamePackage $zipPath $hash '0.4.1'
    Check ((Get-InstalledVersion) -eq [version]'0.4.1') 'Installation failed'
    Check ((Get-Content -LiteralPath (Join-Path $script:InstallRoot 'updater_config.json') -Raw | ConvertFrom-Json).repository -eq 'player/custom') 'Player repository settings were overwritten'
    $badZip = Join-Path $testRoot 'traversal.zip'
    $stream = [IO.File]::Create($badZip)
    $archive = New-Object IO.Compression.ZipArchive($stream, [IO.Compression.ZipArchiveMode]::Create)
    $entry = $archive.CreateEntry('../escaped.txt')
    $writer = New-Object IO.StreamWriter($entry.Open())
    $writer.Write('escape'); $writer.Dispose(); $archive.Dispose(); $stream.Dispose()
    Expect-Failure { Install-GamePackage $badZip (Get-FileHash -LiteralPath $badZip).Hash '0.4.2' }
    Check (-not (Test-Path -LiteralPath (Join-Path $testRoot 'escaped.txt'))) 'ZIP path escaped destination'
    Write-Host 'UPDATER PASS: repository parsing, version comparison, checksum rejection, manifest validation, rollback, install, config preservation, ZIP traversal rejection'
} finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $expected = [IO.Path]::GetFullPath((Join-Path $workspace 'Food_Truck_Drive\.godot'))
    if ($resolved.StartsWith($expected + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolved)) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
