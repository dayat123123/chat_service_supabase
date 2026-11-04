# OLT Social - perintah operasional (Linux / macOS / WSL / VPS).
# Windows tanpa make: pakai .\make.ps1 <target> dengan target yang sama.
#
# PROFILE (docs/PROMPT-PRODUCTION.md bagian 1):
#   dev     (default) laptop developer: http://localhost:8000, Studio, token mock OLT
#   single  produksi 1 server: Traefik HTTPS, Studio mati (make admin-up)
#   cluster Docker Swarm (kerangka; dilengkapi Tahap 7)
# PROD=1 adalah alias lama untuk PROFILE=single.
# DUMMY_OLT=1 menambahkan OLT dummy (penerbit token sosial) + auth-bridge mode jwt (hanya profil dev).
# CS=1 menyalakan customer service lewat chat (web CS React) di profil single.

PROFILE ?= dev
ifdef PROD
override PROFILE := single
endif
ifeq ($(filter $(PROFILE),dev single cluster),)
$(error PROFILE harus dev, single, atau cluster)
endif
ifneq ($(and $(DUMMY_OLT),$(filter-out dev,$(PROFILE))),)
$(error DUMMY_OLT hanya boleh dipakai di profil dev)
endif

FILES_dev     := -f docker/compose.yml -f docker/compose.dev.yml $(if $(DUMMY_OLT),-f docker/compose.dummy-olt.yml)
FILES_single  := -f docker/compose.yml -f docker/compose.prod.yml $(if $(CS),-f docker/compose.cs.yml)
FILES_cluster := -f docker/compose.yml -f docker/compose.prod.yml
# Customer service (profil compose `cs`): selalu di dev; produksi dengan CS=1.
CS_dev        := --profile cs
CS_single     := $(if $(CS),--profile cs)
COMPOSE       := docker compose $(FILES_$(PROFILE)) $(CS_$(PROFILE))
DUMMY_COMPOSE := docker compose -f docker/compose.yml -f docker/compose.dev.yml -f docker/compose.dummy-olt.yml --profile cs
STACK         := olt-social
TOOLS         := $(COMPOSE) run --rm tools
RACE_REST     := olt-cs-race-rest-1 olt-cs-race-rest-2 olt-cs-race-rest-3
ENV           := docker/.env
SECRETS       := docker/secrets
# Build lokal tanpa attestation (berisi timestamp): build ulang tanpa perubahan
# menghasilkan ID image yang sama, jadi `up --build` tidak me-restart container.
export BUILDX_NO_DEFAULT_ATTESTATIONS := 1
NODE_IMG      := node:24.22.2-alpine@sha256:8a32c8cf649a49915a66e81e7a609223c708d0adabf288ee3f4077d765542f85
GO_IMG        := golang:1.27.3-alpine3.24@sha256:d200d2dd76b03a99b52651fd1325aff7dcd35422c35c01bac56571b0507f3deb
GITLEAKS_IMG  := ghcr.io/gitleaks/gitleaks:v8.28.0@sha256:cdbb7c955abce02001a9f6c9f602fb195b7fadc1e812065883f695d1eeaba854
TOOLS_IMG     := olt-social/tools:0.1.0
ALPINE_IMG    := alpine:3.22.7@sha256:2e0b81d60597f449baa56dc25d355367869d2dca4cd57e866f1e2b52af3eb55f
WEB_IMG       := caddy:2.10.2-alpine@sha256:4c6e91c6ed0e2fa03efd5b44747b625fec79bc9cd06ac5235a779726618e530d
PKG           := packages/rendezvous_community
TESTKIT_IMG   := olt-social/testkit:0.1.0
TESTKIT_SECRETS := anon_key jwt_secret postgres_password olt_dev_signing_key
# Alat uji keamanan/beban/chaos (tests/, docs/testing): k6, psql, docker CLI (docker.sock untuk chaos),
# di network edge+app+data stack dev. Hasil di tests/results/ (tidak di-commit).
TESTKIT       = docker run --rm --network $(STACK)_app --network $(STACK)_data --network $(STACK)_edge \
                  -v /var/run/docker.sock:/var/run/docker.sock -v "$(CURDIR)/tests:/olt/tests:ro" \
                  -v "$(CURDIR)/tests/results:/olt/results" -v "$(CURDIR)/docker:/olt/docker:ro" \
                  --mount type=tmpfs,destination=/olt/docker/secrets \
                  -v "$(CURDIR)/packages/rendezvous_community/lib:/olt/client-lib:ro" \
                  $(foreach s,$(TESTKIT_SECRETS),-v "$(CURDIR)/$(SECRETS)/$(s):/olt/secrets/$(s):ro") \
                  -e LOAD_STEPS -e LOAD_HOLD -e LOAD_RAMP -e LOAD_MSG_EVERY -e LOAD_FORCE -e LOAD_VIA \
                  -e GAP_EVERY -e GAP_IDS -e GAP_OVERLAP -e RECONNECT_JITTER -e GAP_RECHECK \
                  -e CHAOS_VUS -e CHAOS_OUTAGE -e CHAOS_LONG_OUTAGE $(TESTKIT_IMG)
