<#
.SYNOPSIS
  OLT Social - Makefile equivalent for Windows (PowerShell 5.1+).

.EXAMPLE
  .\make.ps1 gen-secrets
  .\make.ps1 up                            (dev profile: http://localhost:8000)
  .\make.ps1 up -Profile single            (single-server production; needs PROXY_DOMAIN & ACME_EMAIL)
  .\make.ps1 logs -Service auth-bridge
  .\make.ps1 restore -File olt-20261029-020000.dump -Yes
  .\make.ps1 up -DummyOlt                  (dummy OLT social token issuer + auth-bridge jwt mode)
  .\make.ps1 dummy-token -User sari_invest -Ttl 5m
  .\make.ps1 up -Profile single -Cs        (production with chat customer service)
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('help', 'up', 'down', 'logs', 'ps', 'reset', 'migrate', 'seed',
                 'test', 'test-db', 'test-bridge', 'test-flutter', 'test-flutter-it',
                 'e2e-windows', 'web-example', 'license-audit', 'perf-flutter', 'smoke', 'backup', 'restore',
                 'gen-secrets', 'gen-keys', 'anon-key', 'admin-up', 'admin-down', 'psql',
                 'dummy-token', 'smoke-dummy', 'test-dummy-olt', 'test-nasabah-gateway', 'test-notifier', 'test-janitor', 'test-flutter-it-dummy', 'e2e-windows-dummy',
                 'test-media', 'test-sentinel', 'test-healer', 'test-backup', 'test-integration', 'test-link-preview', 'test-classifier', 'check-go-comments', 'secrets-scan',
                 'backup-snapshots', 'restore-pitr',
                 'smoke-cs', 'cs-race', 'cs-demo',
                 'cs-staff', 'cs-bootstrap-admin', 'cs-console-react', 'test-cs-console', 'e2e-cs-console',
                 'testkit', 'test-security', 'test-zap', 'scan-deps', 'load-test', 'load-integration', 'chaos-test', 'loadtest-cleanup')]
    [string]$Target = 'help',
    [Alias('Profile')]
    [ValidateSet('dev', 'single', 'cluster')]
    [string]$DeployProfile = 'dev',
    [string]$Service = '',
    [string]$File = '',
    [switch]$Force,
    [switch]$Yes,
    [switch]$DummyOlt,
    [switch]$Cs,
    [string]$User = 'budi_santoso',
    [string]$Email = '',
    [string]$Name = '',
    [string]$Ttl = '',
    [string]$At = '',
    [string]$Load = 'smoke',
    [string]$Experiments = '',
    [switch]$Strict,
    [switch]$ThirdParty,
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
$PackageDir = if ($env:PKG) { $env:PKG } else { Join-Path (Split-Path $PSScriptRoot -Parent) 'rendezvous_community' }
# Rendezvous Hub (web CS) lives in its own repo (github.com/dayat123123/rendezvous_hub): clone it next to
# this repo, set $env:HUB (relative to this repo), or set HUB_DIR in docker/.env (relative to docker/).
$envHubDir = if (Test-Path -LiteralPath $EnvFile) { Select-String -LiteralPath $EnvFile -Pattern '^HUB_DIR=(.+)$' | Select-Object -Last 1 }
$HubDir = if ($env:HUB) { [IO.Path]::Combine($PSScriptRoot, $env:HUB) }
          elseif ($env:HUB_DIR) { [IO.Path]::Combine($PSScriptRoot, 'docker', $env:HUB_DIR) }
          elseif ($envHubDir) { [IO.Path]::Combine($PSScriptRoot, 'docker', $envHubDir.Matches[0].Groups[1].Value.Trim('"')) }
          else { [IO.Path]::Combine((Split-Path $PSScriptRoot -Parent), 'rendezvous_hub') }
$HubDir = [IO.Path]::GetFullPath($HubDir)
$HubFound = Test-Path -LiteralPath (Join-Path $HubDir 'package.json')
$HubMissing = "Rendezvous Hub checkout not found at $HubDir; clone https://github.com/dayat123123/rendezvous_hub next to this repo or set HUB"
$Stack = 'olt-social'

