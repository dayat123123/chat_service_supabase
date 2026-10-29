# OLT Social - perintah operasional (Linux / macOS / WSL / VPS).
# Windows tanpa make: pakai .\make.ps1 <target> dengan target yang sama.

# PROD=1 menambahkan Caddy (HTTPS) di depan Kong, untuk VPS.
COMPOSE := docker compose -f docker/docker-compose.yml $(if $(PROD),-f docker/docker-compose.prod.yml)
TOOLS   := $(COMPOSE) run --rm tools
ENV     := docker/.env
GO_IMG  := golang:1.24.5-alpine3.22
PKG     := packages/olt_social

.DEFAULT_GOAL := help
.PHONY: help up down logs ps reset migrate seed test test-db test-bridge test-flutter test-flutter-it \
        e2e-windows license-audit smoke backup restore gen-keys psql check-env

help: ## Tampilkan daftar target
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-13s %s\n", $$1, $$2}'

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

test: test-db test-bridge ## Tes backend (pgTAP + Go)

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
	cd $(PKG)/example && flutter test integration_test -d windows \
	  --dart-define=OLT_SOCIAL_ANON_KEY=$$(grep '^ANON_KEY=' $(CURDIR)/$(ENV) | cut -d= -f2)

license-audit: ## Audit lisensi dependensi runtime Flutter (tolak GPL/AGPL)
	cd $(PKG) && dart run tool/license_audit.dart