ANON_KEY      = $$(cat $(CURDIR)/$(SECRETS)/anon_key)
SECRET_NAMES  := postgres_password jwt_secret anon_key service_role_key dashboard_password \
                 secret_key_base realtime_db_enc_key realtime_erlang_cookie pg_meta_crypto_key \
                 s3_protocol_access_key_id s3_protocol_access_key_secret valkey_password postgrest_db_uri pgbouncer_stats_password \
                 olt_jwks backup_db_password \

.DEFAULT_GOAL := help
.PHONY: help up down logs ps reset migrate seed test test-db test-bridge test-flutter test-flutter-it \
        e2e-windows web-example license-audit perf-flutter smoke backup restore gen-secrets gen-keys psql check-config \
        anon-key admin-up admin-down dummy-token smoke-dummy test-dummy-olt test-nasabah-gateway test-notifier test-janitor test-flutter-it-dummy e2e-windows-dummy \
        test-media test-sentinel test-backup test-integration test-link-preview test-classifier check-go-comments secrets-scan backup-snapshots restore-pitr \
        smoke-cs cs-race cs-demo cs-staff cs-bootstrap-admin cs-console-react test-cs-console e2e-cs-console \
        testkit test-security test-zap scan-deps load-test load-integration chaos-test loadtest-cleanup

help: ## Tampilkan daftar target
	@grep -E '^[a-z0-9-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-15s %s\n", $$1, $$2}'

check-config:
	@test -f $(ENV) || { echo "docker/.env belum ada. Jalankan: make gen-secrets"; exit 1; }
	@for s in $(SECRET_NAMES); do test -s $(SECRETS)/$$s || { echo "Secret $$s belum ada. Jalankan: make gen-secrets"; exit 1; }; done
	@test -f $(SECRETS)/csadmin_signing_key || : > $(SECRETS)/csadmin_signing_key
	@! grep -q '=CHANGE_ME' $(ENV) || { echo "docker/.env masih berisi CHANGE_ME:"; grep '=CHANGE_ME' $(ENV); exit 1; }
	@if [ "$(PROFILE)" != dev ]; then for k in PROXY_DOMAIN ACME_EMAIL; do \
	  grep -qE "^$$k=.+" $(ENV) || { echo "Profil $(PROFILE): $$k wajib diisi di docker/.env"; exit 1; }; done; \
	  rl=$$(sed -n 's/^AUTH_BRIDGE_RATE_LIMIT_PER_MINUTE=\([0-9]*\).*/\1/p' $(ENV) | tail -1); \
	  [ -z "$$rl" ] || [ "$$rl" -ge 300 ] || { echo "Profil $(PROFILE): AUTH_BRIDGE_RATE_LIMIT_PER_MINUTE=$$rl di docker/.env terlalu kecil (minimal 300, docs/PRODUCTION.md Batas & rate limit)"; exit 1; }; fi

up: check-config ## Build & jalankan stack (PROFILE=dev|single|cluster), tunggu healthy
ifeq ($(PROFILE),cluster)
	set -a; . ./$(ENV); set +a; docker stack deploy --detach=false -c docker/compose.yml -c docker/stack.cluster.yml $(STACK)
else
	$(COMPOSE) up -d --build --wait --wait-timeout 300 --remove-orphans
	@$(COMPOSE) ps
	@echo "API: $$(grep '^SUPABASE_PUBLIC_URL=' $(ENV) | cut -d= -f2)  (profil $(PROFILE))"
