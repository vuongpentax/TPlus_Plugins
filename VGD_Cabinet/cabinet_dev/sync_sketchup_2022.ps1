[CmdletBinding()]
param([switch]$VerifyOnly)
$ErrorActionPreference = 'Stop'
$taskRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourceRoot = Join-Path $taskRoot 'cabinet_work'
$pluginRoot = Join-Path $env:APPDATA 'SketchUp\SketchUp 2022\SketchUp\Plugins'
$ownedFiles = @('vgd_cabinet.rb','VGD_Cabinet\main43.rb','VGD_Cabinet\geometry_engine.rb','VGD_Cabinet\modeling_rules.rb','VGD_Cabinet\modeling.rb','VGD_Cabinet\pano.rb','VGD_Cabinet\preset_store.rb','VGD_Cabinet\defaults.rb','VGD_Cabinet\draw_tool.rb','VGD_Cabinet\ui_renderer.rb','VGD_Cabinet\VGD_Cabinet_UI.html','VGD_Cabinet\utilities.rb','VGD_Cabinet\reload.rb','VGD_Cabinet\combine.svg','VGD_Cabinet\untag.svg','VGD_Cabinet\logo.svg','VGD_Cabinet\HUONG_DAN.txt')
function Assert-TaskPath([string]$Path,[string]$Root) {
    $full = [IO.Path]::GetFullPath($Path)
    $allowed = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    if ($full -ne $allowed -and -not $full.StartsWith($allowed+'\',[StringComparison]::OrdinalIgnoreCase)) { throw "Ngoài phạm vi: $full" }
    $cursor = $full
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Junction/symlink không được phép: $cursor" }
        }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }; $cursor = $parent
    }
}
Assert-TaskPath $pluginRoot $pluginRoot
if (-not (Test-Path -LiteralPath $pluginRoot -PathType Container)) { throw 'Không tìm thấy Plugins SU 2022.' }
$loader = Join-Path $pluginRoot 'vgd_cabinet.rb'
Assert-TaskPath $loader $pluginRoot
if (Test-Path -LiteralPath $loader) {
    $text = Get-Content -LiteralPath $loader -Raw
    if ($text -notmatch 'VGD_Cabinet/main43' -or $text -notmatch 'module VGD_Cabinet') { throw 'Loader hiện tại không thuộc VGD_Cabinet; từ chối ghi đè.' }
}
# Explicit predecessor only. Keep its runtime files inert for recovery; never scan other extensions.
$legacy = Join-Path $pluginRoot 'tplus_cabinet.rb'
Assert-TaskPath $legacy $pluginRoot
$legacyHash = $null
if (Test-Path -LiteralPath $legacy) {
    $text = Get-Content -LiteralPath $legacy -Raw
    if ($text -notmatch 'TPlus_Cabinet/main43' -or $text -notmatch 'module TPlus_Cabinet') { throw 'Bộ nạp cũ không thuộc T+ Cabinet; từ chối di chuyển.' }
    $legacyHash = (Get-FileHash -LiteralPath $legacy -Algorithm SHA256).Hash
}
$plan = @(foreach ($relative in $ownedFiles) {
    $src = Join-Path $sourceRoot $relative; $dst = Join-Path $pluginRoot $relative
    Assert-TaskPath $src $sourceRoot; Assert-TaskPath $dst $pluginRoot
    $hash = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash
    $exists = Test-Path -LiteralPath $dst -PathType Leaf
    $before = if ($exists) { (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash } else { $null }
    [PSCustomObject]@{File=$relative;Source=$src;Destination=$dst;SourceSHA256=$hash;BeforeSHA256=$before;Existed=$exists;Changed=$before -ne $hash}
})
if ($VerifyOnly) {
    $plan | Select-Object File,Existed,Changed | Format-Table -AutoSize
    Write-Output ("T+ Cabinet loader còn bật: " + [bool]$legacyHash)
    return
}
$backupRoot = Join-Path $taskRoot ('outputs\install_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
Assert-TaskPath $backupRoot $taskRoot
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
foreach ($entry in $plan | Where-Object Changed) {
    if ($entry.Existed) {
        $backup = Join-Path $backupRoot $entry.File
        Assert-TaskPath $backup $backupRoot
        New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($backup)) -Force | Out-Null
        Copy-Item -LiteralPath $entry.Destination -Destination $backup
        if ((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash -ne $entry.BeforeSHA256) { throw 'Sao lưu không khớp.' }
    }
}
$legacyBackup = Join-Path $backupRoot 'legacy\tplus_cabinet.rb'
Assert-TaskPath $legacyBackup $backupRoot
if ($legacyHash) {
    New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($legacyBackup)) -Force | Out-Null
    Copy-Item -LiteralPath $legacy -Destination $legacyBackup
    if ((Get-FileHash -LiteralPath $legacyBackup -Algorithm SHA256).Hash -ne $legacyHash) { throw 'Sao lưu bộ nạp cũ không khớp.' }
}
$written = @()
$legacyDisabled = $false
try {
    foreach ($entry in $plan | Where-Object Changed) {
        $written += $entry
        New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($entry.Destination)) -Force | Out-Null
        Copy-Item -LiteralPath $entry.Source -Destination $entry.Destination -Force
    }
    foreach ($entry in $plan) {
        if ((Get-FileHash -LiteralPath $entry.Destination -Algorithm SHA256).Hash -ne $entry.SourceSHA256) { throw "Sai SHA256: $($entry.File)" }
    }
    if ($legacyHash) {
        if ((Get-FileHash -LiteralPath $legacy -Algorithm SHA256).Hash -ne $legacyHash) { throw 'Bộ nạp T+ Cabinet đã đổi trong lúc cài.' }
        Assert-TaskPath $legacy $pluginRoot
        Remove-Item -LiteralPath $legacy
        $legacyDisabled = $true
    }
    [PSCustomObject]@{Target=$pluginRoot;Status='VERIFIED';LegacyLoaderDisabled=$legacyDisabled;LegacyBackup=$legacyBackup;Files=$plan} |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $backupRoot 'INSTALL_REPORT.json') -Encoding UTF8
} catch {
    if ($legacyDisabled) { Copy-Item -LiteralPath $legacyBackup -Destination $legacy }
    foreach ($entry in $written) {
        Assert-TaskPath $entry.Destination $pluginRoot
        if ($entry.Existed) {
            Copy-Item -LiteralPath (Join-Path $backupRoot $entry.File) -Destination $entry.Destination -Force
        } elseif (Test-Path -LiteralPath $entry.Destination -PathType Leaf) {
            Remove-Item -LiteralPath $entry.Destination
        }
    }
    throw
}
Write-Output ("Đã cài VGD_Cabinet vào SketchUp 2022; {0}/{0} file khớp SHA256. T+ Cabinet loader đã tắt: {1}. Backup: {2}" -f $plan.Count,$legacyDisabled,$backupRoot)
