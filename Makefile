# OLT Social operations (Linux / macOS / WSL / VPS). On Windows without make use .\make.ps1 <target>.
#
# PROFILE (docs/PROMPT-PRODUCTION.md section 1):
#   dev     (default) developer laptop: http://localhost:8000, Studio, mock OLT token
#   single  single-server production: Traefik HTTPS, Studio off (make admin-up)
#   cluster Docker Swarm (skeleton)
# PROD=1 is a legacy alias for PROFILE=single.
# DUMMY_OLT=1 adds the dummy OLT (social token issuer) + auth-bridge jwt mode (dev profile only).
# CS=1 enables chat customer service (React web CS) in the single profile.

PROFILE ?= dev
ifdef PROD
override PROFILE := single
endif
ifeq ($(filter $(PROFILE),dev single cluster),)
$(error PROFILE must be dev, single, or cluster)
endif
ifneq ($(and $(DUMMY_OLT),$(filter-out dev,$(PROFILE))),)
$(error DUMMY_OLT is only allowed with the dev profile)
endif

FILES_dev     := -f docker/compose.yml -f docker/compose.dev.yml $(if $(DUMMY_OLT),-f docker/compose.dummy-olt.yml)
FILES_single  := -f docker/compose.yml -f docker/compose.prod.yml $(if $(CS),-f docker/compose.cs.yml)
FILES_cluster := -f docker/compose.yml -f docker/compose.prod.yml
CS_dev        := --profile cs
CS_single     := $(if $(CS),--profile cs)
COMPOSE       := docker compose $(FILES_$(PROFILE)) $(CS_$(PROFILE))
DUMMY_COMPOSE := docker compose -f docker/compose.yml -f docker/compose.dev.yml -f docker/compose.dummy-olt.yml --profile cs
STACK         := olt-social
TOOLS         := $(COMPOSE) run --rm tools
RACE_REST     := olt-cs-race-rest-1 olt-cs-race-rest-2 olt-cs-race-rest-3
ENV           := docker/.env
SECRETS       := docker/secrets
# Local builds skip attestations (they embed a timestamp) so an unchanged rebuild keeps the
# same image ID and `up --build` does not restart containers.
export BUILDX_NO_DEFAULT_ATTESTATIONS := 1
NODE_IMG      := node:24.22.2-alpine@sha256:8a32c8cf649a49915a66e81e7a609223c708d0adabf288ee3f4077d765542f85
GO_IMG        := golang:1.27.3-alpine3.24@sha256:d200d2dd76b03a99b52651fd1325aff7dcd35422c35c01bac56571b0507f3deb
GITLEAKS_IMG  := ghcr.io/gitleaks/gitleaks:v8.28.0@sha256:cdbb7c955abce02001a9f6c9f602fb195b7fadc1e812065883f695d1eeaba854
TOOLS_IMG     := olt-social/tools:0.1.0
ALPINE_IMG    := alpine:3.22.7@sha256:2e0b81d60597f449baa56dc25d355367869d2dca4cd57e866f1e2b52af3eb55f
WEB_IMG       := caddy:2.10.2-alpine@sha256:4c6e91c6ed0e2fa03efd5b44747b625fec79bc9cd06ac5235a779726618e530d
# The Flutter package lives in its own repo (github.com/dayat123123/rendezvous_community): clone it next to
# this repo or set PKG=<path>. Used by the Flutter targets, web-example and the static-config cs_api check.
PKG           ?= ../rendezvous_community
TESTKIT_IMG   := olt-social/testkit:0.1.0
TESTKIT_SECRETS := anon_key jwt_secret postgres_password olt_dev_signing_key
# Security/load/chaos test kit (k6, psql, docker CLI; docker.sock is for chaos) on the dev stack's
# edge+app+data networks. Results go to tests/results/ (not committed).
TESTKIT       = docker run --rm --network $(STACK)_app --network $(STACK)_data --network $(STACK)_edge \
                  -v /var/run/docker.sock:/var/run/docker.sock -v "$(CURDIR)/tests:/olt/tests:ro" \
                  -v "$(CURDIR)/tests/results:/olt/results" -v "$(CURDIR)/docker:/olt/docker:ro" \
                  --mount type=tmpfs,destination=/olt/docker/secrets \
                  $(if $(wildcard $(PKG)/lib),-v "$(abspath $(PKG))/lib:/olt/client-lib:ro") \
                  $(foreach s,$(TESTKIT_SECRETS),-v "$(CURDIR)/$(SECRETS)/$(s):/olt/secrets/$(s):ro") \
                  -e LOAD_STEPS -e LOAD_HOLD -e LOAD_RAMP -e LOAD_MSG_EVERY -e LOAD_FORCE -e LOAD_VIA \
                  -e GAP_EVERY -e GAP_IDS -e GAP_OVERLAP -e RECONNECT_JITTER -e GAP_RECHECK \
                  -e TYPING -e LIST_VUS -e LIST_POLL -e PRESENCE \
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
        test-media test-sentinel test-healer test-backup test-integration test-link-preview test-classifier check-go-comments secrets-scan backup-snapshots restore-pitr \
        smoke-cs cs-race cs-demo cs-staff cs-bootstrap-admin cs-console-react test-cs-console e2e-cs-console \
        testkit test-security test-zap scan-deps load-test load-integration chaos-test loadtest-cleanup

