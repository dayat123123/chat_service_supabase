[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Folder,
    [Parameter(Mandatory = $true)][string]$ApiBase,
    [string]$SentFolder = 'terkirim',
    [int]$MaxRetries = 3
)

$ErrorActionPreference = 'Stop'

$key = $env:FINREPORT_KEY
if ([string]::IsNullOrWhiteSpace($key)) {
    Write-Error 'Set the FINREPORT_KEY environment variable to the integration API key first.'
    exit 1
}
if (-not (Test-Path -LiteralPath $Folder -PathType Container)) {
    Write-Error "Folder not found: $Folder"
    exit 1
}
$curl = Get-Command curl.exe -ErrorAction SilentlyContinue
if ($null -eq $curl) {
    Write-Error 'curl.exe was not found. It ships with Windows 10 1803 and later.'
    exit 1
}

$endpoint = $ApiBase.TrimEnd('/') + '/integration/v1/financial-reports'
$sentDir = Join-Path $Folder $SentFolder
$files = @(Get-ChildItem -LiteralPath $Folder -Filter '*.zip' -File | Sort-Object Name)
if ($files.Count -eq 0) {
    Write-Host 'No .zip files to send.'
    exit 0
}

$headerFile = [System.IO.Path]::GetTempFileName()
Set-Content -LiteralPath $headerFile -Value "Authorization: Bearer $key" -Encoding ascii -NoNewline

function Send-Report([System.IO.FileInfo]$File) {
    $bodyFile = [System.IO.Path]::GetTempFileName()
    $headFile = [System.IO.Path]::GetTempFileName()
    try {
        for ($attempt = 1; ; $attempt++) {
            $code = & $curl.Source -sS -o $bodyFile -D $headFile -w '%{http_code}' -X POST $endpoint `
                -H "@$headerFile" -H 'Content-Type: application/zip' --data-binary "@$($File.FullName)"
            $status = 0
            [void][int]::TryParse("$code", [ref]$status)
            $body = $null
            $raw = Get-Content -LiteralPath $bodyFile -Raw -ErrorAction SilentlyContinue
            if ($raw) {
                try { $body = $raw | ConvertFrom-Json } catch { $body = $null }
            }
            $busy = $status -eq 429 -or $status -eq 503 -or $status -eq 0
            if (-not $busy -or $attempt -gt $MaxRetries -or ($body -and $body.error -eq 'too_many_auth_failures')) {
                return [pscustomobject]@{ Status = $status; Body = $body }
            }
            $wait = 10
            $retryLine = Select-String -LiteralPath $headFile -Pattern '^Retry-After:\s*(\d+)' | Select-Object -Last 1
            if ($retryLine) { $wait = [Math]::Min(120, [int]$retryLine.Matches[0].Groups[1].Value) }
            Write-Host ("{0}: server busy (HTTP {1}), retrying in {2}s" -f $File.Name, $status, $wait)
            Start-Sleep -Seconds $wait
        }
    } finally {
        Remove-Item -LiteralPath $bodyFile, $headFile -Force -ErrorAction SilentlyContinue
    }
}

$failed = 0
try {
    foreach ($file in $files) {
        $result = Send-Report $file
        if ($result.Status -eq 200 -or $result.Status -eq 202) {
            $state = $result.Body.status
            if ($result.Body.resubmitted) { $state = "$state (already sent)" }
            Write-Host ("{0}: {1}, id {2}" -f $file.Name, $state, $result.Body.id)
            if (-not (Test-Path -LiteralPath $sentDir)) { New-Item -ItemType Directory -Path $sentDir | Out-Null }
            $target = Join-Path $sentDir $file.Name
            if (Test-Path -LiteralPath $target) {
                $target = Join-Path $sentDir ("{0}-{1}{2}" -f $file.BaseName, (Get-Date -Format 'yyyyMMddHHmmss'), $file.Extension)
            }
            Move-Item -LiteralPath $file.FullName -Destination $target
            continue
        }
        $failed++
        $reason = 'no response'
        if ($result.Body) { $reason = "{0}: {1}" -f $result.Body.error, $result.Body.message }
        Write-Warning ("{0}: not accepted (HTTP {1}) {2}" -f $file.Name, $result.Status, $reason)
    }
} finally {
    Remove-Item -LiteralPath $headerFile -Force -ErrorAction SilentlyContinue
}

Write-Host ("Done: {0} sent, {1} not accepted." -f ($files.Count - $failed), $failed)
if ($failed -gt 0) { exit 1 }