endif

down: ## Hentikan semua service (data tetap ada)
ifeq ($(PROFILE),cluster)
	docker stack rm $(STACK)
else
	$(COMPOSE) --profile admin --profile cs down
endif

logs: ## Ikuti log (filter service: make logs s=auth-bridge)
	$(COMPOSE) logs -f --tail=200 $(s)

ps: ## Status service
	$(COMPOSE) ps

reset: check-config ## HAPUS semua volume (DB & storage) lalu naik ulang: make reset CONFIRM=yes
	@[ "$(CONFIRM)" = yes ] || { echo "Ini MENGHAPUS seluruh data DB & storage. Ulangi dengan CONFIRM=yes"; exit 1; }
	$(COMPOSE) --profile admin down -v --remove-orphans
	$(MAKE) up

migrate: check-config ## Jalankan migrasi baru di supabase/migrations
	$(TOOLS) migrate

seed: check-config ## Isi data dummy development
	$(TOOLS) seed

test: test-db test-bridge test-dummy-olt test-nasabah-gateway test-notifier test-janitor test-media test-sentinel test-backup test-integration test-link-preview test-classifier check-go-comments ## Tes backend (pgTAP + Go)

test-db: check-config ## Tes pgTAP (supabase/tests)
	$(TOOLS) test-db

test-bridge: ## Unit test auth-bridge (Go, di container)
	docker run --rm -v "$(CURDIR)/services/auth-bridge:/src" -w /src $(GO_IMG) go test ./...

test-flutter: ## Analyze + unit/widget test package Flutter (butuh Flutter SDK)
	cd $(PKG) && flutter analyze && flutter test

smoke: check-config ## Smoke test end-to-end lewat Kong (butuh seed + mode mock)
	$(TOOLS) smoke

backup: check-config ## Backup DB (+ file storage) ke folder backups/
	$(TOOLS) backup
	docker run --rm -v olt-social_storage-data:/data:ro -v "$(CURDIR)/backups:/backup" $(ALPINE_IMG) \
	  tar czf /backup/storage-$$(date -u +%Y%m%d-%H%M%S).tar.gz -C /data .

restore: check-config ## Restore DB: make restore FILE=olt-YYYYMMDD-HHMMSS.dump CONFIRM=yes
	$(COMPOSE) run --rm -e CONFIRM=$(CONFIRM) tools restore $(FILE)

backup-snapshots: check-config ## Daftar snapshot backup (restic) + rentang waktu PITR
	$(COMPOSE) run --rm --no-deps -T backup snapshots

restore-pitr: check-config ## PITR: make restore-pitr AT=<RFC3339|latest> CONFIRM=yes (env RESTIC_*, AWS_*; docs/backup)
	@test "$(CONFIRM)" = yes || { echo "Isi database diganti hasil restore. Ulangi dengan CONFIRM=yes"; exit 1; }
	@test -n "$(AT)" || { echo "Sebutkan AT=2026-11-03T10:15:00+07:00 atau AT=latest"; exit 1; }
	@test -n "$$RESTIC_REPOSITORY" || { echo "Set RESTIC_REPOSITORY, RESTIC_PASSWORD (atau RESTIC_PASSWORD_FILE), AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY"; exit 1; }
	$(COMPOSE) build backup
	$(COMPOSE) stop
	docker run --rm --user 0:0 --network $(STACK)_egress \
	  -e RESTIC_REPOSITORY -e RESTIC_PASSWORD -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION \
	  $(if $(RESTIC_PASSWORD_FILE),-v "$(abspath $(RESTIC_PASSWORD_FILE)):/run/secrets/restic_password:ro" -e RESTIC_PASSWORD_FILE=/run/secrets/restic_password) \
	  -v $(STACK)_db-data:/restore olt-social/backup:0.1.0 \
	  restore --target-time "$(AT)" --data-dir /restore --wipe
	$(COMPOSE) up -d db
	@echo "Menunggu recovery selesai (pantau: make logs s=db)..."
	@for i in $$(seq 1 720); do $(COMPOSE) exec -T db pg_isready -U postgres -h localhost -q && exit 0; sleep 5; done; \
	  echo "Database belum siap setelah 1 jam; lihat make logs s=db"; exit 1
	$(COMPOSE) exec -T db psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 \
	  -c "ALTER SYSTEM RESET restore_command" -c "ALTER SYSTEM RESET recovery_target_time" \
	  -c "ALTER SYSTEM RESET recovery_target_action" -c "ALTER SYSTEM RESET recovery_target_timeline" \
	  -c "SELECT pg_reload_conf()"
	$(COMPOSE) exec -T -u postgres db rm -rf /var/lib/postgresql/data/restore_wal
	@echo "Database dipulihkan ke $(AT). Periksa data, lalu: make up"