help: ## List targets
	@grep -E '^[a-z0-9-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-15s %s\n", $$1, $$2}'

check-config:
	@test -f $(ENV) || { echo "docker/.env is missing. Run: make gen-secrets"; exit 1; }
	@for s in $(SECRET_NAMES); do test -s $(SECRETS)/$$s || { echo "Secret $$s is missing. Run: make gen-secrets"; exit 1; }; done
	@test -f $(SECRETS)/csadmin_signing_key || : > $(SECRETS)/csadmin_signing_key
	@! grep -q '=CHANGE_ME' $(ENV) || { echo "docker/.env still contains CHANGE_ME:"; grep '=CHANGE_ME' $(ENV); exit 1; }
	@if [ "$(PROFILE)" != dev ]; then for k in PROXY_DOMAIN ACME_EMAIL; do \
	  grep -qE "^$$k=.+" $(ENV) || { echo "Profile $(PROFILE): $$k is required in docker/.env"; exit 1; }; done; \
	  for k in AUTH_BRIDGE_RATE_LIMIT_PER_MINUTE EDGE_WS_PER_IP; do \
	    v=$$(sed -n "s/^$$k=\([0-9]*\).*/\1/p" $(ENV) | tail -1); \
	    [ -z "$$v" ] || [ "$$v" -ge 1000 ] || { echo "Profile $(PROFILE): $$k=$$v in docker/.env is too low (minimum 1000, see docs/PRODUCTION.md 'Batas & rate limit')"; exit 1; }; done; fi

up: check-config ## Build and start the stack (PROFILE=dev|single|cluster), wait until healthy
ifeq ($(PROFILE),cluster)
	set -a; . ./$(ENV); set +a; docker stack deploy --detach=false -c docker/compose.yml -c docker/stack.cluster.yml $(STACK)
else
	$(COMPOSE) up -d --build --wait --wait-timeout 300 --remove-orphans
	@$(COMPOSE) ps
	@echo "API: $$(grep '^SUPABASE_PUBLIC_URL=' $(ENV) | cut -d= -f2)  (profile $(PROFILE))"
endif

down: ## Stop all services (data is kept)
ifeq ($(PROFILE),cluster)
	docker stack rm $(STACK)
else
	$(COMPOSE) --profile admin --profile cs down
endif

logs: ## Follow logs (filter by service: make logs s=auth-bridge)
	$(COMPOSE) logs -f --tail=200 $(s)

ps: ## Service status
	$(COMPOSE) ps

reset: check-config ## DELETE all volumes (DB & storage) and start again: make reset CONFIRM=yes
	@[ "$(CONFIRM)" = yes ] || { echo "This DELETES all DB & storage data. Re-run with CONFIRM=yes"; exit 1; }
	$(COMPOSE) --profile admin down -v --remove-orphans
	$(MAKE) up

migrate: check-config ## Apply new migrations from supabase/migrations
	$(TOOLS) migrate

seed: check-config ## Load development dummy data
	$(TOOLS) seed

