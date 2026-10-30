# OLT Social - perintah operasional (Linux / macOS / WSL / VPS).
# Windows tanpa make: pakai .\make.ps1 <target> dengan target yang sama.
#
# PROFILE (docs/PROMPT-PRODUCTION.md bagian 1):
#   dev     (default) laptop developer: http://localhost:8000, Studio, token mock OLT
#   single  produksi 1 server: Traefik HTTPS, Studio mati (make admin-up)
#   cluster Docker Swarm (kerangka; dilengkapi Tahap 7)
# PROD=1 adalah alias lama untuk PROFILE=single.
# DUMMY_OLT=1 menambahkan OLT dummy + auth-bridge mode websocket (hanya profil dev).
# CS=1 menyalakan customer service lewat chat (customer-adapter) di profil single.

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
FILES_single  := -f docker/compose.yml -f docker/compose.prod.yml
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
GO_IMG        := golang:1.27.3-alpine3.24@sha256:d200d2dd76b03a99b52651fd1325aff7dcd35422c35c01bac56571b0507f3deb
TOOLS_IMG     := olt-social/tools:0.1.0
ALPINE_IMG    := alpine:3.22.7@sha256:2e0b81d60597f449baa56dc25d355367869d2dca4cd57e866f1e2b52af3eb55f
WEB_IMG       := caddy:2.10.2-alpine@sha256:4c6e91c6ed0e2fa03efd5b44747b625fec79bc9cd06ac5235a779726618e530d
PKG           := packages/olt_social
ANON_KEY      = $$(cat $(CURDIR)/$(SECRETS)/anon_key)
SECRET_NAMES  := postgres_password jwt_secret anon_key service_role_key dashboard_password \
                 secret_key_base realtime_db_enc_key realtime_erlang_cookie pg_meta_crypto_key \
                 s3_protocol_access_key_id s3_protocol_access_key_secret valkey_password postgrest_db_uri \
                 olt_customer_service_token

.DEFAULT_GOAL := help
.PHONY: help up down logs ps reset migrate seed test test-db test-bridge test-flutter test-flutter-it \
        e2e-windows web-example license-audit smoke backup restore gen-secrets gen-keys psql check-config \
        anon-key admin-up admin-down dummy-token smoke-dummy test-dummy-olt test-flutter-it-dummy e2e-windows-dummy \
        test-cs smoke-cs cs-race cs-demo cs-console cs-totp

help: ## Tampilkan daftar target
	@grep -E '^[a-z0-9-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-15s %s\n", $$1, $$2}'

check-config:
	@test -f $(ENV) || { echo "docker/.env belum ada. Jalankan: make gen-secrets"; exit 1; }
	@for s in $(SECRET_NAMES); do test -s $(SECRETS)/$$s || { echo "Secret $$s belum ada. Jalankan: make gen-secrets"; exit 1; }; done
	@! grep -q '=CHANGE_ME' $(ENV) || { echo "docker/.env masih berisi CHANGE_ME:"; grep '=CHANGE_ME' $(ENV); exit 1; }
	@if [ "$(PROFILE)" != dev ]; then for k in PROXY_DOMAIN ACME_EMAIL; do \
	  grep -qE "^$$k=.+" $(ENV) || { echo "Profil $(PROFILE): $$k wajib diisi di docker/.env"; exit 1; }; done; fi

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

test: test-db test-bridge test-dummy-olt test-cs ## Tes backend (pgTAP + Go)

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

web-example: check-config ## App example versi web di http://localhost:8081 (?user=sari_invest), butuh Flutter SDK
	cd $(PKG)/example && flutter build web --release --no-web-resources-cdn --pwa-strategy=none \
	  --dart-define=OLT_SOCIAL_ANON_KEY=$(ANON_KEY)
	@# Server statis untuk build/web; container lama diganti. Stop: docker rm -f olt-web-example
	@docker rm -f olt-web-example >/dev/null 2>&1 || true
	docker run -d --name olt-web-example --restart unless-stopped -p 127.0.0.1:8081:8081 \
	  -v "$(CURDIR)/$(PKG)/example/build/web:/srv:ro" $(WEB_IMG) caddy file-server --root /srv --listen :8081
	@echo "App web: http://localhost:8081  (langsung login: http://localhost:8081/?user=sari_invest)"

license-audit: ## Audit lisensi dependensi runtime Flutter: olt_social dan web CS (tolak GPL/AGPL)
	cd $(PKG) && dart run tool/license_audit.dart
	cd apps/cs-console && dart run ../../$(PKG)/tool/license_audit.dart

