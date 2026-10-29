# OLT Social - perintah operasional (Linux / macOS / WSL / VPS).
# Windows tanpa make: pakai .\make.ps1 <target> dengan target yang sama.

# PROD=1 menambahkan Caddy (HTTPS) di depan Kong, untuk VPS.
# DUMMY_OLT=1 menjalankan OLT dummy dan auth-bridge mode websocket (development/testing).
ifneq ($(and $(PROD),$(DUMMY_OLT)),)
$(error DUMMY_OLT tidak boleh dipakai bersama PROD)
endif
COMPOSE := docker compose -f docker/docker-compose.yml $(if $(PROD),-f docker/docker-compose.prod.yml) \
           $(if $(DUMMY_OLT),-f docker/docker-compose.dummy-olt.yml)
DUMMY_COMPOSE := docker compose -f docker/docker-compose.yml -f docker/docker-compose.dummy-olt.yml
TOOLS   := $(COMPOSE) run --rm tools
ENV     := docker/.env
GO_IMG  := golang:1.24.5-alpine3.22
WEB_IMG := caddy:2.10.2-alpine
PKG     := packages/olt_social

.DEFAULT_GOAL := help
.PHONY: help up down logs ps reset migrate seed test test-db test-bridge test-flutter test-flutter-it \
        e2e-windows web-example license-audit smoke backup restore gen-keys psql check-env \
        dummy-token smoke-dummy test-dummy-olt test-flutter-it-dummy e2e-windows-dummy

help: ## Tampilkan daftar target
	@grep -E '^[a-z0-9-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-13s %s\n", $$1, $$2}'

check-env:
	@test -f $(ENV) || { echo "docker/.env belum ada. Jalankan: make gen-keys"; exit 1; }
	@! grep -q '=CHANGE_ME' $(ENV) || { echo "docker/.env masih berisi CHANGE_ME:"; grep '=CHANGE_ME' $(ENV); exit 1; }

up: check-env ## Build & jalankan semua service (migrasi otomatis), tunggu healthy
	$(COMPOSE) up -d --build --wait --wait-timeout 300
	@$(COMPOSE) ps
	@echo "API + Studio: $$(grep '^SUPABASE_PUBLIC_URL=' $(ENV) | cut -d= -f2)"

down: ## Hentikan semua service (data tetap ada)
	$(COMPOSE) down

logs: ## Ikuti log (filter service: make logs s=auth-bridge)
	$(COMPOSE) logs -f --tail=200 $(s)

ps: ## Status service
	$(COMPOSE) ps

reset: check-env ## HAPUS semua volume (DB & storage), lalu naik ulang
	$(COMPOSE) down -v --remove-orphans
	$(MAKE) up

migrate: check-env ## Jalankan migrasi baru di supabase/migrations
	$(TOOLS) migrate

seed: check-env ## Isi data dummy development
	$(TOOLS) seed

test: test-db test-bridge test-dummy-olt ## Tes backend (pgTAP + Go)

test-db: check-env ## Tes pgTAP (supabase/tests)
	$(TOOLS) test-db

test-bridge: ## Unit test auth-bridge (Go, di container)
	docker run --rm -v "$(CURDIR)/services/auth-bridge:/src" -w /src $(GO_IMG) go test ./...

test-flutter: ## Analyze + unit/widget test package Flutter (butuh Flutter SDK)
	cd $(PKG) && flutter analyze && flutter test

smoke: check-env ## Smoke test end-to-end lewat Kong (butuh seed + mode mock)
	$(TOOLS) smoke

backup: check-env ## Backup DB (+ file storage) ke folder backups/
	$(TOOLS) backup
	docker run --rm -v olt-social_storage-data:/data:ro -v "$(CURDIR)/backups:/backup" alpine:3.22.7 \
	  tar czf /backup/storage-$$(date -u +%Y%m%d-%H%M%S).tar.gz -C /data .

restore: check-env ## Restore DB: make restore FILE=olt-YYYYMMDD-HHMMSS.dump CONFIRM=yes
	$(COMPOSE) run --rm -e CONFIRM=$(CONFIRM) tools restore $(FILE)

gen-keys: ## Buat docker/.env + rahasia baru (FORCE=1 untuk menimpa)
	@# .env mungkin belum ada; interpolasi compose cukup memakai .env.example.
	$(COMPOSE) --env-file docker/.env.example run --rm tools gen-keys $(if $(FORCE),--force)

psql: check-env ## Buka psql ke DB sebagai postgres
	$(TOOLS) psql

test-flutter-it: check-env ## Integration test package Flutter ke stack lokal (butuh Flutter SDK)
	cd $(PKG) && OLT_SOCIAL_IT=1 flutter test test/integration

e2e-windows: check-env ## E2E app example di Windows (butuh Flutter SDK + Visual Studio)
	cd $(PKG)/example && flutter test integration_test/app_test.dart -d windows \
	  --dart-define=OLT_SOCIAL_ANON_KEY=$$(grep '^ANON_KEY=' $(CURDIR)/$(ENV) | cut -d= -f2)

web-example: check-env ## App example versi web di http://localhost:8081 (?user=sari_invest), butuh Flutter SDK
	cd $(PKG)/example && flutter build web --release --no-web-resources-cdn --pwa-strategy=none \
	  --dart-define=OLT_SOCIAL_ANON_KEY=$$(grep '^ANON_KEY=' $(CURDIR)/$(ENV) | cut -d= -f2)
	@# Server statis untuk build/web; container lama diganti. Stop: docker rm -f olt-web-example
	@docker rm -f olt-web-example >/dev/null 2>&1 || true
	docker run -d --name olt-web-example --restart unless-stopped -p 127.0.0.1:8081:8081 \
	  -v "$(CURDIR)/$(PKG)/example/build/web:/srv:ro" $(WEB_IMG) caddy file-server --root /srv --listen :8081
	@echo "App web: http://localhost:8081  (langsung login: http://localhost:8081/?user=sari_invest)"

license-audit: ## Audit lisensi dependensi runtime Flutter (tolak GPL/AGPL)
	cd $(PKG) && dart run tool/license_audit.dart

# --- OLT dummy (development/testing) -------------------------------------------------

dummy-token: check-env ## Token sesi OLT dummy: make dummy-token U=budi_santoso [TTL=1h]
	@$(DUMMY_COMPOSE) run --rm --no-deps -T dummy-olt token $(or $(U),budi_santoso) $(if $(TTL),-ttl $(TTL))

smoke-dummy: check-env ## Smoke test auth-bridge mode websocket vs OLT dummy (butuh up DUMMY_OLT=1)
	$(DUMMY_COMPOSE) run --rm tools smoke-dummy

test-dummy-olt: ## Unit test OLT dummy (Go, di container)
	docker run --rm -v "$(CURDIR)/services/dummy-olt:/src" -w /src $(GO_IMG) go test ./...

test-flutter-it-dummy: check-env ## Integration test Flutter: login lewat OLT dummy (butuh up DUMMY_OLT=1)
	cd $(PKG) && OLT_SOCIAL_IT_DUMMY=1 flutter test test/integration/dummy_olt_integration_test.dart

e2e-windows-dummy: check-env ## E2E app example: form login OLT dummy (butuh up DUMMY_OLT=1)
	cd $(PKG)/example && flutter test integration_test/dummy_olt_login_test.dart -d windows \
	  --dart-define=OLT_DUMMY_E2E=true \
	  --dart-define=OLT_SOCIAL_ANON_KEY=$$(grep '^ANON_KEY=' $(CURDIR)/$(ENV) | cut -d= -f2)
