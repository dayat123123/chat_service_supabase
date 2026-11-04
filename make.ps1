<#
.SYNOPSIS
  OLT Social - padanan Makefile untuk Windows (PowerShell 5.1+).

.EXAMPLE
  .\make.ps1 gen-secrets
  .\make.ps1 up                            (profil dev: http://localhost:8000)
  .\make.ps1 up -Profile single            (produksi 1 server; butuh PROXY_DOMAIN & ACME_EMAIL)
  .\make.ps1 logs -Service auth-bridge
  .\make.ps1 restore -File olt-20261029-020000.dump -Yes
  .\make.ps1 up -DummyOlt                  (OLT dummy penerbit token sosial + auth-bridge mode jwt)
  .\make.ps1 dummy-token -User sari_invest -Ttl 5m
  .\make.ps1 up -Profile single -Cs        (produksi dengan customer service lewat chat)
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('help', 'up', 'down', 'logs', 'ps', 'reset', 'migrate', 'seed',
                 'test', 'test-db', 'test-bridge', 'test-flutter', 'test-flutter-it',
                 'e2e-windows', 'web-example', 'license-audit', 'perf-flutter', 'smoke', 'backup', 'restore',
                 'gen-secrets', 'gen-keys', 'anon-key', 'admin-up', 'admin-down', 'psql',
                 'dummy-token', 'smoke-dummy', 'test-dummy-olt', 'test-nasabah-gateway', 'test-notifier', 'test-janitor', 'test-flutter-it-dummy', 'e2e-windows-dummy',
                 'test-media', 'test-sentinel', 'test-backup', 'test-integration', 'test-link-preview', 'test-classifier', 'check-go-comments', 'secrets-scan',
                 'backup-snapshots', 'restore-pitr',
                 'smoke-cs', 'cs-race', 'cs-demo',
                 'cs-staff', 'cs-bootstrap-admin', 'cs-console-react', 'test-cs-console', 'e2e-cs-console',
                 'testkit', 'test-security', 'test-zap', 'scan-deps', 'load-test', 'load-integration', 'chaos-test', 'loadtest-cleanup')]
    [string]$Target = 'help',
    # dev (default) | single | cluster - lihat docs/PROMPT-PRODUCTION.md bagian 1.
    [Alias('Profile')]
    [ValidateSet('dev', 'single', 'cluster')]
    [string]$DeployProfile = 'dev',
    [string]$Service = '',
    [string]$File = '',
    [switch]$Force,
    [switch]$Yes,
    # OLT dummy penerbit token sosial + auth-bridge mode jwt (hanya profil dev).
    [switch]$DummyOlt,
    # Customer service lewat chat di profil single (di profil dev selalu aktif).
    [switch]$Cs,
    [string]$User = 'budi_santoso',
    [string]$Email = '',
    [string]$Name = '',
    [string]$Ttl = '',
    # restore-pitr: waktu target (RFC3339) atau 'latest'.
    [string]$At = '',
    # load-test: smoke | step | spike | light (docs/testing/README.md).
    [string]$Load = 'smoke',
    # chaos-test: daftar eksperimen dipisah spasi (kosong = semua).
    [string]$Experiments = '',
    # scan-deps: -Strict gagal bila ada temuan penghalang; -ThirdParty ikut memindai image pihak ketiga.
    [switch]$Strict,
    [switch]$ThirdParty,
    # loadtest-cleanup: -DryRun hanya menampilkan.
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

$EnvFile = 'docker/.env'
$SecretsDir = 'docker/secrets'
$SecretNames = @('postgres_password', 'jwt_secret', 'anon_key', 'service_role_key', 'dashboard_password',
                 'secret_key_base', 'realtime_db_enc_key', 'realtime_erlang_cookie', 'pg_meta_crypto_key',
                 's3_protocol_access_key_id', 's3_protocol_access_key_secret', 'valkey_password', 'postgrest_db_uri', 'pgbouncer_stats_password',
                 'olt_jwks', 'backup_db_password')