# --- OLT dummy (development/testing) -------------------------------------------------

dummy-token: check-config ## Token sesi OLT dummy: make dummy-token U=budi_santoso [TTL=1h]
	@$(DUMMY_COMPOSE) run --rm --no-deps -T dummy-olt token $(or $(U),budi_santoso) $(if $(TTL),-ttl $(TTL))

smoke-dummy: check-config ## Smoke test auth-bridge mode websocket vs OLT dummy (butuh up DUMMY_OLT=1)
	$(DUMMY_COMPOSE) run --rm tools smoke-dummy

test-cs: ## Unit test customer-adapter (Go, di container)
	docker run --rm -v "$(CURDIR)/services/cs:/src" -w /src $(GO_IMG) go test ./...

smoke-cs: check-config ## Smoke test CS chat end-to-end lewat API asli (butuh up DUMMY_OLT=1)
	$(DUMMY_COMPOSE) run --rm tools smoke-cs

cs-race: check-config ## Tes rebutan klaim tiket CS: DB langsung + 3 replika PostgREST khusus tes
	-@docker rm -f $(RACE_REST) > /dev/null 2>&1
	@for name in $(RACE_REST); do $(COMPOSE) run -d --no-deps -e PGRST_DB_POOL=3 --name $$name rest > /dev/null || exit 1; done
	$(TOOLS) cs-race $(foreach name,$(RACE_REST),http://$(name):3000); 	  status=$$?; docker rm -f $(RACE_REST) > /dev/null; exit $$status

cs-console: check-config ## Web CS (Flutter web) di http://localhost:8084 + akun staf dev dengan TOTP (butuh up DUMMY_OLT=1)
	mkdir -p scripts/cs-demo/runtime
	@(cat scripts/cs-demo/runtime/staff.json 2>/dev/null || echo '{}') | $(DUMMY_COMPOSE) run --rm -T tools cs-staff \
	  > scripts/cs-demo/runtime/staff.json.new && mv scripts/cs-demo/runtime/staff.json.new scripts/cs-demo/runtime/staff.json
	cd apps/cs-console && flutter build web --release --no-web-resources-cdn --pwa-strategy=none \
	  --dart-define=CS_CONSOLE_ANON_KEY=$(ANON_KEY)
	@docker rm -f olt-cs-console >/dev/null 2>&1 || true
	docker run -d --name olt-cs-console --restart unless-stopped -p 127.0.0.1:8084:8084 \
	  -v "$(CURDIR)/apps/cs-console/build/web:/srv:ro" $(WEB_IMG) caddy file-server --root /srv --listen :8084
	@echo "CS Console: http://localhost:8084  (akun dev: scripts/cs-demo/runtime/staff.json, kode TOTP: make cs-totp)"

cs-totp: check-config ## Kode TOTP saat ini untuk akun staf dev
	@$(DUMMY_COMPOSE) run --rm -T tools cs-totp < scripts/cs-demo/runtime/staff.json

cs-demo: check-config ## Halaman demo CS (nasabah + panel agen) di http://localhost:8082 (butuh up DUMMY_OLT=1)
	mkdir -p scripts/cs-demo/runtime
	$(DUMMY_COMPOSE) run --rm -T tools cs-demo-config > scripts/cs-demo/runtime/config.js
	-docker rm -f olt-cs-demo
	docker run -d --name olt-cs-demo --restart unless-stopped -p 127.0.0.1:8082:8082 	  -v "$(CURDIR)/scripts/cs-demo:/srv:ro" $(WEB_IMG) caddy file-server --root /srv --listen :8082
	@echo "Demo CS: http://localhost:8082  (stop: docker rm -f olt-cs-demo)"

test-dummy-olt: ## Unit test OLT dummy (Go, di container)
	docker run --rm -v "$(CURDIR)/services/dummy-olt:/src" -w /src $(GO_IMG) go test ./...

test-flutter-it-dummy: check-config ## Integration test Flutter: login lewat OLT dummy (butuh up DUMMY_OLT=1)
	cd $(PKG) && OLT_SOCIAL_IT_DUMMY=1 flutter test test/integration/dummy_olt_integration_test.dart

e2e-windows-dummy: check-config ## E2E app example: form login OLT dummy (butuh up DUMMY_OLT=1)
	cd $(PKG)/example && flutter test integration_test/dummy_olt_login_test.dart -d windows \
	  --dart-define=OLT_DUMMY_E2E=true \
	  --dart-define=OLT_SOCIAL_ANON_KEY=$(ANON_KEY)