test: test-db test-bridge test-dummy-olt test-nasabah-gateway test-notifier test-janitor test-media test-sentinel test-healer test-backup test-integration test-link-preview test-classifier check-go-comments ## Backend tests (pgTAP + Go)

test-db: check-config ## pgTAP tests (supabase/tests)
	$(TOOLS) test-db

test-bridge: ## auth-bridge unit tests (Go, in a container)
	docker run --rm -v "$(CURDIR)/services/auth-bridge:/src" -w /src $(GO_IMG) go test ./...

test-flutter: ## Analyze + unit/widget tests of the Flutter package (needs the Flutter SDK)
	cd $(PKG) && flutter analyze && flutter test

smoke: check-config ## End-to-end smoke test through Kong (needs seed + mock mode)
	$(TOOLS) smoke

backup: check-config ## Back up the DB (+ storage files) to backups/
	$(TOOLS) backup
	docker run --rm -v olt-social_storage-data:/data:ro -v "$(CURDIR)/backups:/backup" $(ALPINE_IMG) \
	  tar czf /backup/storage-$$(date -u +%Y%m%d-%H%M%S).tar.gz -C /data .

restore: check-config ## Restore the DB: make restore FILE=olt-YYYYMMDD-HHMMSS.dump CONFIRM=yes
	$(COMPOSE) run --rm -e CONFIRM=$(CONFIRM) tools restore $(FILE)

backup-snapshots: check-config ## List backup snapshots (restic) + PITR time range
	$(COMPOSE) run --rm --no-deps -T \
	  $(if $(RESTIC_REPOSITORY),$(if $(RESTIC_LOCAL),-v "$(abspath $(RESTIC_LOCAL)):/var/lib/olt-backup-repo" -e RESTIC_REPOSITORY=/var/lib/olt-backup-repo,-e RESTIC_REPOSITORY) \
	    -e RESTIC_PASSWORD -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION) \
	  $(if $(RESTIC_PASSWORD_FILE),-v "$(abspath $(RESTIC_PASSWORD_FILE)):/run/secrets/restic_password:ro" -e RESTIC_PASSWORD_FILE=/run/secrets/restic_password) \
	  backup snapshots

RESTIC_LOCAL = $(if $(filter s3:% sftp:% rest:% swift:% b2:% azure:% gs:% rclone:%,$(RESTIC_REPOSITORY)),,$(RESTIC_REPOSITORY))

restore-pitr: check-config ## PITR: make restore-pitr AT=<RFC3339|latest> CONFIRM=yes (env RESTIC_*, AWS_* for S3; docs/backup)
	@test "$(CONFIRM)" = yes || { echo "The database contents will be replaced by the restore. Re-run with CONFIRM=yes"; exit 1; }
	@test -n "$(AT)" || { echo "Specify AT=2026-11-03T10:15:00+07:00 or AT=latest"; exit 1; }
	@test -n "$$RESTIC_REPOSITORY" || { echo "Set RESTIC_REPOSITORY (s3:https://host/bucket/prefix or a local folder, e.g. backups/restic), RESTIC_PASSWORD (or RESTIC_PASSWORD_FILE); for S3 also AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY"; exit 1; }
	@test -z "$(RESTIC_LOCAL)" || test -f "$(RESTIC_LOCAL)/config" || { echo "$(RESTIC_LOCAL) is not a restic repository (config file missing)"; exit 1; }
	$(COMPOSE) build backup
	$(COMPOSE) stop
	docker run --rm --user 0:0 --network $(STACK)_egress \
	  $(if $(RESTIC_LOCAL),-v "$(abspath $(RESTIC_LOCAL)):/var/lib/olt-backup-repo" -e RESTIC_REPOSITORY=/var/lib/olt-backup-repo,-e RESTIC_REPOSITORY) \
	  -e RESTIC_PASSWORD -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION \
	  $(if $(RESTIC_PASSWORD_FILE),-v "$(abspath $(RESTIC_PASSWORD_FILE)):/run/secrets/restic_password:ro" -e RESTIC_PASSWORD_FILE=/run/secrets/restic_password) \
	  -v $(STACK)_db-data:/restore olt-social/backup:0.2.0 \
	  restore --target-time "$(AT)" --data-dir /restore --wipe
	$(COMPOSE) up -d db
	@echo "Waiting for recovery to finish (follow: make logs s=db)..."
	@for i in $$(seq 1 720); do $(COMPOSE) exec -T db pg_isready -U postgres -h localhost -q && exit 0; sleep 5; done; \
	  echo "Database not ready after 1 hour; see make logs s=db"; exit 1
	$(COMPOSE) exec -T db psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 \
	  -c "ALTER SYSTEM RESET restore_command" -c "ALTER SYSTEM RESET recovery_target_time" \
	  -c "ALTER SYSTEM RESET recovery_target_action" -c "ALTER SYSTEM RESET recovery_target_timeline" \
	  -c "SELECT pg_reload_conf()"
	$(COMPOSE) exec -T -u postgres db rm -rf /var/lib/postgresql/data/restore_wal
	@echo "Database restored to $(AT). Check the data, then: make up"

