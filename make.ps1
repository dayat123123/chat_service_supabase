<#
.SYNOPSIS
  OLT Social - padanan Makefile untuk Windows (PowerShell 5.1+).

.EXAMPLE
  .\make.ps1 gen-keys
  .\make.ps1 up
  .\make.ps1 logs -Service auth-bridge
  .\make.ps1 gen-keys -Force
  .\make.ps1 restore -File olt-20261029-020000.dump -Yes
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('help', 'up', 'down', 'logs', 'ps', 'reset', 'migrate', 'seed',
                 'test', 'test-db', 'test-bridge', 'test-flutter', 'test-flutter-it',
                 'e2e-windows', 'license-audit', 'smoke', 'backup', 'restore', 'gen-keys', 'psql')]
    [string]$Target = 'help',
    [string]$Service = '',
    [string]$File = '',
    [switch]$Force,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

$EnvFile = 'docker/.env'
$GoImage = 'golang:1.24.5-alpine3.22'
$Compose = @('compose', '-f', 'docker/docker-compose.yml')

function Invoke-Native {
    param([string]$Exe, [string[]]$Arguments)
    # Program native menulis progres ke stderr; di PS 5.1 itu jangan dianggap error.
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $Exe @Arguments } finally { $ErrorActionPreference = $prev }
    # Jangan cetak argumen lengkap: bisa berisi kunci (--dart-define=...KEY=...).
    if ($LASTEXITCODE -ne 0) { throw "$Exe $($Arguments | Select-Object -First 2) gagal (exit $LASTEXITCODE)" }
}

function Invoke-Docker { param([string[]]$Arguments) Invoke-Native 'docker' $Arguments }

function Invoke-Compose { param([string[]]$Arguments) Invoke-Docker ($Compose + $Arguments) }

function Invoke-Tools { param([string[]]$Arguments) Invoke-Compose (@('run', '--rm', 'tools') + $Arguments) }

function Assert-Env {
    if (-not (Test-Path -LiteralPath $EnvFile)) {
        throw 'docker/.env belum ada. Jalankan: .\make.ps1 gen-keys'
    }
    $placeholders = Select-String -LiteralPath $EnvFile -Pattern '=CHANGE_ME' -SimpleMatch
    if ($placeholders) {
        $placeholders | ForEach-Object { Write-Host $_.Line }
        throw 'docker/.env masih berisi CHANGE_ME.'
    }
}

switch ($Target) {
    'help' {
        Write-Host @'
  up            Build & jalankan semua service (migrasi otomatis), tunggu healthy
  down          Hentikan semua service (data tetap ada)
  logs          Ikuti log (filter: -Service auth-bridge)
  ps            Status service
  reset         HAPUS semua volume (DB & storage), lalu naik ulang
  migrate       Jalankan migrasi baru di supabase/migrations
  seed          Isi data dummy development
  test          Tes backend (pgTAP + Go)
  test-db       Tes pgTAP (supabase/tests)
  test-bridge   Unit test auth-bridge (Go, di container)
  test-flutter  Analyze + unit/widget test package Flutter (butuh Flutter SDK)
  test-flutter-it  Integration test package Flutter ke stack lokal
  e2e-windows   E2E app example di Windows (butuh Visual Studio)
  license-audit Audit lisensi dependensi runtime Flutter (tolak GPL/AGPL)
  smoke         Smoke test end-to-end lewat Kong (butuh seed + mode mock)
  backup        Backup DB (+ file storage) ke folder backups/
  restore       Restore DB: -File olt-YYYYMMDD-HHMMSS.dump -Yes
  gen-keys      Buat docker/.env + rahasia baru (-Force untuk menimpa)
  psql          Buka psql ke DB sebagai postgres
'@
    }
    'up' {
        Assert-Env
        Invoke-Compose @('up', '-d', '--build', '--wait', '--wait-timeout', '300')
        Invoke-Compose @('ps')
        $url = (Select-String -LiteralPath $EnvFile -Pattern '^SUPABASE_PUBLIC_URL=(.*)$').Matches[0].Groups[1].Value
        Write-Host "API + Studio: $url"
    }
    'down' { Invoke-Compose @('down') }
    'logs' {
        $logArgs = @('logs', '-f', '--tail=200')
        if ($Service) { $logArgs += $Service }
        Invoke-Compose $logArgs
    }
    'ps' { Invoke-Compose @('ps') }
    'reset' {
        Assert-Env
        Invoke-Compose @('down', '-v', '--remove-orphans')
        & $PSCommandPath up
    }
    'migrate' { Assert-Env; Invoke-Tools @('migrate') }
    'seed' { Assert-Env; Invoke-Tools @('seed') }
    'test-db' { Assert-Env; Invoke-Tools @('test-db') }
    'test-bridge' {
        $src = Join-Path $PSScriptRoot 'services/auth-bridge'
        Invoke-Docker @('run', '--rm', '-v', "${src}:/src", '-w', '/src', $GoImage, 'go', 'test', './...')
    }
    'test' {
        & $PSCommandPath test-db
        & $PSCommandPath test-bridge
    }
    'test-flutter' {
        Push-Location (Join-Path $PSScriptRoot 'packages/olt_social')
        try {
            Invoke-Native 'flutter' @('analyze')
            Invoke-Native 'flutter' @('test')
        } finally { Pop-Location }
    }
    'test-flutter-it' {
        Assert-Env
        Push-Location (Join-Path $PSScriptRoot 'packages/olt_social')
        $env:OLT_SOCIAL_IT = '1'
        try { Invoke-Native 'flutter' @('test', 'test/integration') }
        finally { Remove-Item Env:OLT_SOCIAL_IT; Pop-Location }
    }
    'e2e-windows' {
        Assert-Env
        $anon = (Select-String -LiteralPath $EnvFile -Pattern '^ANON_KEY=(.*)$').Matches[0].Groups[1].Value
        Push-Location (Join-Path $PSScriptRoot 'packages/olt_social/example')
        try { Invoke-Native 'flutter' @('test', 'integration_test', '-d', 'windows', "--dart-define=OLT_SOCIAL_ANON_KEY=$anon") }
        finally { Pop-Location }
    }
    'license-audit' {
        Push-Location (Join-Path $PSScriptRoot 'packages/olt_social')
        try { Invoke-Native 'dart' @('run', 'tool/license_audit.dart') } finally { Pop-Location }
    }
    'smoke' { Assert-Env; Invoke-Tools @('smoke') }
    'backup' {
        Assert-Env
        Invoke-Tools @('backup')
        $backups = Join-Path $PSScriptRoot 'backups'
        $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
        Invoke-Docker @('run', '--rm', '-v', 'olt-social_storage-data:/data:ro', '-v', "${backups}:/backup",
                        'alpine:3.22.7', 'tar', 'czf', "/backup/storage-$stamp.tar.gz", '-C', '/data', '.')
    }
    'restore' {
        Assert-Env
        if (-not $File) { throw 'Sebutkan file: .\make.ps1 restore -File olt-YYYYMMDD-HHMMSS.dump -Yes' }
        $confirm = if ($Yes) { 'yes' } else { 'no' }
        Invoke-Compose @('run', '--rm', '-e', "CONFIRM=$confirm", 'tools', 'restore', $File)
    }
    'gen-keys' {
        # .env mungkin belum ada; interpolasi compose cukup memakai .env.example.
        $keyArgs = @('--env-file', 'docker/.env.example', 'run', '--rm', 'tools', 'gen-keys')
        if ($Force) { $keyArgs += '--force' }
        Invoke-Compose $keyArgs
    }
    'psql' { Assert-Env; Invoke-Tools @('psql') }
}
