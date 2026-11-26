[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Folder,
    [Parameter(Mandatory = $true)][string]$ApiBase,
    [string]$SentFolder = 'terkirim',
    [int]$MaxRetries = 3
)

$ErrorActionPreference = 'Stop'

$key = $env:RESEARCH_KEY
if ([string]::IsNullOrWhiteSpace($key)) {
    Write-Error 'Set the RESEARCH_KEY environment variable to the integration API key first.'
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

$endpoint = $ApiBase.TrimEnd('/') + '/integration/v1/research'
$sentDir = Join-Path $Folder $SentFolder
$files = @(Get-ChildItem -LiteralPath $Folder -Filter '*.zip' -File | Sort-Object Name)
if ($files.Count -eq 0) {
    Write-Host 'No .zip files to send.'
    exit 0
}

$headerFile = [System.IO.Path]::GetTempFileName()
Set-Content -LiteralPath $headerFile -Value "Authorization: Bearer $key" -Encoding ascii -NoNewline

$documentTypes = @{
    '.pdf'  = 'application/pdf'
    '.xlsx' = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
}

function Send-File([System.IO.FileInfo]$File, [string]$Url, [string]$ContentType) {
    $bodyFile = [System.IO.Path]::GetTempFileName()
    $headFile = [System.IO.Path]::GetTempFileName()
    try {
        for ($attempt = 1; ; $attempt++) {
            $code = & $curl.Source -sS -o $bodyFile -D $headFile -w '%{http_code}' -X POST $Url `
                -H "@$headerFile" -H "Content-Type: $ContentType" --data-binary "@$($File.FullName)"
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

function Move-Sent([System.IO.FileInfo]$File) {
    if (-not (Test-Path -LiteralPath $sentDir)) { New-Item -ItemType Directory -Path $sentDir | Out-Null }
    $target = Join-Path $sentDir $File.Name
    if (Test-Path -LiteralPath $target) {
        $target = Join-Path $sentDir ("{0}-{1}{2}" -f $File.BaseName, (Get-Date -Format 'yyyyMMddHHmmss'), $File.Extension)
    }
    Move-Item -LiteralPath $File.FullName -Destination $target
}

function Write-Rejected([System.IO.FileInfo]$File, $Result) {
    $reason = 'no response'
    if ($Result.Body) { $reason = "{0}: {1}" -f $Result.Body.error, $Result.Body.message }
    Write-Warning ("{0}: not accepted (HTTP {1}) {2}" -f $File.Name, $Result.Status, $reason)
}

function Get-Documents([System.IO.FileInfo]$Zip) {
    @(Get-ChildItem -LiteralPath $Folder -File |
        Where-Object { $documentTypes.ContainsKey($_.Extension.ToLowerInvariant()) -and
                       $_.Name.StartsWith($Zip.BaseName, [System.StringComparison]::OrdinalIgnoreCase) } |
        Sort-Object Name)
}

$failed = 0
$documentsSent = 0
$documentsFailed = 0
try {
    foreach ($file in $files) {
        $documents = Get-Documents $file
        $result = Send-File $file $endpoint 'application/zip'
        if ($result.Status -ne 200 -and $result.Status -ne 202) {
            $failed++
            Write-Rejected $file $result
            continue
        }
        $state = $result.Body.status
        if ($result.Body.resubmitted) { $state = "$state (already sent)" }
        Write-Host ("{0}: {1}, id {2}" -f $file.Name, $state, $result.Body.id)
        $documentsOk = $true
        foreach ($document in $documents) {
            $url = "{0}/{1}/documents?name={2}" -f $endpoint, $result.Body.id, [uri]::EscapeDataString($document.Name)
            $sent = Send-File $document $url $documentTypes[$document.Extension.ToLowerInvariant()]
            if ($sent.Status -eq 200 -or $sent.Status -eq 202) {
                $documentsSent++
                $docState = $sent.Body.status
                if ($sent.Body.resubmitted) { $docState = "$docState (already sent)" }
                Write-Host ("  {0}: {1}, id {2}" -f $document.Name, $docState, $sent.Body.id)
                Move-Sent $document
                continue
            }
            $documentsFailed++
            $documentsOk = $false
            Write-Rejected $document $sent
        }
        if ($documentsOk) { Move-Sent $file }
    }
} finally {
    Remove-Item -LiteralPath $headerFile -Force -ErrorAction SilentlyContinue
}

Write-Host ("Done: {0} reports sent, {1} not accepted; {2} documents sent, {3} not accepted." -f `
    ($files.Count - $failed), $failed, $documentsSent, $documentsFailed)
if ($failed -gt 0 -or $documentsFailed -gt 0) { exit 1 }