gen-secrets: ## Create docker/secrets/ + docker/.env (idempotent; FORCE=1 regenerates everything)
	docker build -q -t $(TOOLS_IMG) docker/tools > /dev/null
	docker run --rm --user "$$(id -u):$$(id -g)" -v "$(CURDIR)/docker:/olt/docker" -v "$(CURDIR)/scripts:/olt/scripts:ro" \
	  --entrypoint bash $(TOOLS_IMG) /olt/scripts/gen-secrets.sh $(if $(FORCE),--force)

gen-keys: gen-secrets ## Legacy alias for gen-secrets

anon-key: ## Print ANON_KEY for Flutter app builds (--dart-define=OLT_SOCIAL_ANON_KEY=...)
	@cat $(SECRETS)/anon_key; echo

admin-up: check-config ## Start Studio (single profile: reach it through an SSH tunnel to 127.0.0.1:8000)
	$(COMPOSE) --profile admin up -d --wait studio meta

admin-down: ## Stop Studio again (single profile)
	$(COMPOSE) --profile admin stop studio meta

psql: check-config ## Open psql to the DB as postgres
	$(TOOLS) psql

test-flutter-it: check-config ## Flutter package integration tests against the local stack (needs the Flutter SDK)
	cd $(PKG) && OLT_SOCIAL_IT=1 flutter test test/integration

e2e-windows: check-config ## Example app E2E on Windows (needs the Flutter SDK + Visual Studio)
	cd $(PKG)/example && flutter test integration_test/app_test.dart -d windows \
	  --dart-define=OLT_SOCIAL_ANON_KEY=$(ANON_KEY)

web-example: check-config ## Web build of the example app at http://localhost:8086 (?user=sari_invest), needs the Flutter SDK
	cd $(PKG)/example && flutter build web --release --no-web-resources-cdn --pwa-strategy=none \
	  --dart-define=OLT_SOCIAL_ANON_KEY=$(ANON_KEY)
	@docker rm -f olt-web-example >/dev/null 2>&1 || true
	docker run -d --name olt-web-example --restart unless-stopped -p 127.0.0.1:8086:8086 \
	  -v "$(abspath $(PKG))/example/build/web:/srv:ro" $(WEB_IMG) caddy file-server --root /srv --listen :8086
	@echo "Web app: http://localhost:8086  (direct login: http://localhost:8086/?user=sari_invest)"

license-audit: ## License audit of rendezvous_community runtime dependencies (rejects GPL/AGPL)
	cd $(PKG) && dart run tool/license_audit.dart

PERF_DEVICE ?= windows
perf-flutter: ## Flutter scroll performance test without a backend (profile mode; PERF_DEVICE=<Android id> for a phone)
	cd $(PKG)/example && flutter drive --profile -d $(PERF_DEVICE) --driver=test_driver/perf_driver.dart --target=integration_test/perf_scroll_test.dart

dummy-token: check-config ## Dummy OLT social token (JWT) for the exchange: make dummy-token U=budi_santoso [TTL=5m]
	@$(DUMMY_COMPOSE) run --rm --no-deps -T dummy-olt token $(or $(U),budi_santoso) -social $(if $(TTL),-ttl $(TTL))

