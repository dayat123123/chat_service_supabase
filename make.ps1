<#
.SYNOPSIS
  OLT Social - padanan Makefile untuk Windows (PowerShell 5.1+).

.EXAMPLE
  .\make.ps1 gen-secrets
  .\make.ps1 up                            (profil dev: http://localhost:8000)
  .\make.ps1 up -Profile single            (produksi 1 server; butuh PROXY_DOMAIN & ACME_EMAIL)
  .\make.ps1 logs -Service auth-bridge
  .\make.ps1 restore -File olt-20261029-020000.dump -Yes
  .\make.ps1 up -DummyOlt                  (OLT dummy + auth-bridge mode websocket)
  .\make.ps1 dummy-token -User sari_invest -Ttl 1h
  .\make.ps1 up -Profile single -Cs        (produksi dengan customer service lewat chat)
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('help', 'up', 'down', 'logs', 'ps', 'reset', 'migrate', 'seed',
                 'test', 'test-db', 'test-bridge', 'test-flutter', 'test-flutter-it',
                 'e2e-windows', 'web-example', 'license-audit', 'smoke', 'backup', 'restore',
                 'gen-secrets', 'gen-keys', 'anon-key', 'admin-up', 'admin-down', 'psql',
                 'dummy-token', 'smoke-dummy', 'test-dummy-olt', 'test-flutter-it-dummy', 'e2e-windows-dummy',
                 'test-cs', 'smoke-cs')]
    [string]$Target = 'help',
    # dev (default) | single | cluster - lihat docs/PROMPT-PRODUCTION.md bagian 1.
    [Alias('Profile')]
    [ValidateSet('dev', 'single', 'cluster')]
    [string]$DeployProfile = 'dev',
    [string]$Service = '',
    [string]$File = '',
    [switch]$Force,
    [switch]$Yes,
    # OLT dummy + auth-bridge mode websocket (hanya profil dev).
    [switch]$DummyOlt,
    # Customer service lewat chat di profil single (di profil dev selalu aktif).
    [switch]$Cs,
    [string]$User = 'budi_santoso',
    [string]$Ttl = ''
)

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

$EnvFile = 'docker/.env'
$SecretsDir = 'docker/secrets'
$SecretNames = @('postgres_password', 'jwt_secret', 'anon_key', 'service_role_key', 'dashboard_password',
                 'secret_key_base', 'realtime_db_enc_key', 'realtime_erlang_cookie', 'pg_meta_crypto_key',
                 's3_protocol_access_key_id', 's3_protocol_access_key_secret', 'valkey_password', 'postgrest_db_uri',
                 'olt_customer_service_token')
$GoImage = 'golang:1.27.3-alpine3.24@sha256:d200d2dd76b03a99b52651fd1325aff7dcd35422c35c01bac56571b0507f3deb'
$AlpineImage = 'alpine:3.22.7@sha256:2e0b81d60597f449baa56dc25d355367869d2dca4cd57e866f1e2b52af3eb55f'
$ToolsImage = 'olt-social/tools:0.1.0'
$WebImage = 'caddy:2.10.2-alpine@sha256:4c6e91c6ed0e2fa03efd5b44747b625fec79bc9cd06ac5235a779726618e530d'
$Stack = 'olt-social'

if ($DummyOlt -and $DeployProfile -ne 'dev') { throw 'DummyOlt hanya boleh dipakai di profil dev.' }
$Compose = switch ($DeployProfile) {
    'dev' { @('compose', '-f', 'docker/compose.yml', '-f', 'docker/compose.dev.yml') }
    default { @('compose', '-f', 'docker/compose.yml', '-f', 'docker/compose.prod.yml') }
}
if ($DummyOlt) { $Compose += @('-f', 'docker/compose.dummy-olt.yml') }
if ($DeployProfile -eq 'dev' -or $Cs) { $Compose += @('--profile', 'cs') }
$DummyCompose = @('compose', '-f', 'docker/compose.yml', '-f', 'docker/compose.dev.yml', '-f', 'docker/compose.dummy-olt.yml',
                  '--profile', 'cs')

function Invoke-Native {
    param([string]$Exe, [string[]]$Arguments)
    # Program native menulis progres ke stderr; di PS 5.1 itu jangan dianggap error.
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $Exe @Arguments } finally { $ErrorActionPreference = $prev }
    # Jangan cetak argumen lengkap: bisa berisi kunci (--dart-define=...KEY=...).
    if ($LASTEXITCODE -ne 0) { throw "$Exe $($Arguments | Select-Object -First 2) gagal (exit $LASTEXITCODE)" }
}

