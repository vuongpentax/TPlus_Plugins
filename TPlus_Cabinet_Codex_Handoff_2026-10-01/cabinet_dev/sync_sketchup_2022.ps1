# Đồng bộ CHỈ T+ Cabinet của dự án này vào SketchUp 2022 trên máy Dừa.
[CmdletBinding()]
param([switch]$VerifyOnly)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourceRoot = Join-Path $projectRoot 'cabinet_work'
$pluginRoot = 'C:\Users\PC\AppData\Roaming\SketchUp\SketchUp 2022\SketchUp\Plugins'
$ownedFiles = @(
    'tplus_cabinet.rb',
    'TPlus_Cabinet\main43.rb', 'TPlus_Cabinet\geometry_engine.rb',
    'TPlus_Cabinet\modeling_rules.rb', 'TPlus_Cabinet\modeling.rb',
    'TPlus_Cabinet\defaults.rb', 'TPlus_Cabinet\draw_tool.rb',
    'TPlus_Cabinet\ui_renderer.rb', 'TPlus_Cabinet\TPlus_Cabinet_UI.html',
    'TPlus_Cabinet\utilities.rb', 'TPlus_Cabinet\reload.rb',
    'TPlus_Cabinet\combine.svg', 'TPlus_Cabinet\untag.svg',
    'TPlus_Cabinet\logo.svg', 'TPlus_Cabinet\HUONG_DAN.txt'
)

function Assert-PlainPath([string]$Path, [string]$Root) {
    $resolvedPath = [IO.Path]::GetFullPath($Path)
    $resolvedRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    if ($resolvedPath -ne $resolvedRoot -and -not $resolvedPath.StartsWith($resolvedRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Đường dẫn nằm ngoài phạm vi T+ Cabinet: $resolvedPath"
    }
    $cursorPath = $resolvedPath
    while ($cursorPath) {
        if (Test-Path -LiteralPath $cursorPath) {
            $item = Get-Item -LiteralPath $cursorPath -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Từ chối junction/symlink: $cursorPath"
            }
        }
        $parentPath = [IO.Path]::GetDirectoryName($cursorPath)
        if ($parentPath -eq $cursorPath) { break }
        $cursorPath = $parentPath
    }
}

Assert-PlainPath $pluginRoot $pluginRoot
if (-not (Test-Path -LiteralPath $pluginRoot -PathType Container)) { throw 'Không tìm thấy Plugins của SketchUp 2022.' }
$installedLoader = Join-Path $pluginRoot 'tplus_cabinet.rb'
if (-not (Test-Path -LiteralPath $installedLoader -PathType Leaf)) { throw 'Không tìm thấy bộ nạp T+ Cabinet hiện tại.' }
Assert-PlainPath $installedLoader $pluginRoot
$loaderText = Get-Content -LiteralPath $installedLoader -Raw
if ($loaderText -notmatch "TPlus_Cabinet/main43\.rb" -or $loaderText -notmatch 'T\+_CABINET') {
    throw 'Bộ nạp đang cài không phải nhánh T+ Cabinet 4.3 đã xác nhận; dừng đồng bộ.'
}

$plan = foreach ($relativePath in $ownedFiles) {
    $sourcePath = Join-Path $sourceRoot $relativePath
    $destinationPath = Join-Path $pluginRoot $relativePath
    Assert-PlainPath $sourcePath $sourceRoot
    Assert-PlainPath $destinationPath $pluginRoot
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "Thiếu mã nguồn: $relativePath" }
    $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    $exists = Test-Path -LiteralPath $destinationPath -PathType Leaf
    $previousHash = if ($exists) { (Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256).Hash } else { $null }
    [pscustomobject]@{
        File = $relativePath; Source = $sourcePath; Destination = $destinationPath
        Existed = $exists; BeforeSHA256 = $previousHash; SourceSHA256 = $sourceHash
        Changed = $sourceHash -ne $previousHash
    }
}
$changedFiles = @($plan | Where-Object Changed)
Write-Output "Phạm vi: riêng T+ Cabinet, SketchUp 2022. File cho phép: $($ownedFiles.Count); thay đổi: $($changedFiles.Count)."
if ($VerifyOnly) {
    $plan | Select-Object File, Changed, Existed | Format-Table -AutoSize
    return
}
if ($changedFiles.Count -eq 0) { Write-Output 'Plugin đang cài đã khớp mã nguồn; không ghi thêm file.'; return }

$backupRoot = Join-Path $projectRoot ('outputs\sketchup_2022_backups\' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
Assert-PlainPath $backupRoot (Join-Path $projectRoot 'outputs\sketchup_2022_backups')
New-Item -ItemType Directory -Path $backupRoot | Out-Null
foreach ($entry in $changedFiles) {
    if ($entry.Existed) {
        $backupPath = Join-Path $backupRoot $entry.File
        New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($backupPath)) -Force | Out-Null
        Copy-Item -LiteralPath $entry.Destination -Destination $backupPath
        if ((Get-FileHash -LiteralPath $backupPath -Algorithm SHA256).Hash -ne $entry.BeforeSHA256) { throw "Sai checksum backup: $($entry.File)" }
    }
}
$receipt = [pscustomobject]@{ Target = $pluginRoot; Backup = $backupRoot; Status = 'BACKED_UP'; Files = @($changedFiles) }
$receiptPath = Join-Path $backupRoot 'SYNC_REPORT.json'
$receipt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $receiptPath -Encoding UTF8
$writtenFiles = [Collections.Generic.List[object]]::new()
try {
    foreach ($entry in $changedFiles) {
        Assert-PlainPath $entry.Destination $pluginRoot
        $currentHash = if ($entry.Existed) { (Get-FileHash -LiteralPath $entry.Destination -Algorithm SHA256).Hash } else { $null }
        if ($currentHash -ne $entry.BeforeSHA256 -or (-not $entry.Existed -and (Test-Path -LiteralPath $entry.Destination))) {
            throw "File đã thay đổi từ lúc sao lưu; dừng đồng bộ: $($entry.File)"
        }
        New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($entry.Destination)) -Force | Out-Null
        $writtenFiles.Add($entry)
        Copy-Item -LiteralPath $entry.Source -Destination $entry.Destination -Force
    }
    foreach ($entry in $plan) {
        if ((Get-FileHash -LiteralPath $entry.Destination -Algorithm SHA256).Hash -ne $entry.SourceSHA256) { throw "Sai checksum sau đồng bộ: $($entry.File)" }
    }
    $receipt.Status = 'VERIFIED'
    $receipt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $receiptPath -Encoding UTF8
} catch {
    foreach ($entry in $writtenFiles) {
        Assert-PlainPath $entry.Destination $pluginRoot
        if ($entry.Existed) {
            Copy-Item -LiteralPath (Join-Path $backupRoot $entry.File) -Destination $entry.Destination -Force
        } elseif (Test-Path -LiteralPath $entry.Destination -PathType Leaf) {
            Remove-Item -LiteralPath $entry.Destination
        }
    }
    $receipt.Status = 'ROLLED_BACK'
    $receipt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $receiptPath -Encoding UTF8
    throw
}
Write-Output "Đã đồng bộ và đối chiếu SHA256 $($plan.Count) file T+ Cabinet."
Write-Output "Sao lưu và biên bản: $receiptPath"
Write-Output 'Trong SketchUp, bấm Extensions > T+ Cabinet — Tiện ích > T+ — Nạp lại mã (Reload).'
