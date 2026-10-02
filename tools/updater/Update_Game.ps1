param([switch]$CheckOnOpen, [switch]$LibraryOnly, [string]$PreviewPath)
$ErrorActionPreference = 'Stop'
$script:InstallRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$script:AssetName = 'OnTheFly_Windows.zip'
$script:AllowedFiles = @('OnTheFly.exe', 'README.txt', 'release_manifest.json', 'Launch_OnTheFly.cmd', 'Update_Game.ps1', 'updater_config.json')

function ConvertTo-Repository([string]$Value) {
    $value = $Value.Trim().TrimEnd('/') -replace '^https://github\.com/', '' -replace '\.git$', ''
    if ($value -notmatch '^[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9_][A-Za-z0-9_.-]*$') { throw 'Enter a GitHub repository as owner/repository.' }
    return $value
}

function Get-InstalledVersion {
    $path = Join-Path $script:InstallRoot 'release_manifest.json'
    if (-not (Test-Path -LiteralPath $path)) { return [version]'0.0.0' }
    return [version]((Get-Content -LiteralPath $path -Raw | ConvertFrom-Json).version)
}

function Test-NewRelease([string]$Tag, [version]$Installed) {
    if ($Tag -notmatch '^v?(\d+\.\d+\.\d+)$') { throw 'The release tag must use v1.2.3 format.' }
    return [version]$Matches[1] -gt $Installed
}

function Get-GameRelease([string]$Repository) {
    $repo = ConvertTo-Repository $Repository
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $headers = @{ 'User-Agent' = 'OnTheFly-Updater'; 'Accept' = 'application/vnd.github+json'; 'X-GitHub-Api-Version' = '2022-11-28' }
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers $headers -TimeoutSec 20
    if ($release.draft -or $release.prerelease) { throw 'No stable release is available.' }
    $asset = @($release.assets | Where-Object { $_.name -ceq $script:AssetName -and $_.state -eq 'uploaded' })
    if ($asset.Count -ne 1) { throw "The release is missing $script:AssetName." }
    $checksums = @($release.assets | Where-Object { $_.name -ceq ($script:AssetName + '.sha256') })
    if ($checksums.Count -ne 1) { throw 'The release is missing its checksum file.' }
    foreach ($item in @($asset[0], $checksums[0])) {
        $url = [uri]$item.browser_download_url
        if ($url.Scheme -ne 'https' -or $url.Host -ne 'github.com' -or -not $url.AbsolutePath.StartsWith("/$repo/releases/download/", [StringComparison]::Ordinal)) { throw 'Invalid release download URL.' }
    }
    return @{ Tag = $release.tag_name; Version = $release.tag_name.TrimStart('v'); Asset = $asset[0]; Checksum = $checksums[0] }
}

function Test-GameClosed {
    $game = Join-Path $script:InstallRoot 'OnTheFly.exe'
    foreach ($process in @(Get-Process -Name OnTheFly -ErrorAction SilentlyContinue)) {
        if ([IO.Path]::GetFullPath($process.Path) -eq $game) { throw 'Close OnTheFly before installing the update.' }
    }
}

function Expand-GamePackage([string]$Archive, [string]$Destination) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        $seen = @{}
        $total = 0L
        foreach ($entry in $zip.Entries) {
            # Only flat, known application files can enter the installation.
            if ($entry.FullName -notin $script:AllowedFiles -or $seen.ContainsKey($entry.FullName)) { throw "Unexpected ZIP entry: $($entry.FullName)" }
            $seen[$entry.FullName] = $true
            $total += $entry.Length
            if ($total -gt 1GB) { throw 'The update is too large.' }
        }
        foreach ($required in @('OnTheFly.exe', 'release_manifest.json', 'Update_Game.ps1', 'Launch_OnTheFly.cmd')) {
            if (-not $seen.ContainsKey($required)) { throw "Update is missing $required." }
        }
        [IO.Directory]::CreateDirectory($Destination) | Out-Null
        foreach ($entry in $zip.Entries) {
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $Destination $entry.FullName), $false)
        }
    } finally { $zip.Dispose() }
}