gen-secrets: ## Buat docker/secrets/ + docker/.env (idempoten; FORCE=1 membuat ulang semua)
	docker build -q -t $(TOOLS_IMG) docker/tools > /dev/null
	docker run --rm --user "$$(id -u):$$(id -g)" -v "$(CURDIR)/docker:/olt/docker" -v "$(CURDIR)/scripts:/olt/scripts:ro" \
	  --entrypoint bash $(TOOLS_IMG) /olt/scripts/gen-secrets.sh $(if $(FORCE),--force)

gen-keys: gen-secrets ## Alias lama untuk gen-secrets

anon-key: ## Cetak ANON_KEY untuk build app Flutter (--dart-define=OLT_SOCIAL_ANON_KEY=...)
	@cat $(SECRETS)/anon_key; echo

admin-up: check-config ## Nyalakan Studio (profil single: akses lewat SSH tunnel ke 127.0.0.1:8000)
	$(COMPOSE) --profile admin up -d --wait studio meta

admin-down: ## Matikan Studio lagi (profil single)
	$(COMPOSE) --profile admin stop studio meta

psql: check-config ## Buka psql ke DB sebagai postgres
	$(TOOLS) psql

test-flutter-it: check-config ## Integration test package Flutter ke stack lokal (butuh Flutter SDK)
	cd $(PKG) && OLT_SOCIAL_IT=1 flutter test test/integration

e2e-windows: check-config ## E2E app example di Windows (butuh Flutter SDK + Visual Studio)
	cd $(PKG)/example && flutter test integration_test/app_test.dart -d windows \
	  --dart-define=OLT_SOCIAL_ANON_KEY=$(ANON_KEY)

web-example: check-config ## App example versi web di http://localhost:8086 (?user=sari_invest), butuh Flutter SDK
	cd $(PKG)/example && flutter build web --release --no-web-resources-cdn --pwa-strategy=none \
	  --dart-define=OLT_SOCIAL_ANON_KEY=$(ANON_KEY)
	@# Server statis untuk build/web; container lama diganti. Stop: docker rm -f olt-web-example
	@docker rm -f olt-web-example >/dev/null 2>&1 || true
	docker run -d --name olt-web-example --restart unless-stopped -p 127.0.0.1:8086:8086 \
	  -v "$(CURDIR)/$(PKG)/example/build/web:/srv:ro" $(WEB_IMG) caddy file-server --root /srv --listen :8086
	@echo "App web: http://localhost:8086  (langsung login: http://localhost:8086/?user=sari_invest)"

license-audit: ## Audit lisensi dependensi runtime Flutter rendezvous_community (tolak GPL/AGPL)
	cd $(PKG) && dart run tool/license_audit.dart

PERF_DEVICE ?= windows
perf-flutter: ## Tes performa scroll Flutter tanpa backend (profile; PERF_DEVICE=<id Android> untuk HP)
	cd $(PKG)/example && flutter drive --profile -d $(PERF_DEVICE) --driver=test_driver/perf_driver.dart --target=integration_test/perf_scroll_test.dart

# --- OLT dummy (development/testing) -------------------------------------------------

dummy-token: check-config ## Token sosial (JWT) OLT dummy untuk exchange: make dummy-token U=budi_santoso [TTL=5m]
	@$(DUMMY_COMPOSE) run --rm --no-deps -T dummy-olt token $(or $(U),budi_santoso) -social $(if $(TTL),-ttl $(TTL))

smoke-dummy: check-config ## Smoke test auth-bridge mode jwt vs token sosial OLT dummy (butuh up DUMMY_OLT=1)
	$(DUMMY_COMPOSE) run --rm tools smoke-dummy