if ($DummyOlt -and $DeployProfile -ne 'dev') { throw 'DummyOlt is only allowed with the dev profile.' }
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
    # Native tools write progress to stderr; PS 5.1 must not treat that as an error.
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $Exe @Arguments } finally { $ErrorActionPreference = $prev }
    # Never print the full argument list: it can contain keys (--dart-define=...KEY=...).
    if ($LASTEXITCODE -ne 0) { throw "$Exe $($Arguments | Select-Object -First 2) failed (exit $LASTEXITCODE)" }
}

# Local builds skip attestations (they embed a timestamp) so an unchanged rebuild keeps the
# same image ID and `up --build` does not restart containers.
function Invoke-Docker {
    param([string[]]$Arguments)
    $prev = $env:BUILDX_NO_DEFAULT_ATTESTATIONS
    $prevHub = $env:HUB_DIR
    $env:BUILDX_NO_DEFAULT_ATTESTATIONS = '1'
    $env:HUB_DIR = $HubDir
    try { Invoke-Native 'docker' $Arguments } finally { $env:BUILDX_NO_DEFAULT_ATTESTATIONS = $prev; $env:HUB_DIR = $prevHub }
}

function Assert-Hub { if (-not $HubFound) { throw $HubMissing } }

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
    if ($LASTEXITCODE -ne 0) { throw "dev staff accounts could not be prepared (exit $LASTEXITCODE)" }
    [IO.File]::WriteAllText($staffFile, (($staff | Out-String).Trim() + "`n"))
}

function Invoke-Testkit {
    param([string[]]$Arguments)
    if ($DeployProfile -ne 'dev') { throw 'Security/load/chaos tests are for the dev profile only.' }
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

function Get-ResticArgs {
    $repo = $env:RESTIC_REPOSITORY
    $resticArgs = @()
    if ($repo -match '^(s3|sftp|rest|swift|b2|azure|gs|rclone):') {
        $resticArgs += @('-e', 'RESTIC_REPOSITORY', '-e', 'AWS_ACCESS_KEY_ID', '-e', 'AWS_SECRET_ACCESS_KEY', '-e', 'AWS_DEFAULT_REGION')
    } else {
        $dir = (Resolve-Path -LiteralPath $repo).Path
        if (-not (Test-Path -LiteralPath (Join-Path $dir 'config') -PathType Leaf)) { throw "$dir is not a restic repository (config file missing)" }
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
        throw 'docker/.env is missing. Run: .\make.ps1 gen-secrets'
    }
    foreach ($name in $SecretNames) {
        $path = Join-Path $SecretsDir $name
        if (-not (Test-Path -LiteralPath $path) -or (Get-Item -LiteralPath $path).Length -eq 0) {
            throw "Secret $name is missing. Run: .\make.ps1 gen-secrets"
        }
    }
    $csadminSigningKey = Join-Path $SecretsDir 'csadmin_signing_key'
    if (-not (Test-Path -LiteralPath $csadminSigningKey)) {
        [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot $csadminSigningKey), '')
    }
    $placeholders = Select-String -LiteralPath $EnvFile -Pattern '=CHANGE_ME' -SimpleMatch
    if ($placeholders) {
        $placeholders | ForEach-Object { Write-Host $_.Line }
        throw 'docker/.env still contains CHANGE_ME.'
    }
    if ($DeployProfile -ne 'dev') {
        foreach ($key in @('PROXY_DOMAIN', 'ACME_EMAIL')) {
            if (-not (Get-EnvValue $key)) { throw "Profile ${DeployProfile}: $key is required in docker/.env" }
        }
        foreach ($key in @('AUTH_BRIDGE_RATE_LIMIT_PER_MINUTE', 'EDGE_WS_PER_IP')) {
            $limit = Get-EnvValue $key
            if ($limit -match '^\d+$' -and [int]$limit -lt 1000) {
                throw "Profile ${DeployProfile}: $key=$limit in docker/.env is too low (minimum 1000, see docs/PRODUCTION.md 'Batas & rate limit')"
            }
        }
    }
}