# Build lokal tanpa attestation (berisi timestamp): build ulang tanpa perubahan
# menghasilkan ID image yang sama, jadi `up --build` tidak me-restart container.
function Invoke-Docker {
    param([string[]]$Arguments)
    $prev = $env:BUILDX_NO_DEFAULT_ATTESTATIONS
    $env:BUILDX_NO_DEFAULT_ATTESTATIONS = '1'
    try { Invoke-Native 'docker' $Arguments } finally { $env:BUILDX_NO_DEFAULT_ATTESTATIONS = $prev }
}

function Invoke-Compose { param([string[]]$Arguments) Invoke-Docker ($Compose + $Arguments) }

function Invoke-Tools { param([string[]]$Arguments) Invoke-Compose (@('run', '--rm', 'tools') + $Arguments) }

function Get-EnvValue {
    param([string]$Key)
    $m = Select-String -LiteralPath $EnvFile -Pattern "^$Key=(.*)$" | Select-Object -Last 1
    if ($m) { return $m.Matches[0].Groups[1].Value.Trim('"') }
    return ''
}

function Get-AnonKey { (Get-Content -LiteralPath (Join-Path $SecretsDir 'anon_key') -Raw).Trim() }

function Assert-Config {
    if (-not (Test-Path -LiteralPath $EnvFile)) {
        throw 'docker/.env belum ada. Jalankan: .\make.ps1 gen-secrets'
    }
    foreach ($name in $SecretNames) {
        $path = Join-Path $SecretsDir $name
        if (-not (Test-Path -LiteralPath $path) -or (Get-Item -LiteralPath $path).Length -eq 0) {
            throw "Secret $name belum ada. Jalankan: .\make.ps1 gen-secrets"
        }
    }
    $placeholders = Select-String -LiteralPath $EnvFile -Pattern '=CHANGE_ME' -SimpleMatch
    if ($placeholders) {
        $placeholders | ForEach-Object { Write-Host $_.Line }
        throw 'docker/.env masih berisi CHANGE_ME.'
    }
    if ($DeployProfile -ne 'dev') {
        foreach ($key in @('PROXY_DOMAIN', 'ACME_EMAIL')) {
            if (-not (Get-EnvValue $key)) { throw "Profil ${DeployProfile}: $key wajib diisi di docker/.env" }
        }
    }
}