$GoImage = 'golang:1.27.3-alpine3.24@sha256:d200d2dd76b03a99b52651fd1325aff7dcd35422c35c01bac56571b0507f3deb'
$GitleaksImage = 'ghcr.io/gitleaks/gitleaks:v8.28.0@sha256:cdbb7c955abce02001a9f6c9f602fb195b7fadc1e812065883f695d1eeaba854'
$AlpineImage = 'alpine:3.22.7@sha256:2e0b81d60597f449baa56dc25d355367869d2dca4cd57e866f1e2b52af3eb55f'
$ToolsImage = 'olt-social/tools:0.1.0'
$NodeImage = 'node:24.22.2-alpine@sha256:8a32c8cf649a49915a66e81e7a609223c708d0adabf288ee3f4077d765542f85'
$WebImage = 'caddy:2.10.2-alpine@sha256:4c6e91c6ed0e2fa03efd5b44747b625fec79bc9cd06ac5235a779726618e530d'
$TestkitImage = 'olt-social/testkit:0.1.0'
# Package Flutter ada di repo terpisah (github.com/dayat123123/rendezvous_community), di-clone di sebelah repo ini; $env:PKG untuk path lain.
$PackageDir = if ($env:PKG) { $env:PKG } else { Join-Path (Split-Path $PSScriptRoot -Parent) 'rendezvous_community' }
$Stack = 'olt-social'

if ($DummyOlt -and $DeployProfile -ne 'dev') { throw 'DummyOlt hanya boleh dipakai di profil dev.' }
$Compose = switch ($DeployProfile) {
    'dev' { @('compose', '-f', 'docker/compose.yml', '-f', 'docker/compose.dev.yml') }
    default { @('compose', '-f', 'docker/compose.yml', '-f', 'docker/compose.prod.yml') }
}
if ($DummyOlt) { $Compose += @('-f', 'docker/compose.dummy-olt.yml') }
if ($Cs -and $DeployProfile -ne 'dev') { $Compose += @('-f', 'docker/compose.cs.yml') }
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

function Remove-Containers {
    param([string[]]$Names)
    foreach ($name in $Names) {
        if (& docker ps -aq --filter "name=^$name$") { Invoke-Docker @('rm', '-f', $name) | Out-Null }
    }
}

function Get-EnvValue {
    param([string]$Key)
    $m = Select-String -LiteralPath $EnvFile -Pattern "^$Key=(.*)$" | Select-Object -Last 1
    if ($m) { return $m.Matches[0].Groups[1].Value.Trim('"') }
    return ''
}

function Update-StaffAccounts {
    $runtime = Join-Path $PSScriptRoot 'scripts/cs-demo/runtime'
    New-Item -ItemType Directory -Force $runtime | Out-Null
    $staffFile = Join-Path $runtime 'staff.json'
    $previous = if (Test-Path -LiteralPath $staffFile) { Get-Content -LiteralPath $staffFile -Raw } else { '{}' }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $staff = $previous | & docker @($DummyCompose + @('run', '--rm', '-T', 'tools', 'cs-staff')) 2>$null }
    finally { $ErrorActionPreference = $prev }
    if ($LASTEXITCODE -ne 0) { throw "akun staf dev gagal disiapkan (exit $LASTEXITCODE)" }
    [IO.File]::WriteAllText($staffFile, (($staff | Out-String).Trim() + "`n"))
}

# Alat uji keamanan/beban/chaos (tests/): image olt-social/testkit di network edge+app+data stack dev,
# docker.sock untuk chaos, hanya secret yang dibutuhkan. Hasil di tests/results/.
function Invoke-Testkit {
    param([string[]]$Arguments)
    if ($DeployProfile -ne 'dev') { throw 'Uji keamanan/beban/chaos hanya untuk profil dev.' }
    $results = Join-Path $PSScriptRoot 'tests/results'
    New-Item -ItemType Directory -Force $results | Out-Null
    Invoke-Docker @('build', '-q', '-t', $TestkitImage, 'tests') | Out-Null
    if ($Arguments.Count -eq 0) { return }
    $runArgs = @('run', '--rm', '--network', "${Stack}_app", '--network', "${Stack}_data", '--network', "${Stack}_edge",
                 '-v', '/var/run/docker.sock:/var/run/docker.sock',
                 '-v', "$(Join-Path $PSScriptRoot 'tests'):/olt/tests:ro", '-v', "${results}:/olt/results",
                 '-v', "$(Join-Path $PSScriptRoot 'docker'):/olt/docker:ro", '--mount', 'type=tmpfs,destination=/olt/docker/secrets')
    $clientLib = Join-Path $PackageDir 'lib'
    if (Test-Path $clientLib) { $runArgs += @('-v', "$((Resolve-Path $clientLib).Path):/olt/client-lib:ro") }
    foreach ($s in @('anon_key', 'jwt_secret', 'postgres_password', 'olt_dev_signing_key')) {
        $runArgs += @('-v', "$(Join-Path $PSScriptRoot "$SecretsDir/$s"):/olt/secrets/${s}:ro")
    }
    foreach ($e in @('LOAD_STEPS', 'LOAD_HOLD', 'LOAD_RAMP', 'LOAD_MSG_EVERY', 'LOAD_FORCE', 'LOAD_VIA', 'CHAOS_VUS', 'CHAOS_OUTAGE', 'CHAOS_LONG_OUTAGE', 'GAP_EVERY', 'GAP_IDS', 'GAP_OVERLAP', 'RECONNECT_JITTER', 'GAP_RECHECK', 'TYPING', 'LIST_VUS', 'LIST_POLL', 'PRESENCE')) {
        if (Test-Path "Env:$e") { $runArgs += @('-e', $e) }
    }
    Invoke-Docker ($runArgs + @($TestkitImage) + $Arguments)
}

