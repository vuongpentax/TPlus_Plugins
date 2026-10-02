param([switch]$VerifyOnly, [switch]$RetireLegacy, [string]$PluginRoot = (Join-Path $env:APPDATA 'SketchUp\SketchUp 2022\SketchUp\Plugins'))
$ErrorActionPreference = 'Stop'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$pluginRoot = [IO.Path]::GetFullPath($PluginRoot).TrimEnd('\')
$runtime = Join-Path $project 'runtime'
$owned = @('vgd_scenes.rb','vgd_scenes\utils.rb','vgd_scenes\geometry.rb','vgd_scenes\scenes.rb','vgd_scenes\frame.rb','vgd_scenes\export.rb','vgd_scenes\main.rb','vgd_scenes\dialog.html','vgd_scenes\dialog.css','vgd_scenes\dialog.js','vgd_scenes\icon.svg')
$legacy = Join-Path $pluginRoot 'tplus_scenes_to_layout.rb'
$retired = Join-Path $pluginRoot 'tplus_scenes_to_layout.rb.vgd-disabled'
function Assert-Target([string]$path) {
  $absolute = [IO.Path]::GetFullPath($path)
  if (-not $absolute.StartsWith($pluginRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "Target outside Plugins: $absolute" }
  $cursor = $absolute
  while ($cursor.Length -ge $pluginRoot.Length) {
    if ((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Refuse reparse point: $cursor" }
    $cursor = [IO.Path]::GetDirectoryName($cursor)
  }
  return $absolute
}
function Other-Hashes {
  $result = @{}
  foreach ($file in Get-ChildItem -LiteralPath $pluginRoot -File -Recurse -Force) {
    $relative = $file.FullName.Substring($pluginRoot.Length + 1)
    if ($relative -eq 'vgd_scenes.rb' -or $relative.StartsWith('vgd_scenes\',[StringComparison]::OrdinalIgnoreCase) -or $relative -eq 'tplus_scenes_to_layout.rb' -or $relative -eq 'tplus_scenes_to_layout.rb.vgd-disabled') { continue }
    $result[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
  }
  return $result
}
foreach ($relative in $owned) {
  $null = Assert-Target (Join-Path $pluginRoot $relative)
  if (-not (Test-Path -LiteralPath (Join-Path $runtime $relative) -PathType Leaf)) { throw "Missing runtime: $relative" }
}
$null = Assert-Target $legacy
$null = Assert-Target $retired
$ownLoader = Join-Path $pluginRoot 'vgd_scenes.rb'
if (Test-Path -LiteralPath $ownLoader) {
  if ((Get-Content -LiteralPath $ownLoader -Raw) -notmatch "SketchupExtension.new\('VGD Scenes'") { throw 'Existing vgd_scenes.rb is not owned by VGD Scenes.' }
} elseif (Test-Path -LiteralPath (Join-Path $pluginRoot 'vgd_scenes')) { throw 'Existing vgd_scenes folder has no verified VGD loader.' }
if ($RetireLegacy -and (Test-Path -LiteralPath $legacy)) {
  $reviewedHash = '39689D7C9CCB6B1C7AFC68B99E3AD102B4BC6ADE1B6F9CB1377125EB55F31287'
  if ((Get-FileHash -LiteralPath $legacy).Hash -ne $reviewedHash) { throw 'Old loader differs from reviewed version; do not retire automatically.' }
  if (Test-Path -LiteralPath $retired) { throw 'Retired loader already exists; refuse overwrite.' }
}
if ($VerifyOnly) { Write-Output 'Verified: 11 exact VGD targets and reviewed legacy loader. Other plugins excluded.'; exit 0 }
$backup = Join-Path $project ('outputs\install_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
$null = New-Item -ItemType Directory -Path $backup
$before = Other-Hashes
$previous = @{}
$didRetire = $false
try {
  foreach ($relative in $owned) {
    $destination = Assert-Target (Join-Path $pluginRoot $relative)
    $previous[$relative] = Test-Path -LiteralPath $destination
    if ($previous[$relative]) {
      $saved = Join-Path $backup $relative
      $null = New-Item -ItemType Directory -Path (Split-Path $saved) -Force
      Copy-Item -LiteralPath $destination -Destination $saved
    }
  }
  $null = New-Item -ItemType Directory -Path (Assert-Target (Join-Path $pluginRoot 'vgd_scenes')) -Force
  foreach ($relative in $owned) {
    $source = Join-Path $runtime $relative
    $destination = Assert-Target (Join-Path $pluginRoot $relative)
    Copy-Item -LiteralPath $source -Destination $destination -Force
    if ((Get-FileHash -LiteralPath $source).Hash -ne (Get-FileHash -LiteralPath $destination).Hash) { throw "Copy mismatch: $relative" }
  }
  if ($RetireLegacy -and (Test-Path -LiteralPath $legacy)) {
    Copy-Item -LiteralPath $legacy -Destination (Join-Path $backup 'tplus_scenes_to_layout.rb')
    Move-Item -LiteralPath $legacy -Destination $retired
    $didRetire = $true
  }
  $after = Other-Hashes
  $changed = @(@($before.Keys + $after.Keys) | Sort-Object -Unique | Where-Object { $before[$_] -ne $after[$_] })
  $report = [ordered]@{ installed_at=(Get-Date -Format o); plugin_root=$pluginRoot; version='1.0.0'; installed_files=$owned; other_files_checked=$before.Count; other_files_changed=$changed; legacy_loader_retired=$didRetire; backup=$backup }
  $report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $backup 'install_report.json') -Encoding utf8
  if ($changed.Count) { throw "Other plugin files changed during install: $($changed -join ', ')" }
  Write-Output ($report | ConvertTo-Json -Depth 5)
} catch {
  foreach ($relative in $previous.Keys) {
    $destination = Assert-Target (Join-Path $pluginRoot $relative)
    if ($previous[$relative]) { Copy-Item -LiteralPath (Join-Path $backup $relative) -Destination $destination -Force }
    elseif (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination }
  }
  if ($didRetire) { Move-Item -LiteralPath $retired -Destination $legacy }
  throw
}
