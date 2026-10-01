Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$assetDirectory = [IO.Path]::GetFullPath((Join-Path $projectRoot 'assets\kenney_city\roads'))
if (-not $assetDirectory.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The road asset directory is outside this project.'
}

$tileFiles = Get-ChildItem -LiteralPath $assetDirectory -File | Where-Object {
    ($_.Name.EndsWith('.glb', [StringComparison]::OrdinalIgnoreCase) -or
     $_.Name.EndsWith('.glb.import', [StringComparison]::OrdinalIgnoreCase)) -and
    $_.Name -notin @('sign-highway.glb', 'sign-highway.glb.import')
}

foreach ($file in $tileFiles) {
    Remove-Item -LiteralPath $file.FullName -Force
    Write-Host "Removed $($file.Name)"
}
Write-Host "Removed $($tileFiles.Count) road tile files. Highway sign and colormap retained."
