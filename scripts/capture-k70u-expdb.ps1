param(
    [string]$Adb = 'I:\刷机\root\scrcpy-win64-v3.2\adb.exe',
    [Parameter(Mandatory = $true)][string]$Serial,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [string]$CommandDirectory = 'D:\tmp'
)

$ErrorActionPreference = 'Stop'
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'Capture directory must be new' }
[IO.Directory]::CreateDirectory($output) | Out-Null
[IO.Directory]::CreateDirectory($CommandDirectory) | Out-Null
$captureId = [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId(
    [DateTime]::UtcNow, 'China Standard Time').ToString('yyyyMMdd-HHmmss')
$utf8 = [Text.UTF8Encoding]::new($false)

function Write-NewBytes([string]$Path, [byte[]]$Bytes) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
    try { $stream.Write($Bytes, 0, $Bytes.Length) } finally { $stream.Dispose() }
}

function Save-Command([string]$Name, [string]$Text) {
    $path = Join-Path $CommandDirectory "k70u-expdb-$captureId-$Name.sh"
    $bytes = $utf8.GetBytes($Text.Replace("`r`n", "`n") + "`n")
    Write-NewBytes $path $bytes
    Write-NewBytes (Join-Path $output "$Name.commands.sh") $bytes
    return $path
}

function Invoke-AdbSu([string]$CommandFile, [string]$Destination) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Adb
    foreach ($argument in @('-s', $Serial, 'shell', '-T', 'su')) {
        $start.ArgumentList.Add($argument)
    }
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.StandardInputEncoding = $utf8
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $file = [IO.File]::Open($Destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
    try {
        if (-not $process.Start()) { throw 'adb did not start' }
        $errors = $process.StandardError.ReadToEndAsync()
        # Never pass raw partition bytes through a PowerShell text pipeline.
        $copy = $process.StandardOutput.BaseStream.CopyToAsync($file)
        $process.StandardInput.Write([IO.File]::ReadAllText($CommandFile))
        $process.StandardInput.Close()
        if (-not $process.WaitForExit(120000)) {
            $process.Kill()
            throw 'Owned adb capture process exceeded 120 seconds; partial output retained'
        }
        [void]$copy.GetAwaiter().GetResult()
        $stderr = $errors.GetAwaiter().GetResult()
        Write-NewBytes "$Destination.stderr.txt" ($utf8.GetBytes($stderr))
        if ($process.ExitCode -ne 0) { throw "adb/root command failed: $stderr" }
    } finally {
        $file.Dispose()
        $process.Dispose()
    }
}

$metadataCommand = Save-Command 'metadata' @'
id
printf 'CAPTURE_SIZE='
blockdev --getsize64 /dev/block/by-name/expdb
printf 'CAPTURE_SLOT='
getprop ro.boot.slot_suffix
printf 'CAPTURE_BOOT_COMPLETED='
getprop sys.boot_completed
printf 'CAPTURE_DEVICE='
getprop ro.product.device
printf 'CAPTURE_SHA256='
sha256sum /dev/block/by-name/expdb
exit
'@
$metadataFile = Join-Path $output 'metadata-before.txt'
Invoke-AdbSu $metadataCommand $metadataFile
$metadata = [IO.File]::ReadAllText($metadataFile)
if ($metadata -notmatch 'uid=0\b') { throw 'Root identity was not confirmed' }
$sizeMatch = [regex]::Match($metadata, '(?m)^CAPTURE_SIZE=(\d+)\r?$')
$beforeMatch = [regex]::Match($metadata, '(?m)^CAPTURE_SHA256=([0-9a-fA-F]{64})\s')
if (-not $sizeMatch.Success -or -not $beforeMatch.Success) {
    throw 'Partition size/hash metadata missing; inspect retained metadata'
}
$expectedSize = [long]$sizeMatch.Groups[1].Value
if ($expectedSize -ne 134217728) { throw "Unexpected K70U expdb size: $expectedSize" }

$readCommand = Save-Command 'read' 'exec dd if=/dev/block/by-name/expdb bs=1048576'
$rawFile = Join-Path $output 'expdb.bin'
Invoke-AdbSu $readCommand $rawFile
$transportFile = $rawFile
$transportTransform = 'none'
$actualSize = (Get-Item -LiteralPath $rawFile).Length
if ($actualSize -ne $expectedSize) {
    # Some su implementations add a PTY even when adb uses -T. Accept a
    # reversal only if the complete bytes match the device-side SHA-256.
    $normalized = Join-Path $output 'expdb.raw.bin'
    $normalizer = @'
import hashlib
from pathlib import Path
import sys
data = Path(sys.argv[1]).read_bytes().replace(b'\r\n', b'\n')
if len(data) != int(sys.argv[4]) or hashlib.sha256(data).hexdigest() != sys.argv[3].lower():
    raise SystemExit('Transport reversal does not match device size/hash; raw stream retained')
with Path(sys.argv[2]).open('xb') as output:
    output.write(data)
'@
    $normalizer | & python - $rawFile $normalized $beforeMatch.Groups[1].Value $expectedSize
    if ($LASTEXITCODE -ne 0) { throw 'Raw transport could not be recovered exactly' }
    $rawFile = $normalized
    $actualSize = (Get-Item -LiteralPath $rawFile).Length
    $transportTransform = 'CRLF expansion reversed; exact device size/SHA-256 match required'
}
$localHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $rawFile).Hash.ToLowerInvariant()

$afterCommand = Save-Command 'after' @'
printf 'CAPTURE_SHA256='
sha256sum /dev/block/by-name/expdb
exit
'@
$afterFile = Join-Path $output 'metadata-after.txt'
$afterHash = $null
$afterNote = $null
try {
    Invoke-AdbSu $afterCommand $afterFile
    $after = [IO.File]::ReadAllText($afterFile)
    $afterMatch = [regex]::Match($after, '(?m)^CAPTURE_SHA256=([0-9a-fA-F]{64})\s')
    if (-not $afterMatch.Success) { throw 'Post-capture device hash missing' }
    $afterHash = $afterMatch.Groups[1].Value.ToLowerInvariant()
} catch {
    $afterNote = $_.Exception.Message
}
$beforeHash = $beforeMatch.Groups[1].Value.ToLowerInvariant()
$stable = ($beforeHash -eq $localHash -and $localHash -eq $afterHash)
$record = [ordered]@{
    capture_id = $captureId
    timezone = 'Asia/Shanghai'
    serial = $Serial
    partition = '/dev/block/by-name/expdb'
    local_file = $rawFile
    size = $actualSize
    sha256 = $localHash
    device_sha256_before = $beforeHash
    device_sha256_after = $afterHash
    hash_matches_device_before = ($beforeHash -eq $localHash)
    post_capture_note = $afterNote
    stable_before_during_after = $stable
    transport = 'adb shell -T su with command-file stdin and raw stdout stream'
    transport_file = $transportFile
    transport_transform = $transportTransform
    script_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $PSCommandPath).Hash.ToLowerInvariant()
    device_writes = @()
    metadata_scope = 'Current restored Android state only, not candidate identity'
}
Write-NewBytes (Join-Path $output 'capture.json') ($utf8.GetBytes(($record | ConvertTo-Json -Depth 4) + "`n"))
$record | ConvertTo-Json -Depth 4
if ($beforeHash -ne $localHash) { throw 'Capture does not match the device before-hash' }
if (-not $stable) {
    Write-Warning 'Capture matches the complete device before-hash; after-capture stability is not established'
}