function Get-AnonKey { (Get-Content -LiteralPath (Join-Path $SecretsDir 'anon_key') -Raw).Trim() }

# Argumen docker untuk kredensial restic dari env: repositori S3 diteruskan apa adanya (+ AWS_*),
# folder lokal (mis. backups\restic) di-mount ke /var/lib/olt-backup-repo tanpa kredensial AWS.
function Get-ResticArgs {
    $repo = $env:RESTIC_REPOSITORY
    $resticArgs = @()
    if ($repo -match '^(s3|sftp|rest|swift|b2|azure|gs|rclone):') {
        $resticArgs += @('-e', 'RESTIC_REPOSITORY', '-e', 'AWS_ACCESS_KEY_ID', '-e', 'AWS_SECRET_ACCESS_KEY', '-e', 'AWS_DEFAULT_REGION')
    } else {
        $dir = (Resolve-Path -LiteralPath $repo).Path
        if (-not (Test-Path -LiteralPath (Join-Path $dir 'config') -PathType Leaf)) { throw "$dir bukan repositori restic (file config tidak ada)" }
        $resticArgs += @('-v', "${dir}:/var/lib/olt-backup-repo", '-e', 'RESTIC_REPOSITORY=/var/lib/olt-backup-repo')
    }
    $resticArgs += @('-e', 'RESTIC_PASSWORD')
    if ($env:RESTIC_PASSWORD_FILE) {
        $pw = (Resolve-Path -LiteralPath $env:RESTIC_PASSWORD_FILE).Path
        $resticArgs += @('-v', "${pw}:/run/secrets/restic_password:ro", '-e', 'RESTIC_PASSWORD_FILE=/run/secrets/restic_password')
    }
    return $resticArgs
}

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
    $csadminSigningKey = Join-Path $SecretsDir 'csadmin_signing_key'
    if (-not (Test-Path -LiteralPath $csadminSigningKey)) {
        [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot $csadminSigningKey), '')
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
        foreach ($key in @('AUTH_BRIDGE_RATE_LIMIT_PER_MINUTE', 'EDGE_WS_PER_IP')) {
            $limit = Get-EnvValue $key
            if ($limit -match '^\d+$' -and [int]$limit -lt 1000) {
                throw "Profil ${DeployProfile}: $key=$limit di docker/.env terlalu kecil (minimal 1000, docs/PRODUCTION.md Batas & rate limit)"
            }
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
  web-example   App example versi web di http://localhost:8086 (?user=sari_invest)
  license-audit Audit lisensi dependensi runtime Flutter (tolak GPL/AGPL)
  perf-flutter  Tes performa scroll Flutter (repository palsu, Windows profile; $env:PERF_DEVICE untuk Android)
  smoke         Smoke test end-to-end lewat Kong (butuh seed + mode mock)
  backup        Backup DB (+ file storage) ke folder backups/
  restore       Restore DB: -File olt-YYYYMMDD-HHMMSS.dump -Yes
  gen-secrets   Buat docker/secrets/ + docker/.env (idempoten; -Force membuat ulang semua)
  anon-key      Cetak ANON_KEY untuk build app Flutter
  admin-up      Nyalakan Studio (profil single: lewat SSH tunnel ke 127.0.0.1:8000)
  admin-down    Matikan Studio lagi (profil single)
  psql          Buka psql ke DB sebagai postgres

  OLT dummy (development/testing), jalankan stack dengan: .\make.ps1 up -DummyOlt
  dummy-token   Token sosial (JWT) OLT dummy untuk exchange: -User budi_santoso [-Ttl 5m]
  smoke-dummy   Smoke test auth-bridge mode jwt vs token sosial OLT dummy
  test-dummy-olt  Unit test OLT dummy (Go, di container)
  test-nasabah-gateway  Unit test gateway menu Nasabah (Go, di container)
  test-notifier  Unit test layanan push notifier (Go, di container)
  test-janitor   Unit test pembersih file storage (Go, di container)
  test-media     Unit test pintu upload media nasabah (Go, di container)
  test-sentinel  Unit test pemantau sistem + alert (Go, di container)
  test-backup    Unit test layanan backup (Go, di container)
  test-integration  Unit test gateway integrasi OLT (Go, di container)
  test-link-preview  Unit test pratinjau link (Go, di container)
  test-classifier  Unit test classifier NSFW (Go + cgo, di container)
  check-go-comments  Pastikan kode Go tanpa komentar (selain directive)
  secrets-scan   Pindai riwayat git dengan gitleaks (.gitleaks.toml)
  backup-snapshots  Daftar snapshot backup (restic) + rentang waktu PITR
  restore-pitr   Pulihkan DB ke waktu tertentu: -At 2026-11-03T10:15:00+07:00 -Yes (env RESTIC_*, AWS_* untuk S3; docs/backup)
  test-flutter-it-dummy  Integration test Flutter: login lewat OLT dummy
  e2e-windows-dummy      E2E app example: form login OLT dummy

  Customer service lewat chat (dev: selalu aktif; produksi: -Profile single -Cs)
  smoke-cs      Smoke test CS chat end-to-end lewat API asli (butuh up -DummyOlt)
  cs-race       Tes rebutan klaim tiket CS: DB langsung + 3 replika PostgREST khusus tes
  cs-demo       Halaman demo CS (nasabah + panel agen) di http://localhost:8082 (butuh up -DummyOlt)
  cs-staff      Akun staf dev (CS, super admin, kepatuhan) di scripts/cs-demo/runtime/staff.json
  cs-bootstrap-admin  Super admin web CS pertama: -Email nama@domain -Name "Nama" [-Force] [-Profile single]
  cs-console-react  Web CS React (container nginx) di http://localhost:8085 (butuh up -DummyOlt)
  test-cs-console   Lint, typecheck, unit test, build, ukuran bundle, lisensi web CS React (di container Node)
  e2e-cs-console    E2E Playwright web CS React vs stack dev (butuh up -DummyOlt, Node 24 + Chromium Playwright)

  Uji keamanan, beban, dan chaos (hanya stack dev: .\make.ps1 up -DummyOlt; docs/testing/README.md)
  testkit           Build image alat uji (k6, tokengen, psql, docker CLI)
  test-security     Uji otorisasi, konfigurasi edge statis, routing produksi
  test-zap          OWASP ZAP baseline pasif (opsional) ke web CS dan API dev
  scan-deps         Pindai kerentanan (govulncheck, npm audit, osv-scanner, Trivy) [-Strict] [-ThirdParty], butuh Git Bash
  load-test         Uji beban k6 pembukaan pasar: -Load smoke|step|spike|light
  load-integration  Uji beban API integrasi OLT (notify + siaran, inbox saja)
  chaos-test        Uji chaos di bawah beban ringan [-Experiments "realtime valkey"]
  loadtest-cleanup  Hapus data uji lt_* [-DryRun]
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
        & $PSCommandPath test-nasabah-gateway
        & $PSCommandPath test-notifier
        & $PSCommandPath test-janitor
        & $PSCommandPath test-media
        & $PSCommandPath test-sentinel
        & $PSCommandPath test-backup
        & $PSCommandPath test-integration
        & $PSCommandPath test-link-preview
        & $PSCommandPath test-classifier
        & $PSCommandPath check-go-comments
    }
    'test-flutter' {
        Push-Location $PackageDir
        try {
            Invoke-Native 'flutter' @('analyze')
            Invoke-Native 'flutter' @('test')
        } finally { Pop-Location }
    }
    'test-flutter-it' {
        Assert-Config
        Push-Location $PackageDir
        $env:OLT_SOCIAL_IT = '1'
        try { Invoke-Native 'flutter' @('test', 'test/integration') }
        finally { Remove-Item Env:OLT_SOCIAL_IT; Pop-Location }
    }
    'e2e-windows' {
        Assert-Config
        $anon = Get-AnonKey
        Push-Location (Join-Path $PackageDir 'example')
        try { Invoke-Native 'flutter' @('test', 'integration_test/app_test.dart', '-d', 'windows', "--dart-define=OLT_SOCIAL_ANON_KEY=$anon") }
        finally { Pop-Location }
    }
    'web-example' {
        Assert-Config
        $anon = Get-AnonKey
        $example = Join-Path $PackageDir 'example'
        Push-Location $example
        try {
            Invoke-Native 'flutter' @('build', 'web', '--release', '--no-web-resources-cdn', '--pwa-strategy=none',
                                      "--dart-define=OLT_SOCIAL_ANON_KEY=$anon")
        } finally { Pop-Location }
        # Server statis untuk build/web; container lama diganti. Stop: docker rm -f olt-web-example
        if (& docker ps -aq --filter 'name=^olt-web-example$') { Invoke-Docker @('rm', '-f', 'olt-web-example') }
        Invoke-Docker @('run', '-d', '--name', 'olt-web-example', '--restart', 'unless-stopped',
                        '-p', '127.0.0.1:8086:8086', '-v', "$(Join-Path $example 'build/web'):/srv:ro",
                        $WebImage, 'caddy', 'file-server', '--root', '/srv', '--listen', ':8086')
        Write-Host 'App web: http://localhost:8086  (langsung login: http://localhost:8086/?user=sari_invest)'
    }
    'license-audit' {
        Push-Location $PackageDir
        try { Invoke-Native 'dart' @('run', 'tool/license_audit.dart') } finally { Pop-Location }
    }
    'perf-flutter' {
        $device = if ($env:PERF_DEVICE) { $env:PERF_DEVICE } else { 'windows' }
        Push-Location (Join-Path $PackageDir 'example')
        try {
            Invoke-Native 'flutter' @('drive', '--profile', '-d', $device, '--driver=test_driver/perf_driver.dart',
                                      '--target=integration_test/perf_scroll_test.dart')
        } finally { Pop-Location }
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
        $tokenArgs = @('run', '--rm', '--no-deps', '-T', 'dummy-olt', 'token', $User, '-social')
        if ($Ttl) { $tokenArgs += @('-ttl', $Ttl) }
        Invoke-Docker ($DummyCompose + $tokenArgs)
    }
    'smoke-dummy' { Assert-Config; Invoke-Docker ($DummyCompose + @('run', '--rm', 'tools', 'smoke-dummy')) }
    'smoke-cs' { Assert-Config; Invoke-Docker ($DummyCompose + @('run', '--rm', 'tools', 'smoke-cs')) }
    'cs-race' {
        Assert-Config
        $replicas = 1..3 | ForEach-Object { "olt-cs-race-rest-$_" }
        Remove-Containers $replicas
        try {
            foreach ($name in $replicas) { Invoke-Compose @('run', '-d', '--no-deps', '-e', 'PGRST_DB_POOL=3', '--name', $name, 'rest') | Out-Null }
            Invoke-Tools (@('cs-race') + ($replicas | ForEach-Object { "http://${_}:3000" }))
        } finally {
            Remove-Containers $replicas
        }
    }
    'cs-demo' {
        Assert-Config
        $demo = Join-Path $PSScriptRoot 'scripts/cs-demo'
        $runtime = Join-Path $demo 'runtime'
        New-Item -ItemType Directory -Force $runtime | Out-Null
        $config = Invoke-Docker ($DummyCompose + @('run', '--rm', '-T', 'tools', 'cs-demo-config'))
        [IO.File]::WriteAllText((Join-Path $runtime 'config.js'), (($config | Out-String).Trim() + "`n"))
        Remove-Containers @('olt-cs-demo')
        Invoke-Docker @('run', '-d', '--name', 'olt-cs-demo', '--restart', 'unless-stopped', '-p', '127.0.0.1:8082:8082',
                        '-v', "${demo}:/srv:ro", $WebImage, 'caddy', 'file-server', '--root', '/srv', '--listen', ':8082')
        Write-Host 'Demo CS: http://localhost:8082  (stop: docker rm -f olt-cs-demo)'
    }
    'cs-staff' { Assert-Config; Update-StaffAccounts }
    'cs-bootstrap-admin' {
        Assert-Config
        $arguments = @('cs-bootstrap-admin', $Email, $Name)
        if ($Force) { $arguments += '--force' }
        Invoke-Tools $arguments
    }
    'cs-console-react' {
        Assert-Config
        Update-StaffAccounts
        Invoke-Compose @('up', '-d', '--build', '--wait', 'traefik', 'cs-console')
        Write-Host 'Web CS React: http://localhost:8085  (akun dev: scripts/cs-demo/runtime/staff.json)'
    }
    'test-cs-console' {
        $src = Join-Path $PSScriptRoot 'apps/cs-console-react'
        Invoke-Docker @('run', '--rm', '-v', "${src}:/app", '-v', '/app/node_modules', '-v', '/app/dist', '-w', '/app', $NodeImage,
                        'sh', '-c', 'npm ci --no-audit --no-fund && npm run ci')
    }
    'e2e-cs-console' {
        & $PSCommandPath cs-console-react -Profile $DeployProfile -DummyOlt:$DummyOlt
        Push-Location (Join-Path $PSScriptRoot 'apps/cs-console-react')
        $env:E2E_BASE_URL = 'http://localhost:8085'
        try { Invoke-Native 'npx' @('playwright', 'test') }
        finally { Remove-Item Env:E2E_BASE_URL; Pop-Location }
    }
    'test-dummy-olt' {
        $src = Join-Path $PSScriptRoot 'services/dummy-olt'
        Invoke-Docker @('run', '--rm', '-v', "${src}:/src", '-w', '/src', $GoImage, 'go', 'test', './...')
    }
    'test-nasabah-gateway' {
        $src = Join-Path $PSScriptRoot 'services/nasabah-gateway'
        Invoke-Docker @('run', '--rm', '-v', "${src}:/src", '-w', '/src', $GoImage, 'go', 'test', './...')
    }
    'test-notifier' {
        $src = Join-Path $PSScriptRoot 'services/notifier'
        Invoke-Docker @('run', '--rm', '-v', "${src}:/src", '-w', '/src', $GoImage, 'go', 'test', './...')
    }
    'test-janitor' {
        $src = Join-Path $PSScriptRoot 'services/janitor'
        Invoke-Docker @('run', '--rm', '-v', "${src}:/src", '-w', '/src', $GoImage, 'go', 'test', './...')
    }
    { $_ -in 'test-media', 'test-sentinel', 'test-backup', 'test-integration', 'test-link-preview' } {
        $src = Join-Path $PSScriptRoot ('services/' + $Target.Substring(5))
        Invoke-Docker @('run', '--rm', '-v', "${src}:/src", '-w', '/src', $GoImage, 'go', 'test', './...')
    }
    'backup-snapshots' {
        Assert-Config
        $snapArgs = @('run', '--rm', '--no-deps', '-T')
        if ($env:RESTIC_REPOSITORY) { $snapArgs += Get-ResticArgs }
        Invoke-Compose ($snapArgs + @('backup', 'snapshots'))
    }
    'restore-pitr' {
        Assert-Config
        if (-not $At) { throw 'Sebutkan waktu: .\make.ps1 restore-pitr -At 2026-11-03T10:15:00+07:00 -Yes (atau -At latest)' }
        if (-not $Yes) { throw 'Isi database diganti hasil restore. Ulangi dengan -Yes' }
        if (-not $env:RESTIC_REPOSITORY) { throw 'Set $env:RESTIC_REPOSITORY (s3:https://host/bucket/prefix atau folder lokal, mis. backups\restic), $env:RESTIC_PASSWORD (atau RESTIC_PASSWORD_FILE); untuk S3 juga $env:AWS_ACCESS_KEY_ID, $env:AWS_SECRET_ACCESS_KEY' }
        $resticArgs = Get-ResticArgs
        Invoke-Compose @('build', 'backup')
        Invoke-Compose @('stop')
        $runArgs = @('run', '--rm', '--user', '0:0', '--network', "${Stack}_egress") + $resticArgs + @('-v', "${Stack}_db-data:/restore")
        $runArgs += @('olt-social/backup:0.2.0', 'restore', '--target-time', $At, '--data-dir', '/restore', '--wipe')
        Invoke-Docker $runArgs
        Invoke-Compose @('up', '-d', 'db')
        Write-Host 'Menunggu recovery selesai (pantau: .\make.ps1 logs -Service db)...'
        $ready = $false
        for ($i = 0; $i -lt 720 -and -not $ready; $i++) {
            & docker @($Compose + @('exec', '-T', 'db', 'pg_isready', '-U', 'postgres', '-h', 'localhost', '-q')) 2>$null
            if ($LASTEXITCODE -eq 0) { $ready = $true } else { Start-Sleep -Seconds 5 }
        }
        if (-not $ready) { throw 'Database belum siap; lihat .\make.ps1 logs -Service db' }
        Invoke-Compose @('exec', '-T', 'db', 'psql', '-U', 'supabase_admin', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1',
                         '-c', 'ALTER SYSTEM RESET restore_command', '-c', 'ALTER SYSTEM RESET recovery_target_time',
                         '-c', 'ALTER SYSTEM RESET recovery_target_action', '-c', 'ALTER SYSTEM RESET recovery_target_timeline',
                         '-c', 'SELECT pg_reload_conf()')
        Invoke-Compose @('exec', '-T', '-u', 'postgres', 'db', 'rm', '-rf', '/var/lib/postgresql/data/restore_wal')
        Write-Host "Database dipulihkan ke $At. Periksa data, lalu: .\make.ps1 up"
    }
    'testkit' { Invoke-Testkit @() }
    'test-security' { Assert-Config; Invoke-Testkit @('security') }
    'test-zap' { Assert-Config; Invoke-Testkit @('zap') }
    'scan-deps' {
        $scanArgs = @('tests/security/scan-deps.sh')
        if ($Strict) { $scanArgs += '--strict' }
        if ($ThirdParty) { $scanArgs += '--third-party' }
        Invoke-Native 'bash' $scanArgs
    }
    'load-test' { Assert-Config; Invoke-Testkit @('load', $Load) }
    'load-integration' { Assert-Config; Invoke-Testkit @('integration') }
    'chaos-test' {
        Assert-Config
        $chaosArgs = @('chaos')
        if ($Experiments) { $chaosArgs += ($Experiments -split 's+' | Where-Object { $_ }) }
        Invoke-Testkit $chaosArgs
    }
    'loadtest-cleanup' {
        Assert-Config
        $cleanupArgs = @('cleanup')
        if ($DryRun) { $cleanupArgs += '--dry-run' }
        Invoke-Testkit $cleanupArgs
    }
    'test-classifier' {
        $src = Join-Path $PSScriptRoot 'services/classifier'
        Invoke-Docker @('run', '--rm', '-v', "${src}:/src", '-w', '/src', $GoImage, 'sh', '-c',
                        'apk add --no-cache gcc musl-dev >/dev/null && CGO_ENABLED=1 go test ./...')
    }
    'check-go-comments' {
        Invoke-Docker @('run', '--rm', '-v', "${PSScriptRoot}:/repo", '-w', '/repo/scripts/check-go-comments', $GoImage,
                        'go', 'run', '.', '/repo/services')
    }
    'secrets-scan' {
        Invoke-Docker @('run', '--rm', '-v', "${PSScriptRoot}:/repo", $GitleaksImage, 'git', '/repo',
                        '--config', '/repo/.gitleaks.toml', '--redact', '--no-banner')
    }
    'test-flutter-it-dummy' {
        Assert-Config
        Push-Location $PackageDir
        $env:OLT_SOCIAL_IT_DUMMY = '1'
        try { Invoke-Native 'flutter' @('test', 'test/integration/dummy_olt_integration_test.dart') }
        finally { Remove-Item Env:OLT_SOCIAL_IT_DUMMY; Pop-Location }
    }
    'e2e-windows-dummy' {
        Assert-Config
        $anon = Get-AnonKey
        Push-Location (Join-Path $PackageDir 'example')
        try {
            Invoke-Native 'flutter' @('test', 'integration_test/dummy_olt_login_test.dart', '-d', 'windows',
                                      '--dart-define=OLT_DUMMY_E2E=true', "--dart-define=OLT_SOCIAL_ANON_KEY=$anon")
        } finally { Pop-Location }
    }
}