smoke-dummy: check-config ## Smoke test of auth-bridge jwt mode with dummy OLT social tokens (needs up DUMMY_OLT=1)
	$(DUMMY_COMPOSE) run --rm tools smoke-dummy

smoke-cs: check-config ## End-to-end CS chat smoke test through the real API (needs up DUMMY_OLT=1)
	$(DUMMY_COMPOSE) run --rm tools smoke-cs

cs-race: check-config ## CS ticket claim race test: direct DB + 3 test-only PostgREST replicas
	-@docker rm -f $(RACE_REST) > /dev/null 2>&1
	@for name in $(RACE_REST); do $(COMPOSE) run -d --no-deps -e PGRST_DB_POOL=3 --name $$name rest > /dev/null || exit 1; done
	$(TOOLS) cs-race $(foreach name,$(RACE_REST),http://$(name):3000); 	  status=$$?; docker rm -f $(RACE_REST) > /dev/null; exit $$status

cs-bootstrap-admin: check-config ## First web CS super admin: make cs-bootstrap-admin EMAIL=name@domain NAME="Name" [FORCE=1] [PROFILE=single]
	@$(TOOLS) cs-bootstrap-admin "$(EMAIL)" "$(NAME)" $(if $(FORCE),--force)

cs-staff: check-config ## Dev staff accounts (CS, super admin, compliance) in scripts/cs-demo/runtime/staff.json
	mkdir -p scripts/cs-demo/runtime
	@(cat scripts/cs-demo/runtime/staff.json 2>/dev/null || echo '{}') | $(DUMMY_COMPOSE) run --rm -T tools cs-staff \
	  > scripts/cs-demo/runtime/staff.json.new && mv scripts/cs-demo/runtime/staff.json.new scripts/cs-demo/runtime/staff.json

cs-console-react: cs-staff ## React web CS (nginx container) at http://localhost:8085 (needs up DUMMY_OLT=1)
	$(COMPOSE) up -d --build --wait traefik cs-console
	@echo "React web CS: http://localhost:8085  (dev accounts: scripts/cs-demo/runtime/staff.json)"

test-cs-console: ## React web CS lint, typecheck, unit tests, build, bundle size, licenses (in a Node container)
	docker run --rm -v "$(CURDIR)/apps/cs-console-react:/app" -v /app/node_modules -v /app/dist -w /app $(NODE_IMG) \
	  sh -c 'npm ci --no-audit --no-fund && npm run ci'

e2e-cs-console: cs-console-react ## Playwright E2E of the React web CS against the dev stack (needs up DUMMY_OLT=1, Node 24 + Playwright Chromium)
	cd apps/cs-console-react && E2E_BASE_URL=http://localhost:8085 npx playwright test

cs-demo: check-config ## CS demo page (customer + agent panel) at http://localhost:8082 (needs up DUMMY_OLT=1)
	mkdir -p scripts/cs-demo/runtime
	$(DUMMY_COMPOSE) run --rm -T tools cs-demo-config > scripts/cs-demo/runtime/config.js
	-docker rm -f olt-cs-demo
	docker run -d --name olt-cs-demo --restart unless-stopped -p 127.0.0.1:8082:8082 	  -v "$(CURDIR)/scripts/cs-demo:/srv:ro" $(WEB_IMG) caddy file-server --root /srv --listen :8082
	@echo "Demo CS: http://localhost:8082  (stop: docker rm -f olt-cs-demo)"

test-dummy-olt: ## Dummy OLT unit tests (Go, in a container)
	docker run --rm -v "$(CURDIR)/services/dummy-olt:/src" -w /src $(GO_IMG) go test ./...

test-nasabah-gateway: ## Customer menu gateway unit tests (Go, in a container)
	docker run --rm -v "$(CURDIR)/services/nasabah-gateway:/src" -w /src $(GO_IMG) go test ./...

test-notifier: ## Push notifier unit tests (Go, in a container)
	docker run --rm -v "$(CURDIR)/services/notifier:/src" -w /src $(GO_IMG) go test ./...

test-janitor: ## Storage file janitor unit tests (Go, in a container)
	docker run --rm -v "$(CURDIR)/services/janitor:/src" -w /src $(GO_IMG) go test ./...

test-media: ## Customer media upload gateway unit tests (Go, in a container)
	docker run --rm -v "$(CURDIR)/services/media:/src" -w /src $(GO_IMG) go test ./...

test-sentinel: ## System monitor + alert unit tests (Go, in a container)
	docker run --rm -v "$(CURDIR)/services/sentinel:/src" -w /src $(GO_IMG) go test ./...

test-healer: ## Unhealthy container auto-restart unit tests (Go, in a container)
	docker run --rm -v "$(CURDIR)/services/healer:/src" -w /src $(GO_IMG) go test ./...

test-backup: ## Backup service unit tests (Go, in a container)
	docker run --rm -v "$(CURDIR)/services/backup:/src" -w /src $(GO_IMG) go test ./...

test-integration: ## OLT integration gateway unit tests (Go, in a container)
	docker run --rm -v "$(CURDIR)/services/integration:/src" -w /src $(GO_IMG) go test ./...

test-link-preview: ## Link preview unit tests (Go, in a container)
	docker run --rm -v "$(CURDIR)/services/link-preview:/src" -w /src $(GO_IMG) go test ./...

test-classifier: ## NSFW classifier unit tests (Go + cgo, in a container)
	docker run --rm -v "$(CURDIR)/services/classifier:/src" -w /src $(GO_IMG) sh -c 'apk add --no-cache gcc musl-dev >/dev/null && CGO_ENABLED=1 go test ./...'

check-go-comments: ## Ensure Go code has no comments (other than directives)
	docker run --rm -v "$(CURDIR):/repo" -w /repo/scripts/check-go-comments $(GO_IMG) go run . /repo/services

secrets-scan: ## Scan git history with gitleaks (.gitleaks.toml)
	docker run --rm -v "$(CURDIR):/repo" $(GITLEAKS_IMG) git /repo --config /repo/.gitleaks.toml --redact --no-banner

test-flutter-it-dummy: check-config ## Flutter integration test: login through the dummy OLT (needs up DUMMY_OLT=1)
	cd $(PKG) && OLT_SOCIAL_IT_DUMMY=1 flutter test test/integration/dummy_olt_integration_test.dart

e2e-windows-dummy: check-config ## Example app E2E: dummy OLT login form (needs up DUMMY_OLT=1)
	cd $(PKG)/example && flutter test integration_test/dummy_olt_login_test.dart -d windows \
	  --dart-define=OLT_DUMMY_E2E=true \
	  --dart-define=OLT_SOCIAL_ANON_KEY=$(ANON_KEY)

# Security, load and chaos tests (docs/testing/README.md) run only against the DEV stack with the
# dummy OLT (make up DUMMY_OLT=1); never point them at production.

testkit: ## Build the olt-social/testkit test image (k6, tokengen, psql, docker CLI)
	@[ "$(PROFILE)" = dev ] || { echo "Security/load/chaos tests are for PROFILE=dev only"; exit 1; }
	@mkdir -p tests/results
	docker build -q -t $(TESTKIT_IMG) tests > /dev/null

test-security: check-config testkit ## Authorization probes (anon/other customer/agent without permission), static edge config, production routing
	$(TESTKIT) security

scan-deps: ## Vulnerability scan: govulncheck, npm audit, osv-scanner, Trivy (STRICT=1 fails on blocking findings)
	bash tests/security/scan-deps.sh $(if $(STRICT),--strict) $(if $(THIRD_PARTY),--third-party)

load-test: check-config testkit ## k6 market-open load test: make load-test P=smoke|step|spike|light (LOAD_STEPS="50 100 200")
	$(TESTKIT) load $(or $(P),smoke)

load-integration: check-config testkit ## OLT integration API load test (notify per cust_id + stock_watchers broadcast, inbox only)
	$(TESTKIT) integration

chaos-test: check-config testkit ## Chaos tests under light load: make chaos-test [E="realtime valkey"]
	$(TESTKIT) chaos $(E)

loadtest-cleanup: check-config testkit ## Delete lt_* test data (DRY=1 only shows it)
	$(TESTKIT) cleanup $(if $(DRY),--dry-run)

test-zap: check-config testkit ## Passive OWASP ZAP baseline (optional, ~1.2 GB image) against web CS :8085 and the dev API
	$(TESTKIT) zap