smoke-cs: check-config ## Smoke test CS chat end-to-end lewat API asli (butuh up DUMMY_OLT=1)
	$(DUMMY_COMPOSE) run --rm tools smoke-cs

cs-race: check-config ## Tes rebutan klaim tiket CS: DB langsung + 3 replika PostgREST khusus tes
	-@docker rm -f $(RACE_REST) > /dev/null 2>&1
	@for name in $(RACE_REST); do $(COMPOSE) run -d --no-deps -e PGRST_DB_POOL=3 --name $$name rest > /dev/null || exit 1; done
	$(TOOLS) cs-race $(foreach name,$(RACE_REST),http://$(name):3000); 	  status=$$?; docker rm -f $(RACE_REST) > /dev/null; exit $$status

cs-bootstrap-admin: check-config ## Super admin web CS pertama: make cs-bootstrap-admin EMAIL=nama@domain NAME="Nama" [FORCE=1] [PROFILE=single]
	@$(TOOLS) cs-bootstrap-admin "$(EMAIL)" "$(NAME)" $(if $(FORCE),--force)

cs-staff: check-config ## Akun staf dev (CS, super admin, kepatuhan) di scripts/cs-demo/runtime/staff.json
	mkdir -p scripts/cs-demo/runtime
	@(cat scripts/cs-demo/runtime/staff.json 2>/dev/null || echo '{}') | $(DUMMY_COMPOSE) run --rm -T tools cs-staff \
	  > scripts/cs-demo/runtime/staff.json.new && mv scripts/cs-demo/runtime/staff.json.new scripts/cs-demo/runtime/staff.json

cs-console-react: cs-staff ## Web CS React (container nginx) di http://localhost:8085 (butuh up DUMMY_OLT=1)
	$(COMPOSE) up -d --build --wait traefik cs-console
	@echo "Web CS React: http://localhost:8085  (akun dev: scripts/cs-demo/runtime/staff.json)"

test-cs-console: ## Lint, typecheck, unit test, build, ukuran bundle, lisensi web CS React (di container Node)
	docker run --rm -v "$(CURDIR)/apps/cs-console-react:/app" -v /app/node_modules -v /app/dist -w /app $(NODE_IMG) \
	  sh -c 'npm ci --no-audit --no-fund && npm run ci'

e2e-cs-console: cs-console-react ## E2E Playwright web CS React vs stack dev (butuh up DUMMY_OLT=1, Node 24 + Chromium Playwright)
	cd apps/cs-console-react && E2E_BASE_URL=http://localhost:8085 npx playwright test

cs-demo: check-config ## Halaman demo CS (nasabah + panel agen) di http://localhost:8082 (butuh up DUMMY_OLT=1)
	mkdir -p scripts/cs-demo/runtime
	$(DUMMY_COMPOSE) run --rm -T tools cs-demo-config > scripts/cs-demo/runtime/config.js
	-docker rm -f olt-cs-demo
	docker run -d --name olt-cs-demo --restart unless-stopped -p 127.0.0.1:8082:8082 	  -v "$(CURDIR)/scripts/cs-demo:/srv:ro" $(WEB_IMG) caddy file-server --root /srv --listen :8082
	@echo "Demo CS: http://localhost:8082  (stop: docker rm -f olt-cs-demo)"

test-dummy-olt: ## Unit test OLT dummy (Go, di container)
	docker run --rm -v "$(CURDIR)/services/dummy-olt:/src" -w /src $(GO_IMG) go test ./...

test-nasabah-gateway: ## Unit test gateway menu Nasabah (Go, di container)
	docker run --rm -v "$(CURDIR)/services/nasabah-gateway:/src" -w /src $(GO_IMG) go test ./...

test-notifier: ## Unit test layanan push notifier (Go, di container)
	docker run --rm -v "$(CURDIR)/services/notifier:/src" -w /src $(GO_IMG) go test ./...

test-janitor: ## Unit test pembersih file storage (Go, di container)
	docker run --rm -v "$(CURDIR)/services/janitor:/src" -w /src $(GO_IMG) go test ./...

test-media: ## Unit test pintu upload media nasabah (Go, di container)
	docker run --rm -v "$(CURDIR)/services/media:/src" -w /src $(GO_IMG) go test ./...

test-sentinel: ## Unit test pemantau sistem + alert (Go, di container)
	docker run --rm -v "$(CURDIR)/services/sentinel:/src" -w /src $(GO_IMG) go test ./...

test-backup: ## Unit test layanan backup (Go, di container)
	docker run --rm -v "$(CURDIR)/services/backup:/src" -w /src $(GO_IMG) go test ./...

test-integration: ## Unit test gateway integrasi OLT (Go, di container)
	docker run --rm -v "$(CURDIR)/services/integration:/src" -w /src $(GO_IMG) go test ./...

test-link-preview: ## Unit test pratinjau link (Go, di container)
	docker run --rm -v "$(CURDIR)/services/link-preview:/src" -w /src $(GO_IMG) go test ./...

test-classifier: ## Unit test classifier NSFW (Go + cgo, di container)
	docker run --rm -v "$(CURDIR)/services/classifier:/src" -w /src $(GO_IMG) sh -c 'apk add --no-cache gcc musl-dev >/dev/null && CGO_ENABLED=1 go test ./...'

check-go-comments: ## Pastikan kode Go tanpa komentar (selain directive)
	docker run --rm -v "$(CURDIR):/repo" -w /repo/scripts/check-go-comments $(GO_IMG) go run . /repo/services

secrets-scan: ## Pindai riwayat git dengan gitleaks (.gitleaks.toml)
	docker run --rm -v "$(CURDIR):/repo" $(GITLEAKS_IMG) git /repo --config /repo/.gitleaks.toml --redact --no-banner

test-flutter-it-dummy: check-config ## Integration test Flutter: login lewat OLT dummy (butuh up DUMMY_OLT=1)
	cd $(PKG) && OLT_SOCIAL_IT_DUMMY=1 flutter test test/integration/dummy_olt_integration_test.dart

e2e-windows-dummy: check-config ## E2E app example: form login OLT dummy (butuh up DUMMY_OLT=1)
	cd $(PKG)/example && flutter test integration_test/dummy_olt_login_test.dart -d windows \
	  --dart-define=OLT_DUMMY_E2E=true \
	  --dart-define=OLT_SOCIAL_ANON_KEY=$(ANON_KEY)

# --- Uji keamanan, beban, dan chaos sebelum produksi (docs/testing/README.md) --------------
# Hanya untuk stack DEV dengan OLT dummy (make up DUMMY_OLT=1). Tidak pernah diarahkan ke produksi.

testkit: ## Build image alat uji (k6, tokengen, psql, docker CLI) olt-social/testkit
	@[ "$(PROFILE)" = dev ] || { echo "Uji keamanan/beban/chaos hanya untuk PROFILE=dev"; exit 1; }
	@mkdir -p tests/results
	docker build -q -t $(TESTKIT_IMG) tests > /dev/null

test-security: check-config testkit ## Uji otorisasi (anon/nasabah lain/agen tanpa izin), konfigurasi edge statis, routing produksi
	$(TESTKIT) security

scan-deps: ## Pindai kerentanan: govulncheck, npm audit, osv-scanner, Trivy (STRICT=1 gagal bila ada temuan penghalang)
	bash tests/security/scan-deps.sh $(if $(STRICT),--strict) $(if $(THIRD_PARTY),--third-party)

load-test: check-config testkit ## Uji beban k6 pembukaan pasar: make load-test P=smoke|step|spike|light (LOAD_STEPS="50 100 200")
	$(TESTKIT) load $(or $(P),smoke)

load-integration: check-config testkit ## Uji beban API integrasi OLT (notify per cust_id + siaran stock_watchers, inbox saja)
	$(TESTKIT) integration

chaos-test: check-config testkit ## Uji chaos di bawah beban ringan: make chaos-test [E="realtime valkey"]
	$(TESTKIT) chaos $(E)

loadtest-cleanup: check-config testkit ## Hapus data uji lt_* (DRY=1 hanya menampilkan)
	$(TESTKIT) cleanup $(if $(DRY),--dry-run)

test-zap: check-config testkit ## OWASP ZAP baseline pasif (opsional, image ±1,2 GB) ke web CS :8085 dan API dev
	$(TESTKIT) zap