switch ($Target) {
    'help' {
        Write-Host @'
  Profil: -Profile dev (default) | single | cluster

  up            Build & jalankan stack, tunggu healthy
  down          Hentikan semua service (data tetap ada)
  logs          Ikuti log (filter: -Service auth-bridge)
  ps            Status service
  reset         HAPUS semua volume (DB & storage), lalu naik ulang (-Yes)
  migrate       Jalankan migrasi baru di supabase/migrations
  seed          Isi data dummy development
  test          Tes backend (pgTAP + Go)
  test-db       Tes pgTAP (supabase/tests)
  test-bridge   Unit test auth-bridge (Go, di container)
  test-flutter  Analyze + unit/widget test package Flutter (butuh Flutter SDK)
  test-flutter-it  Integration test package Flutter ke stack lokal
  e2e-windows   E2E app example di Windows (butuh Visual Studio)
  web-example   App example versi web di http://localhost:8081 (?user=sari_invest)
  license-audit Audit lisensi dependensi runtime Flutter (tolak GPL/AGPL)
  smoke         Smoke test end-to-end lewat Kong (butuh seed + mode mock)
  backup        Backup DB (+ file storage) ke folder backups/
  restore       Restore DB: -File olt-YYYYMMDD-HHMMSS.dump -Yes
  gen-secrets   Buat docker/secrets/ + docker/.env (idempoten; -Force membuat ulang semua)
  anon-key      Cetak ANON_KEY untuk build app Flutter
  admin-up      Nyalakan Studio (profil single: lewat SSH tunnel ke 127.0.0.1:8000)
  admin-down    Matikan Studio lagi (profil single)
  psql          Buka psql ke DB sebagai postgres

  OLT dummy (development/testing), jalankan stack dengan: .\make.ps1 up -DummyOlt
  dummy-token   Token sesi OLT dummy: -User budi_santoso [-Ttl 1h]
  smoke-dummy   Smoke test auth-bridge mode websocket vs OLT dummy
  test-dummy-olt  Unit test OLT dummy (Go, di container)
  test-flutter-it-dummy  Integration test Flutter: login lewat OLT dummy
  e2e-windows-dummy      E2E app example: form login OLT dummy

  Customer service lewat chat (dev: selalu aktif; produksi: -Profile single -Cs)
  test-cs       Unit test customer-adapter (Go, di container)
  smoke-cs      Smoke test CS chat end-to-end lewat API asli (butuh up -DummyOlt)
'@
    }
    'up' {
        Assert-Config
        if ($DeployProfile -eq 'cluster') {
            throw 'Profil cluster dijalankan di manager Swarm (Linux): make up PROFILE=cluster. Lihat docs/scaling.md.'
        }
        Invoke-Compose @('up', '-d', '--build', '--wait', '--wait-timeout', '300', '--remove-orphans')
        Invoke-Compose @('ps')
        Write-Host "API: $(Get-EnvValue 'SUPABASE_PUBLIC_URL')  (profil $DeployProfile)"
    }
    'down' { Invoke-Compose @('--profile', 'admin', '--profile', 'cs', 'down') }
    'logs' {
        $logArgs = @('logs', '-f', '--tail=200')
        if ($Service) { $logArgs += $Service }
        Invoke-Compose $logArgs
    }
    'ps' { Invoke-Compose @('ps') }
    'reset' {
        Assert-Config
        if (-not $Yes) { throw 'Ini MENGHAPUS seluruh data DB & storage. Ulangi dengan -Yes' }
        Invoke-Compose @('--profile', 'admin', 'down', '-v', '--remove-orphans')
        & $PSCommandPath up -Profile $DeployProfile -DummyOlt:$DummyOlt
    }
    'migrate' { Assert-Config; Invoke-Tools @('migrate') }
    'seed' { Assert-Config; Invoke-Tools @('seed') }
    'test-db' { Assert-Config; Invoke-Tools @('test-db') }
    'test-bridge' {
        $src = Join-Path $PSScriptRoot 'services/auth-bridge'
        Invoke-Docker @('run', '--rm', '-v', "${src}:/src", '-w', '/src', $GoImage, 'go', 'test', './...')
    }
    'test' {
        & $PSCommandPath test-db -Profile $DeployProfile
        & $PSCommandPath test-bridge
        & $PSCommandPath test-dummy-olt
        & $PSCommandPath test-cs
    }
    'test-flutter' {
        Push-Location (Join-Path $PSScriptRoot 'packages/olt_social')
        try {
            Invoke-Native 'flutter' @('analyze')
            Invoke-Native 'flutter' @('test')
        } finally { Pop-Location }
    }
    'test-flutter-it' {
        Assert-Config
        Push-Location (Join-Path $PSScriptRoot 'packages/olt_social')
        $env:OLT_SOCIAL_IT = '1'
        try { Invoke-Native 'flutter' @('test', 'test/integration') }
        finally { Remove-Item Env:OLT_SOCIAL_IT; Pop-Location }
    }
    'e2e-windows' {
        Assert-Config
        $anon = Get-AnonKey
        Push-Location (Join-Path $PSScriptRoot 'packages/olt_social/example')
        try { Invoke-Native 'flutter' @('test', 'integration_test/app_test.dart', '-d', 'windows', "--dart-define=OLT_SOCIAL_ANON_KEY=$anon") }
        finally { Pop-Location }
    }
    'web-example' {
        Assert-Config
        $anon = Get-AnonKey
        $example = Join-Path $PSScriptRoot 'packages/olt_social/example'
        Push-Location $example
        try {
            Invoke-Native 'flutter' @('build', 'web', '--release', '--no-web-resources-cdn', '--pwa-strategy=none',
                                      "--dart-define=OLT_SOCIAL_ANON_KEY=$anon")
        } finally { Pop-Location }
        # Server statis untuk build/web; container lama diganti. Stop: docker rm -f olt-web-example
        if (& docker ps -aq --filter 'name=^olt-web-example$') { Invoke-Docker @('rm', '-f', 'olt-web-example') }
        Invoke-Docker @('run', '-d', '--name', 'olt-web-example', '--restart', 'unless-stopped',
                        '-p', '127.0.0.1:8081:8081', '-v', "$(Join-Path $example 'build/web'):/srv:ro",
                        $WebImage, 'caddy', 'file-server', '--root', '/srv', '--listen', ':8081')
        Write-Host 'App web: http://localhost:8081  (langsung login: http://localhost:8081/?user=sari_invest)'
    }
    'license-audit' {
        Push-Location (Join-Path $PSScriptRoot 'packages/olt_social')
        try { Invoke-Native 'dart' @('run', 'tool/license_audit.dart') } finally { Pop-Location }
    }
    'smoke' { Assert-Config; Invoke-Tools @('smoke') }
    'backup' {
        Assert-Config
        Invoke-Tools @('backup')
        $backups = Join-Path $PSScriptRoot 'backups'
        $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
        Invoke-Docker @('run', '--rm', '-v', 'olt-social_storage-data:/data:ro', '-v', "${backups}:/backup",
                        $AlpineImage, 'tar', 'czf', "/backup/storage-$stamp.tar.gz", '-C', '/data', '.')
    }
    'restore' {
        Assert-Config
        if (-not $File) { throw 'Sebutkan file: .\make.ps1 restore -File olt-YYYYMMDD-HHMMSS.dump -Yes' }
        $confirm = if ($Yes) { 'yes' } else { 'no' }
        Invoke-Compose @('run', '--rm', '-e', "CONFIRM=$confirm", 'tools', 'restore', $File)
    }
    { $_ -in @('gen-secrets', 'gen-keys') } {
        # Di luar compose: compose menolak jalan bila file secret belum ada.
        Invoke-Docker @('build', '-q', '-t', $ToolsImage, 'docker/tools') | Out-Null
        $genArgs = @('run', '--rm', '-v', "$(Join-Path $PSScriptRoot 'docker'):/olt/docker",
                     '-v', "$(Join-Path $PSScriptRoot 'scripts'):/olt/scripts:ro",
                     '--entrypoint', 'bash', $ToolsImage, '/olt/scripts/gen-secrets.sh')
        if ($Force) { $genArgs += '--force' }
        Invoke-Docker $genArgs
    }
    'anon-key' { Get-AnonKey }
    'admin-up' { Assert-Config; Invoke-Compose @('--profile', 'admin', 'up', '-d', '--wait', 'studio', 'meta') }
    'admin-down' { Invoke-Compose @('--profile', 'admin', 'stop', 'studio', 'meta') }
    'psql' { Assert-Config; Invoke-Tools @('psql') }

    # --- OLT dummy -----------------------------------------------------------------
    'dummy-token' {
        Assert-Config
        $tokenArgs = @('run', '--rm', '--no-deps', '-T', 'dummy-olt', 'token', $User)
        if ($Ttl) { $tokenArgs += @('-ttl', $Ttl) }
        Invoke-Docker ($DummyCompose + $tokenArgs)
    }
    'smoke-dummy' { Assert-Config; Invoke-Docker ($DummyCompose + @('run', '--rm', 'tools', 'smoke-dummy')) }
    'smoke-cs' { Assert-Config; Invoke-Docker ($DummyCompose + @('run', '--rm', 'tools', 'smoke-cs')) }
    'test-cs' {
        $src = Join-Path $PSScriptRoot 'services/cs'
        Invoke-Docker @('run', '--rm', '-v', "${src}:/src", '-w', '/src', $GoImage, 'go', 'test', './...')
    }
    'test-dummy-olt' {
        $src = Join-Path $PSScriptRoot 'services/dummy-olt'
        Invoke-Docker @('run', '--rm', '-v', "${src}:/src", '-w', '/src', $GoImage, 'go', 'test', './...')
    }
    'test-flutter-it-dummy' {
        Assert-Config
        Push-Location (Join-Path $PSScriptRoot 'packages/olt_social')
        $env:OLT_SOCIAL_IT_DUMMY = '1'
        try { Invoke-Native 'flutter' @('test', 'test/integration/dummy_olt_integration_test.dart') }
        finally { Remove-Item Env:OLT_SOCIAL_IT_DUMMY; Pop-Location }
    }
    'e2e-windows-dummy' {
        Assert-Config
        $anon = Get-AnonKey
        Push-Location (Join-Path $PSScriptRoot 'packages/olt_social/example')
        try {
            Invoke-Native 'flutter' @('test', 'integration_test/dummy_olt_login_test.dart', '-d', 'windows',
                                      '--dart-define=OLT_DUMMY_E2E=true', "--dart-define=OLT_SOCIAL_ANON_KEY=$anon")
        } finally { Pop-Location }
    }
}
