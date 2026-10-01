[CmdletBinding()]
param([switch]$VerifyOnly)
$ErrorActionPreference = 'Stop'
$taskRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourceRoot = Join-Path $taskRoot 'runtime'
$pluginRoot = 'C:\Users\PC\AppData\Roaming\SketchUp\SketchUp 2022\SketchUp\Plugins'
$ownedFiles = @('tplus_dim.rb','TPlus_Dim\main.rb','TPlus_Dim\defaults.rb','TPlus_Dim\font_book.rb','TPlus_Dim\custom_dim.rb','TPlus_Dim\profile.rb','TPlus_Dim\reload.rb','TPlus_Dim\engine.rb','TPlus_Dim\dialog.html','TPlus_Dim\dialog.css','TPlus_Dim\dialog.js','TPlus_Dim\dim.svg')
$fontNames = @('UTM-Avo','UTM-Avobold','UTM-Avoitalic','UTM-Avobold-Italic','Roboto-Regular','Roboto-Bold','Roboto-Italic','Roboto-BoldItalic','RobotoCondensed-Regular','RobotoCondensed-Bold','RobotoCondensed-Italic','RobotoCondensed-BoldItalic')
foreach ($fontName in $fontNames) { foreach ($extension in @('ttf','json')) { $ownedFiles += "TPlus_Dim\fonts\$fontName.$extension" } }
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
$loader = Join-Path $pluginRoot 'tplus_dim.rb'
if (Test-Path -LiteralPath $loader) {
    $text = Get-Content -LiteralPath $loader -Raw
    if ($text -notmatch 'TPlus_Dim/main' -or $text -notmatch 'module Dim') { throw 'Loader hiện tại không thuộc T+ Dim; từ chối ghi đè.' }
}
$plan = foreach ($relative in $ownedFiles) {
    $src = Join-Path $sourceRoot $relative; $dst = Join-Path $pluginRoot $relative
    Assert-TaskPath $src $sourceRoot; Assert-TaskPath $dst $pluginRoot
    $hash = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash
    $exists = Test-Path -LiteralPath $dst -PathType Leaf
    $before = if ($exists) { (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash } else { $null }
    [PSCustomObject]@{File=$relative;Source=$src;Destination=$dst;SourceSHA256=$hash;BeforeSHA256=$before;Existed=$exists;Changed=$before -ne $hash}
}
if ($VerifyOnly) { $plan | Select-Object File,Existed,Changed | Format-Table -AutoSize; return }
$backupRoot = Join-Path $taskRoot ('outputs\install_'+(Get-Date -Format 'yyyyMMdd_HHmmss'))
Assert-TaskPath $backupRoot $taskRoot
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
foreach ($entry in $plan | Where-Object Changed) {
    if ($entry.Existed) {
        $backup = Join-Path $backupRoot $entry.File
        New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($backup)) -Force | Out-Null
        Copy-Item -LiteralPath $entry.Destination -Destination $backup
        if ((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash -ne $entry.BeforeSHA256) { throw 'Sao lưu không khớp.' }
    }
}
foreach ($entry in $plan | Where-Object Changed) {
    New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($entry.Destination)) -Force | Out-Null
    Copy-Item -LiteralPath $entry.Source -Destination $entry.Destination -Force
}
foreach ($entry in $plan) {
    if ((Get-FileHash -LiteralPath $entry.Destination -Algorithm SHA256).Hash -ne $entry.SourceSHA256) { throw "Sai SHA256: $($entry.File)" }
}
[PSCustomObject]@{Target=$pluginRoot;Status='VERIFIED';Files=@($plan)} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $backupRoot 'INSTALL_REPORT.json') -Encoding UTF8
Write-Output ("Đã cài T+ Dim vào SketchUp 2022; {0}/{0} file khớp SHA256. Không đổi registry, toolbar hoặc plugin khác." -f $plan.Count)
