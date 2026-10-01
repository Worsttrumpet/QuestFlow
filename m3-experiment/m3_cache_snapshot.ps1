# M3 cache snapshot: read-only. Records path, existence, size, timestamp,
# SHA-256, and (for .wdb files only) the documented 24-byte WDB header
# fields. Never reads past the header; never decrypts or decodes record
# content. Nothing here modifies the client.
#
# Usage:
#   .\m3_cache_snapshot.ps1 -ForeverRoot "E:\World of Warcraft\_classic_beta_" -Label before
#   ... perform the quest lifecycle manually ...
#   .\m3_cache_snapshot.ps1 -ForeverRoot "E:\World of Warcraft\_classic_beta_" -Label after
#
# Writes m3_cache_snapshot_<label>.json in the current directory.

param(
    [Parameter(Mandatory=$true)][string]$ForeverRoot,
    [Parameter(Mandatory=$true)][string]$Label
)

function Read-WdbHeader {
    param([string]$Path)
    # 24-byte WDB header per wowdev.wiki/WDB and addonstudio.org/wiki/WoW:Questcache.wdb:
    #   0x00 char[4]  magic (file-format signature, e.g. "WQST" for QuestCache.wdb)
    #   0x04 uint32   client version ("build", little-endian)
    #   0x08 char[4]  locale, stored REVERSED
    #   0x0C uint32   record size (internal structure size, not file size)
    #   0x10 uint32   record version
    #   0x14 uint32   cache version
    # [2nd] until checked against a real file here -- this function only reads
    # bytes and reports them; it does not decrypt or interpret record payloads.
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 24) {
        return [ordered]@{ readable = $false; reason = "file is $($bytes.Length) bytes, shorter than the 24-byte WDB header" }
    }
    $magic = [System.Text.Encoding]::ASCII.GetString($bytes, 0, 4)
    $clientVersion = [System.BitConverter]::ToUInt32($bytes, 4)
    $localeRaw = [System.Text.Encoding]::ASCII.GetString($bytes, 8, 4)
    $localeReversed = -join ($localeRaw.ToCharArray() | ForEach-Object { $_ })[-1..-4]
    $recordSize = [System.BitConverter]::ToUInt32($bytes, 12)
    $recordVersion = [System.BitConverter]::ToUInt32($bytes, 16)
    $cacheVersion = [System.BitConverter]::ToUInt32($bytes, 20)
    return [ordered]@{
        readable = $true
        magic = $magic
        client_version_raw = $clientVersion
        locale_raw_bytes = $localeRaw
        locale_reversed_guess = $localeReversed
        record_size = $recordSize
        record_version = $recordVersion
        cache_version = $cacheVersion
        note = "[2nd]-documented layout, read here for the first time on this client -- not yet independently confirmed"
    }
}

function Read-DBCacheMagic {
    param([string]$Path)
    # db2tool (wowsims/mop, MIT, commit adbbb98...) hard-codes the hotfix
    # container magic as "XFTH" (tools/db2tool/wdc/hotfix.go). This checks
    # only the first 4 bytes -- no further structure is parsed here.
    $bytes = New-Object byte[] 4
    $stream = [System.IO.File]::OpenRead($Path)
    try { [void]$stream.Read($bytes, 0, 4) } finally { $stream.Close() }
    $magic = [System.Text.Encoding]::ASCII.GetString($bytes)
    return [ordered]@{
        first_4_bytes_ascii = $magic
        matches_known_hotfix_magic_XFTH = ($magic -eq "XFTH")
    }
}

function Get-FileRecord {
    param([System.IO.FileInfo]$File, [string]$Kind)
    $hash = (Get-FileHash -Path $File.FullName -Algorithm SHA256).Hash
    $rec = [ordered]@{
        path = $File.FullName
        exists = $true
        size_bytes = $File.Length
        last_write_time = $File.LastWriteTime.ToString("o")
        sha256 = $hash
    }
    if ($Kind -eq "wdb") {
        $rec.wdb_header = Read-WdbHeader -Path $File.FullName
    } elseif ($Kind -eq "dbcache") {
        $rec.dbcache_check = Read-DBCacheMagic -Path $File.FullName
    }
    return $rec
}

Write-Host "Scanning $ForeverRoot\Cache for *.wdb and DBCache.bin (metadata + header only, no content decode)..."

$cacheRoot = Join-Path $ForeverRoot "Cache"
$results = [ordered]@{
    label = $Label
    forever_root = $ForeverRoot
    cache_root = $cacheRoot
    cache_root_exists = (Test-Path $cacheRoot)
    scanned_at = (Get-Date).ToString("o")
    wdb_files = @()
    dbcache_files = @()
}

if (Test-Path $cacheRoot) {
    Get-ChildItem -Path $cacheRoot -Recurse -Filter "*.wdb" -File -ErrorAction SilentlyContinue | ForEach-Object {
        $results.wdb_files += (Get-FileRecord -File $_ -Kind "wdb")
    }
    Get-ChildItem -Path $cacheRoot -Recurse -Filter "DBCache.bin" -File -ErrorAction SilentlyContinue | ForEach-Object {
        $results.dbcache_files += (Get-FileRecord -File $_ -Kind "dbcache")
    }
}

$outFile = "m3_cache_snapshot_$Label.json"
$results | ConvertTo-Json -Depth 10 | Set-Content -Path $outFile -Encoding UTF8

Write-Host "Wrote $outFile"
Write-Host ("wdb files found: {0}" -f $results.wdb_files.Count)
Write-Host ("DBCache.bin files found: {0}" -f $results.dbcache_files.Count)
if ($results.wdb_files.Count -eq 0 -and $results.dbcache_files.Count -eq 0) {
    Write-Host "No matching files found under Cache\ -- this is itself a real, useful result (record it as such, not as an error)."
}