function Install-GamePackage([string]$Archive, [string]$ExpectedHash, [string]$Version) {
    if ($ExpectedHash -notmatch '^[a-fA-F0-9]{64}$') { throw 'Invalid SHA-256 checksum.' }
    if ((Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash -ne $ExpectedHash) { throw 'Download checksum mismatch. The installed game was not changed.' }
    if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid release version.' }
    Test-GameClosed
    $work = Join-Path $script:InstallRoot ('.update-' + [guid]::NewGuid().ToString('N'))
    $stage = Join-Path $work 'stage'
    $backup = Join-Path $work 'backup'
    $changed = @()
    $cleanupWork = $true
    try {
        Expand-GamePackage $Archive $stage
        $manifest = Get-Content -LiteralPath (Join-Path $stage 'release_manifest.json') -Raw | ConvertFrom-Json
        if ($manifest.version -ne $Version -or $manifest.platform -ne 'windows-x64') { throw 'The package version or platform does not match the release.' }
        $exeStream = [IO.File]::OpenRead((Join-Path $stage 'OnTheFly.exe'))
        try { if ($exeStream.ReadByte() -ne 77 -or $exeStream.ReadByte() -ne 90) { throw 'The package does not contain a Windows executable.' } } finally { $exeStream.Dispose() }
        Test-GameClosed
        [IO.Directory]::CreateDirectory($backup) | Out-Null
        foreach ($name in $script:AllowedFiles) {
            if ($name -eq 'updater_config.json') { continue } # Keep the player's chosen repository.
            $source = Join-Path $stage $name
            if (-not (Test-Path -LiteralPath $source)) { continue }
            $target = Join-Path $script:InstallRoot $name
            $existed = Test-Path -LiteralPath $target
            if ($existed -and ((Get-Item -LiteralPath $target).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Update targets must not be symbolic links.' }
            if ($existed) { Copy-Item -LiteralPath $target -Destination (Join-Path $backup $name) }
            $changed += @{ Name = $name; Existed = $existed }
            Copy-Item -LiteralPath $source -Destination $target -Force
        }
    } catch {
        $installError = $_
        try {
            foreach ($entry in $changed) {
                $target = Join-Path $script:InstallRoot $entry.Name
                if ($entry.Existed) { Copy-Item -LiteralPath (Join-Path $backup $entry.Name) -Destination $target -Force }
                elseif (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }
            }
        } catch {
            $cleanupWork = $false
            throw "Update rollback could not finish. Recovery files remain at $backup. $($_.Exception.Message)"
        }
        throw $installError
    } finally {
        # Resolve and check the generated temporary directory before recursive cleanup.
        $resolved = [IO.Path]::GetFullPath($work)
        if ($cleanupWork -and $resolved.StartsWith($script:InstallRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolved)) {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}

if ($LibraryOnly) { return }
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$configPath = Join-Path $script:InstallRoot 'updater_config.json'
$config = @{ repository = ''; auto_check = $true }
if (Test-Path -LiteralPath $configPath) {
    try { $saved = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json; $config.repository = [string]$saved.repository; $config.auto_check = [bool]$saved.auto_check } catch { }
}
$form = New-Object Windows.Forms.Form
$form.Text = 'OnTheFly Launcher'
$form.ClientSize = New-Object Drawing.Size(560, 290)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
function Add-LauncherControl($Control, [int]$X, [int]$Y, [int]$Width, [int]$Height) {
    $Control.Location = New-Object Drawing.Point($X, $Y)
    $Control.Size = New-Object Drawing.Size($Width, $Height)
    $form.Controls.Add($Control)
    return $Control
}
$title = Add-LauncherControl (New-Object Windows.Forms.Label) 22 18 510 28
$title.Text = 'OnTheFly - PLAY AND UPDATE'
$title.Font = New-Object Drawing.Font('Segoe UI', 14, [Drawing.FontStyle]::Bold)
$repoLabel = Add-LauncherControl (New-Object Windows.Forms.Label) 22 58 510 20
$repoLabel.Text = 'Update repository (owner/repository or GitHub URL)'
$repoBox = Add-LauncherControl (New-Object Windows.Forms.TextBox) 22 80 510 26
$repoBox.Text = $config.repository
$auto = Add-LauncherControl (New-Object Windows.Forms.CheckBox) 22 116 510 24
$auto.Text = 'Check for updates when the launcher opens'
$auto.Checked = $config.auto_check
$status = Add-LauncherControl (New-Object Windows.Forms.Label) 22 149 510 60
$status.Text = 'Installed: ' + (Get-InstalledVersion) + '. Enter your release repository, or play offline.'
$check = Add-LauncherControl (New-Object Windows.Forms.Button) 22 222 160 42
$check.Text = 'Check for Updates'
$install = Add-LauncherControl (New-Object Windows.Forms.Button) 196 222 160 42
$install.Text = 'Install Update'
$install.Enabled = $false
$play = Add-LauncherControl (New-Object Windows.Forms.Button) 370 222 160 42
$play.Text = 'Play'
$script:Candidate = $null
function Save-LauncherConfig {
    @{ repository = $repoBox.Text.Trim(); auto_check = $auto.Checked } | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding UTF8
}
$repoBox.Add_TextChanged({ $script:Candidate = $null; $install.Enabled = $false })
$check.Add_Click({
    $check.Enabled = $false
    $install.Enabled = $false
    $status.Text = 'Checking GitHub Releases...'
    $status.Refresh()
    try {
        $script:Candidate = $null
        $repoBox.Text = ConvertTo-Repository $repoBox.Text
        Save-LauncherConfig
        $script:Candidate = Get-GameRelease $repoBox.Text
        if (Test-NewRelease $script:Candidate.Tag (Get-InstalledVersion)) {
            $install.Enabled = $true
            $status.Text = 'Update available: ' + $script:Candidate.Tag + '. Click Install Update.'
        } else { $status.Text = 'You have the latest version: ' + (Get-InstalledVersion) }
    } catch { $status.Text = 'Update check failed: ' + $_.Exception.Message + ' You can still play offline.' }
    finally { $check.Enabled = $true }
})
$install.Add_Click({
    $check.Enabled = $false; $install.Enabled = $false; $play.Enabled = $false
    $download = Join-Path $script:InstallRoot ('.download-' + [guid]::NewGuid().ToString('N') + '.zip')
    try {
        Test-GameClosed
        $status.Text = 'Downloading update...'; $status.Refresh()
        $headers = @{ 'User-Agent' = 'OnTheFly-Updater' }
        $checksum = Invoke-WebRequest -UseBasicParsing -Uri $script:Candidate.Checksum.browser_download_url -Headers $headers -TimeoutSec 30
        $checksumText = if ($checksum.Content -is [byte[]]) { [Text.Encoding]::UTF8.GetString($checksum.Content) } else { [string]$checksum.Content }
        $hash = ($checksumText.Trim() -split '\s+')[0]
        if ($hash -notmatch '^[a-fA-F0-9]{64}$') { throw 'Invalid release checksum.' }
        Invoke-WebRequest -UseBasicParsing -Uri $script:Candidate.Asset.browser_download_url -Headers $headers -OutFile $download -TimeoutSec 300
        $status.Text = 'Verifying and installing update...'; $status.Refresh()
        Install-GamePackage $download $hash $script:Candidate.Version
        $status.Text = 'Updated to ' + (Get-InstalledVersion) + '. Ready to play!'
        $script:Candidate = $null
    } catch { $status.Text = 'Update failed: ' + $_.Exception.Message }
    finally {
        if (Test-Path -LiteralPath $download) { Remove-Item -LiteralPath $download -Force }
        $check.Enabled = $true; $play.Enabled = $true
    }
})
$play.Add_Click({
    try { Save-LauncherConfig; Start-Process -FilePath (Join-Path $script:InstallRoot 'OnTheFly.exe') -WorkingDirectory $script:InstallRoot; $form.Close() }
    catch { $status.Text = $_.Exception.Message }
})
$form.Add_Shown({ if (-not $PreviewPath -and ($auto.Checked -or $CheckOnOpen) -and -not [string]::IsNullOrWhiteSpace($repoBox.Text)) { $check.PerformClick() } })
if ($PreviewPath) {
    $form.Show(); $form.Refresh()
    $bitmap = New-Object Drawing.Bitmap($form.Width, $form.Height)
    try { $form.DrawToBitmap($bitmap, (New-Object Drawing.Rectangle(0, 0, $form.Width, $form.Height))); $bitmap.Save($PreviewPath, [Drawing.Imaging.ImageFormat]::Png) }
    finally { $bitmap.Dispose(); $form.Close(); $form.Dispose() }
    return
}
$form.ShowDialog() | Out-Null
