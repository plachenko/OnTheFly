$ErrorActionPreference = 'Stop'
$testRoot = Join-Path $PSScriptRoot ('..\.godot\publisher-test-' + [guid]::NewGuid().ToString('N'))
$testRoot = [IO.Path]::GetFullPath($testRoot)
$testProject = Join-Path $testRoot 'Food_Truck_Drive'
$testTools = Join-Path $testProject 'tools'
[IO.Directory]::CreateDirectory((Join-Path $testTools 'updater')) | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Publish_Update.ps1') -Destination $testTools
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\project.godot') -Destination $testProject
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\export_presets.cfg') -Destination $testProject
$testPresetsPath = Join-Path $testProject 'export_presets.cfg'
$testPresetsText = [IO.File]::ReadAllText($testPresetsPath)
$testPresetsText = [regex]::Replace($testPresetsText, '(?m)^version/code=\d+', 'version/code=413')
[IO.File]::WriteAllText($testPresetsPath, $testPresetsText)
Copy-Item -Path (Join-Path $PSScriptRoot 'updater\*') -Destination (Join-Path $testTools 'updater')
'Test readme' | Set-Content -LiteralPath (Join-Path $testProject 'README.txt')
$testGodot = Join-Path $testRoot 'fake-godot.exe'
'Fake engine' | Set-Content -LiteralPath $testGodot
$global:publisherTestEvents = [Collections.Generic.List[string]]::new()
$global:publisherTestPublished = $false
$global:publisherTestExportFails = $false
$global:publisherTestSmokeFails = $false
$global:publisherTestAndroid = $false
function Check([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Start-Process {
    param($FilePath, $ArgumentList, $WindowStyle, [switch]$Wait, [switch]$PassThru, $RedirectStandardOutput, $RedirectStandardError)
    Check ($WindowStyle -eq 'Hidden') 'Build processes must be hidden'
    $exitCode = 0
    if ($ArgumentList -contains '--export-release') {
        $global:publisherTestEvents.Add('export')
        $text = Get-Content -LiteralPath (Join-Path $testProject 'project.godot') -Raw
        Check ($text.Contains('config/version="0.4.14"')) 'Export did not stamp the requested version'
        $exePath = $ArgumentList[-1].Trim('"')
        if ($ArgumentList -contains 'Android') {
            $presets = Get-Content -LiteralPath (Join-Path $testProject 'export_presets.cfg') -Raw
            Check ($presets.Contains('version/code=4014') -and $presets.Contains('version/name="0.4.14"')) 'Android version not stamped'
        }
        [IO.File]::WriteAllBytes($exePath, [byte[]](77,90,1,2))
        if ($global:publisherTestExportFails) { $exitCode = 1 }
    } elseif ($ArgumentList -contains '--release-smoke-test') {
        $global:publisherTestEvents.Add('smoke')
        if ($global:publisherTestSmokeFails) { 'Failed smoke' | Set-Content -LiteralPath $RedirectStandardOutput }
        else { 'RELEASE SMOKE PASS' | Set-Content -LiteralPath $RedirectStandardOutput }
    } else { $global:publisherTestEvents.Add('bake') }
    $process = [pscustomobject]@{ ExitCode = $exitCode }
    $process | Add-Member ScriptMethod WaitForExit { param($Timeout) return $true }
    $process | Add-Member ScriptMethod Refresh { }
    $process | Add-Member ScriptMethod Kill { }
    return $process
}
function Invoke-RestMethod {
    param($Uri, $Method, $Headers, $ContentType, $Body, $TimeoutSec, $InFile)
    if ($Uri.EndsWith('/latest')) {
        $global:publisherTestEvents.Add('latest')
        return @{ tag_name = $(if ($global:publisherTestPublished) { 'v0.4.14' } else { 'v0.4.13' }) }
    }
    if ($Method -eq 'Post' -and $Uri.EndsWith('/releases')) {
        $data = $Body | ConvertFrom-Json
        Check ($data.draft -and -not $data.prerelease) 'Must create a draft first'
        Check ($global:publisherTestEvents.Contains('smoke')) 'Draft created before build validation'
        $global:publisherTestEvents.Add('draft')
        return @{ id = 1; upload_url = 'https://uploads.github.com/repos/owner/game/releases/1/assets{?name,label}'; html_url = 'https://github.com/owner/game/releases/tag/v0.4.14' }
    }
    if ($InFile) {
        Check (Test-Path -LiteralPath $InFile) 'Missing upload asset'
        $global:publisherTestEvents.Add('upload')
        return @{ state = 'uploaded' }
    }
    if ($Method -eq 'Patch') {
        $wanted = if ($global:publisherTestAndroid) { 5 } else { 2 }
        Check (@($global:publisherTestEvents | Where-Object { $_ -eq 'upload' }).Count -eq $wanted) 'Published before all platform assets uploaded'
        $data = $Body | ConvertFrom-Json
        Check (-not $data.draft -and $data.make_latest -eq 'true') 'Release must become the latest stable release'
        $global:publisherTestEvents.Add('publish')
        $global:publisherTestPublished = $true
        return @{ html_url = 'https://github.com/owner/game/releases/tag/v0.4.14' }
    }
    throw "Unexpected request $Method $Uri"
}
try {
    $originalHash = (Get-FileHash -LiteralPath (Join-Path $testProject 'project.godot')).Hash
    & (Join-Path $testTools 'Publish_Update.ps1') -Version 0.4.14 -Repository owner/game -Build -GodotPath $testGodot -Publish -Token test-token
    Check $global:publisherTestPublished 'Publish did not complete'
    Check ((Get-FileHash -LiteralPath (Join-Path $testProject 'project.godot')).Hash -eq $originalHash) 'Project version was not restored'
    $archivePath = Join-Path $testRoot 'Releases\v0.4.14\OnTheFly_Windows.zip'
    $zip = [IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        $reader = [IO.StreamReader]::new($zip.GetEntry('release_manifest.json').Open())
        try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
        Check ($manifest.version -eq '0.4.14') 'Package version does not match release'
        $reader = [IO.StreamReader]::new($zip.GetEntry('Update_Game.ps1').Open())
        try { Check ($reader.ReadToEnd().Contains('$pollTimer.Interval = 300000')) 'Packaged updater is outdated' } finally { $reader.Dispose() }
    } finally { $zip.Dispose() }
    foreach ($failureMode in @('export', 'smoke')) {
        $global:publisherTestExportFails = $failureMode -eq 'export'
        $global:publisherTestSmokeFails = $failureMode -eq 'smoke'
        $failed = $false
        try { & (Join-Path $testTools 'Publish_Update.ps1') -Version 0.4.14 -Repository owner/game -Build -GodotPath $testGodot } catch { $failed = $true }
        Check $failed "Expected $failureMode failure to stop packaging"
        Check ((Get-FileHash -LiteralPath (Join-Path $testProject 'project.godot')).Hash -eq $originalHash) 'Failed build changed project version'
    }
    $failed = $false
    try { & (Join-Path $testTools 'Publish_Update.ps1') -Version 0.4.14 -Repository owner/game -Publish -Token test-token } catch { $failed = $true }
    Check $failed 'Same release version must be rejected'
    $global:publisherTestExportFails = $false
    $global:publisherTestSmokeFails = $false
    $global:publisherTestPublished = $false
    $global:publisherTestAndroid = $true
    $global:publisherTestEvents.Clear()
    $originalPresetHash = (Get-FileHash -LiteralPath (Join-Path $testProject 'export_presets.cfg')).Hash
    & (Join-Path $testTools 'Publish_Update.ps1') -Version 0.4.14 -Repository owner/game -Build -Android -GodotPath $testGodot -Publish -Token test-token
    Check ((Get-FileHash -LiteralPath (Join-Path $testProject 'export_presets.cfg')).Hash -eq $originalPresetHash) 'Android preset was not restored'
    Check ((Get-FileHash -LiteralPath (Join-Path $testProject 'project.godot')).Hash -eq $originalHash) 'Android build changed project settings'
    Check (Test-Path -LiteralPath (Join-Path $testRoot 'Releases\v0.4.14\OnTheFly.apk.sha256')) 'APK checksum missing'
    Write-Host 'PUBLISHER PASS: version stamping/restoration, smoke gate, current updater packaging, draft/upload/publish/feed order, failed builds and duplicate versions rejected (mocked network/engine)'
} finally {
    $expectedRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\.godot'))
    if (-not $testRoot.StartsWith($expectedRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe test cleanup path' }
    Remove-Item -LiteralPath $testRoot -Recurse -Force
}