switch ($Target) {
    'help' {
        Write-Host @'
  Profile: -Profile dev (default) | single | cluster

  up            Build and start the stack, wait until healthy
  down          Stop all services (data is kept)
  logs          Follow logs (filter: -Service auth-bridge)
  ps            Service status
  reset         DELETE all volumes (DB & storage), then start again (-Yes)
  migrate       Apply new migrations from supabase/migrations
  seed          Load development dummy data
  test          Backend tests (pgTAP + Go)
  test-db       pgTAP tests (supabase/tests)
  test-bridge   auth-bridge unit tests (Go, in a container)
  test-flutter  Analyze + unit/widget tests of the Flutter package (needs the Flutter SDK)
  test-flutter-it  Flutter package integration tests against the local stack
  e2e-windows   Example app E2E on Windows (needs Visual Studio)
  web-example   Web build of the example app at http://localhost:8086 (?user=sari_invest)
  license-audit License audit of Flutter runtime dependencies (rejects GPL/AGPL)
  perf-flutter  Flutter scroll performance test (fake repositories, Windows profile mode; $env:PERF_DEVICE for Android)
  smoke         End-to-end smoke test through Kong (needs seed + mock mode)
  backup        Back up the DB (+ storage files) to backups/
  restore       Restore the DB: -File olt-YYYYMMDD-HHMMSS.dump -Yes
  gen-secrets   Create docker/secrets/ + docker/.env (idempotent; -Force regenerates everything)
  anon-key      Print ANON_KEY for Flutter app builds
  admin-up      Start Studio (single profile: through an SSH tunnel to 127.0.0.1:8000)
  admin-down    Stop Studio again (single profile)
  psql          Open psql to the DB as postgres

  Dummy OLT (development/testing), start the stack with: .\make.ps1 up -DummyOlt
  dummy-token   Dummy OLT social token (JWT) for the exchange: -User budi_santoso [-Ttl 5m]
  smoke-dummy   Smoke test of auth-bridge jwt mode with dummy OLT social tokens
  test-dummy-olt  Dummy OLT unit tests (Go, in a container)
  test-nasabah-gateway  Customer menu gateway unit tests (Go, in a container)
  test-notifier  Push notifier unit tests (Go, in a container)
  test-janitor   Storage file janitor unit tests (Go, in a container)
  test-media     Customer media upload gateway unit tests (Go, in a container)
  test-sentinel  System monitor + alert unit tests (Go, in a container)
  test-healer    Unhealthy container auto-restart unit tests (Go, in a container)
  test-backup    Backup service unit tests (Go, in a container)
  test-integration  OLT integration gateway unit tests (Go, in a container)
  test-link-preview  Link preview unit tests (Go, in a container)
  test-classifier  NSFW classifier unit tests (Go + cgo, in a container)
  check-go-comments  Ensure Go code has no comments (other than directives)
  secrets-scan   Scan git history with gitleaks (.gitleaks.toml)
  backup-snapshots  List backup snapshots (restic) + PITR time range
  restore-pitr   Restore the DB to a point in time: -At 2026-11-03T10:15:00+07:00 -Yes (env RESTIC_*, AWS_* for S3; docs/backup)
  test-flutter-it-dummy  Flutter integration test: login through the dummy OLT
  e2e-windows-dummy      Example app E2E: dummy OLT login form

  Chat customer service (dev: always on; production: -Profile single -Cs)
  smoke-cs      End-to-end CS chat smoke test through the real API (needs up -DummyOlt)
  cs-race       CS ticket claim race test: direct DB + 3 test-only PostgREST replicas
  cs-demo       CS demo page (customer + agent panel) at http://localhost:8082 (needs up -DummyOlt)
  cs-staff      Dev staff accounts (CS, super admin, compliance) in scripts/cs-demo/runtime/staff.json
  cs-bootstrap-admin  First web CS super admin: -Email name@domain -Name "Name" [-Force] [-Profile single]
  cs-console-react  Rendezvous Hub (web CS, nginx container built from $env:HUB, default ..\rendezvous_hub) at http://localhost:8085 (needs up -DummyOlt)
  test-cs-console   Rendezvous Hub CI (npm run ci: lint, typecheck, unit tests, build, bundle size, licenses) in a Node container
  e2e-cs-console    Rendezvous Hub Playwright E2E against the dev stack (needs up -DummyOlt, Node 24 + Playwright Chromium)

  Security, load and chaos tests (dev stack only: .\make.ps1 up -DummyOlt; docs/testing/README.md)
  testkit           Build the test image (k6, tokengen, psql, docker CLI)
  test-security     Authorization probes, static edge config, production routing
  test-zap          Passive OWASP ZAP baseline (optional) against web CS and the dev API
  scan-deps         Vulnerability scan (govulncheck, npm audit, osv-scanner, Trivy) [-Strict] [-ThirdParty], needs Git Bash
  load-test         k6 market-open load test: -Load smoke|step|spike|light
  load-integration  OLT integration API load test (notify + broadcast, inbox only)
  chaos-test        Chaos tests under light load [-Experiments "realtime valkey"]
  loadtest-cleanup  Delete lt_* test data [-DryRun]
'@
    }
    'up' {
        Assert-Config
        if ($DeployProfile -eq 'cluster') {
            throw 'The cluster profile runs on a Swarm manager (Linux): make up PROFILE=cluster. See docs/scaling.md.'
        }
        $upArgs = @('up', '-d', '--build', '--wait', '--wait-timeout', '300', '--remove-orphans')
        if (-not $HubFound -and ($DeployProfile -eq 'dev' -or $Cs)) {
            if ($DeployProfile -ne 'dev') { throw "$HubMissing (needed for -Cs)" }
            Write-Warning "$HubMissing; starting the dev stack without cs-console"
            $upArgs += @(& docker @($Compose + @('config', '--services')) | Where-Object { $_ -ne 'cs-console' })
            if ($LASTEXITCODE -ne 0) { throw "docker compose config --services failed (exit $LASTEXITCODE)" }
        }
        Invoke-Compose $upArgs
        Invoke-Compose @('ps')
        Write-Host "API: $(Get-EnvValue 'SUPABASE_PUBLIC_URL')  (profile $DeployProfile)"
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
        if (-not $Yes) { throw 'This DELETES all DB & storage data. Re-run with -Yes' }
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
        & $PSCommandPath test-healer
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
        if (& docker ps -aq --filter 'name=^olt-web-example$') { Invoke-Docker @('rm', '-f', 'olt-web-example') }
        Invoke-Docker @('run', '-d', '--name', 'olt-web-example', '--restart', 'unless-stopped',
                        '-p', '127.0.0.1:8086:8086', '-v', "$(Join-Path $example 'build/web'):/srv:ro",
                        $WebImage, 'caddy', 'file-server', '--root', '/srv', '--listen', ':8086')
        Write-Host 'Web app: http://localhost:8086  (direct login: http://localhost:8086/?user=sari_invest)'
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
        if (-not $File) { throw 'Specify the file: .\make.ps1 restore -File olt-YYYYMMDD-HHMMSS.dump -Yes' }
        $confirm = if ($Yes) { 'yes' } else { 'no' }
        Invoke-Compose @('run', '--rm', '-e', "CONFIRM=$confirm", 'tools', 'restore', $File)
    }
    { $_ -in @('gen-secrets', 'gen-keys') } {
        # Runs outside compose because compose refuses to start while secret files are missing.
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
        Assert-Hub
        Update-StaffAccounts
        Invoke-Compose @('up', '-d', '--build', '--wait', 'traefik', 'cs-console')
        Write-Host 'Rendezvous Hub: http://localhost:8085  (dev accounts: scripts/cs-demo/runtime/staff.json)'
    }
    'test-cs-console' {
        Assert-Hub
        Invoke-Docker @('run', '--rm', '-v', "${HubDir}:/app", '-v', '/app/node_modules', '-v', '/app/dist', '-w', '/app', $NodeImage,
                        'sh', '-c', 'npm ci --no-audit --no-fund && npm run ci')
    }
    'e2e-cs-console' {
        & $PSCommandPath cs-console-react -Profile $DeployProfile -DummyOlt:$DummyOlt
        Push-Location -LiteralPath $HubDir
        $env:E2E_BASE_URL = 'http://localhost:8085'
        $env:MONOREPO_DIR = $PSScriptRoot
        try { Invoke-Native 'npx' @('playwright', 'test') }
        finally { Remove-Item Env:E2E_BASE_URL, Env:MONOREPO_DIR; Pop-Location }
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
    { $_ -in 'test-media', 'test-sentinel', 'test-healer', 'test-backup', 'test-integration', 'test-link-preview' } {
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
        if (-not $At) { throw 'Specify the time: .\make.ps1 restore-pitr -At 2026-11-03T10:15:00+07:00 -Yes (or -At latest)' }
        if (-not $Yes) { throw 'The database contents will be replaced by the restore. Re-run with -Yes' }
        if (-not $env:RESTIC_REPOSITORY) { throw 'Set $env:RESTIC_REPOSITORY (s3:https://host/bucket/prefix or a local folder, e.g. backups\restic), $env:RESTIC_PASSWORD (or RESTIC_PASSWORD_FILE); for S3 also $env:AWS_ACCESS_KEY_ID, $env:AWS_SECRET_ACCESS_KEY' }
        $resticArgs = Get-ResticArgs
        Invoke-Compose @('build', 'backup')
        Invoke-Compose @('stop')
        $runArgs = @('run', '--rm', '--user', '0:0', '--network', "${Stack}_egress") + $resticArgs + @('-v', "${Stack}_db-data:/restore")
        $runArgs += @('olt-social/backup:0.2.0', 'restore', '--target-time', $At, '--data-dir', '/restore', '--wipe')
        Invoke-Docker $runArgs
        Invoke-Compose @('up', '-d', 'db')
        Write-Host 'Waiting for recovery to finish (follow: .\make.ps1 logs -Service db)...'
        $ready = $false
        for ($i = 0; $i -lt 720 -and -not $ready; $i++) {
            & docker @($Compose + @('exec', '-T', 'db', 'pg_isready', '-U', 'postgres', '-h', 'localhost', '-q')) 2>$null
            if ($LASTEXITCODE -eq 0) { $ready = $true } else { Start-Sleep -Seconds 5 }
        }
        if (-not $ready) { throw 'Database not ready; see .\make.ps1 logs -Service db' }
        Invoke-Compose @('exec', '-T', 'db', 'psql', '-U', 'supabase_admin', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1',
                         '-c', 'ALTER SYSTEM RESET restore_command', '-c', 'ALTER SYSTEM RESET recovery_target_time',
                         '-c', 'ALTER SYSTEM RESET recovery_target_action', '-c', 'ALTER SYSTEM RESET recovery_target_timeline',
                         '-c', 'SELECT pg_reload_conf()')
        Invoke-Compose @('exec', '-T', '-u', 'postgres', 'db', 'rm', '-rf', '/var/lib/postgresql/data/restore_wal')
        Write-Host "Database restored to $At. Check the data, then: .\make.ps1 up"
    }
    'testkit' { Invoke-Testkit @() }
    'test-security' { Assert-Config; Invoke-Testkit @('security') }
    'test-zap' { Assert-Config; Invoke-Testkit @('zap') }
    'scan-deps' {
        $scanArgs = @('tests/security/scan-deps.sh')
        if ($Strict) { $scanArgs += '--strict' }
        if ($ThirdParty) { $scanArgs += '--third-party' }
        $prevHub = $env:HUB
        $env:HUB = $HubDir
        try { Invoke-Native 'bash' $scanArgs } finally { $env:HUB = $prevHub }
    }
    'load-test' { Assert-Config; Invoke-Testkit @('load', $Load) }
    'load-integration' { Assert-Config; Invoke-Testkit @('integration') }
    'chaos-test' {
        Assert-Config
        $chaosArgs = @('chaos')
        if ($Experiments) { $chaosArgs += ($Experiments -split '\s+' | Where-Object { $_ }) }
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
