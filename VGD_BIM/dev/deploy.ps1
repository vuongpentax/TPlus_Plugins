param([string]$PluginRoot = (Join-Path $env:APPDATA 'SketchUp/SketchUp 2022/SketchUp/Plugins'), [switch]$VerifyOnly)
$ErrorActionPreference = 'Stop'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$runtime = Join-Path $project 'runtime'
$destination = [IO.Path]::GetFullPath($PluginRoot).TrimEnd('\')
$owned = @(Get-ChildItem -LiteralPath $runtime -Recurse -File)
function Assert-Path([string]$path) {
  $absolute = [IO.Path]::GetFullPath($path)
  if (-not $absolute.StartsWith($destination + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "Outside Plugins: $absolute" }
  $cursor = $absolute
  while ($cursor.Length -ge $destination.Length) {
    if ((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Refuse reparse point: $cursor" }
    $cursor = [IO.Path]::GetDirectoryName($cursor)
  }
  return $absolute
}
$loader = Assert-Path (Join-Path $destination 'vgd_bim_lite.rb')
if ((Test-Path -LiteralPath $loader) -and -not ([IO.File]::ReadAllText($loader).Contains("SketchupExtension.new('VGD BIM Lite'"))) { throw 'Existing loader is not owned by VGD BIM Lite' }
if ($VerifyOnly) {
  foreach ($file in $owned) {
    $relative = $file.FullName.Substring($runtime.Length + 1)
    $target = Assert-Path (Join-Path $destination $relative)
    if (-not (Test-Path -LiteralPath $target)) { throw "Missing installed file: $relative" }
    if ((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath $target).Hash) { throw "Mismatch: $relative" }
  }
  Write-Output "Verified $($owned.Count) installed VGD BIM files"
  return
}
$backup = Join-Path $project ('outputs/install_' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $backup -Force | Out-Null
foreach ($file in $owned) {
  $relative = $file.FullName.Substring($runtime.Length + 1)
  $target = Assert-Path (Join-Path $destination $relative)
  if (Test-Path -LiteralPath $target) {
    $saved = Join-Path $backup $relative
    New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($saved)) -Force | Out-Null
    Copy-Item -LiteralPath $target -Destination $saved
  }
  New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($target)) -Force | Out-Null
  Copy-Item -LiteralPath $file.FullName -Destination $target -Force
  if ((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath $target).Hash) { throw "Install verification failed: $relative" }
}
@{ Status='VERIFIED'; Target=$destination; Files=$owned.Count; Backup=$backup } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $backup 'INSTALL_REPORT.json') -Encoding utf8
Write-Output "Installed and verified $($owned.Count) VGD BIM files. Restart SketchUp to load. Backup: $backup"
