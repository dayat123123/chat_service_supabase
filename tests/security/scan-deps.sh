#!/usr/bin/env bash
# Vulnerability scan of dependencies and images: govulncheck, npm audit, osv-scanner, Trivy.
# Run from anywhere (Git Bash / Linux): bash tests/security/scan-deps.sh [--strict] [--third-party] [--only go,npm,osv,trivy,third-party]
# Re-summarize earlier results without scanning: bash tests/security/scan-deps.sh --summary tests/security/results/deps-<time>
# Every tool runs in a container pinned by tag + digest. Raw results: tests/security/results/deps-<time>/.
# Exit code: 0 = done (findings are only reported), 1 = --strict with blocking findings, 2 = a tool failed to run.
set -uo pipefail

GO_IMG=golang:1.27.3-alpine3.24@sha256:d200d2dd76b03a99b52651fd1325aff7dcd35422c35c01bac56571b0507f3deb
NODE_IMG=node:24.22.2-alpine@sha256:8a32c8cf649a49915a66e81e7a609223c708d0adabf288ee3f4077d765542f85
OSV_IMG=ghcr.io/google/osv-scanner:v2.7.0@sha256:4f3b7e2c64b9d38a5febc5a7e4a3dfef1d1362f726dea7a2ef4762b46469fcd0
TRIVY_IMG=aquasec/trivy:0.76.1@sha256:790fd66d1697395d8693d1acaa1ea702406a20f109b6fc7bac8db623eca6c06c
GOVULNCHECK_VERSION=v1.9.0

GO_PATH_VOL=olt-security-gopath
GO_BUILD_VOL=olt-security-gobuild
TRIVY_CACHE_VOL=olt-security-trivy

export MSYS_NO_PATHCONV=1

strict=0
summary_only=""
sections="go,npm,osv,trivy"
while [ $# -gt 0 ]; do
  case "$1" in
    --strict) strict=1 ;;
    --third-party) sections="$sections,third-party" ;;
    --only) sections="${2:?--only needs a section list}"; shift ;;
    --summary) summary_only="${2:?--summary needs a results directory}"; shift ;;
    -h|--help) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

cd "$(dirname "$0")/../.." || exit 2
ROOT="$(pwd -W 2>/dev/null || pwd)"
if [ -n "$summary_only" ]; then
  OUT_REL="${summary_only%/}"
  [ -f "$OUT_REL/run-info.txt" ] || { echo "Not a results directory: $OUT_REL" >&2; exit 2; }
  sections="$(sed -n -E 's/^(sections|bagian): //p' "$OUT_REL/run-info.txt")"
else
  OUT_REL="tests/security/results/deps-$(date +%Y%m%d-%H%M%S)"
fi
OUT="$ROOT/$OUT_REL"
mkdir -p "$OUT_REL"/{go,npm,osv,trivy,third-party}
HOST_IDS="$(id -u):$(id -g)"
SRC_RO=(--mount "type=bind,source=$ROOT,target=/src,readonly")
PKG_DIR="${PKG:-../rendezvous_community}"
PKG_RO=()
[ -d "$PKG_DIR" ] && PKG_RO=(--mount "type=bind,source=$(cd "$PKG_DIR" && { pwd -W 2>/dev/null || pwd; }),target=/pkg/rendezvous_community,readonly")
DOCKER_SOCK=(-v /var/run/docker.sock:/var/run/docker.sock)

errors=0
want() { [[ ",$sections," == *",$1,"* ]]; }
tool_fail() {
  echo "FAILED - $1" >&2
  echo "$1" >> "$OUT_REL/errors.txt"
  errors=$((errors + 1))
}
safe_name() { tr '/:@' '___' <<< "$1"; }

[ -n "$summary_only" ] || {
  echo "date: $(date -Iseconds)"
  echo "git: $(git rev-parse --short HEAD 2>/dev/null) $(git status --porcelain 2>/dev/null | wc -l | tr -d ' ') files changed"
  echo "GO_IMG=$GO_IMG"
  echo "NODE_IMG=$NODE_IMG"
  echo "OSV_IMG=$OSV_IMG"
  echo "TRIVY_IMG=$TRIVY_IMG"
  echo "GOVULNCHECK_VERSION=$GOVULNCHECK_VERSION"
  echo "sections: $sections"
} > "$OUT_REL/run-info.txt"

scan_go() {
  local mod name cgo
  for mod in services/*/ scripts/check-go-comments/; do
    mod="${mod%/}"
    [ -f "$mod/go.mod" ] || continue
    name="$(basename "$mod")"
    cgo=0
    [ "$name" = classifier ] && cgo=1
    echo "==> govulncheck $mod"
    docker run --rm "${SRC_RO[@]}" \
      --mount "type=bind,source=$OUT/go,target=/out" \
      -v "$GO_PATH_VOL:/go" -v "$GO_BUILD_VOL:/root/.cache/go-build" \
      -e GOTOOLCHAIN=local -e GOFLAGS=-mod=readonly -e CGO_ENABLED="$cgo" \
      -e NAME="$name" -e V="$GOVULNCHECK_VERSION" -e HOST_IDS="$HOST_IDS" \
      -w "/src/$mod" "$GO_IMG" sh -uc '
        if [ "$CGO_ENABLED" = 1 ]; then apk add --no-cache gcc musl-dev >/dev/null || exit 10; fi
        go install "golang.org/x/vuln/cmd/govulncheck@$V" || exit 11
        govulncheck -format json ./... > "/out/$NAME.json" || exit 12
        govulncheck -show verbose ./... > "/out/$NAME.txt" 2>&1
        rc=$?
        chown "$HOST_IDS" "/out/$NAME.json" "/out/$NAME.txt" 2>/dev/null || true
        [ "$rc" -eq 0 ] || [ "$rc" -eq 3 ] || exit 13
      ' 2> "$OUT_REL/go/$name.log" || tool_fail "govulncheck $mod (see $OUT_REL/go/$name.log)"
  done
}

scan_npm() {
  local app=apps/cs-console-react mode flag
  for mode in prod all; do
    flag=""
    [ "$mode" = prod ] && flag="--omit=dev"
    echo "==> npm audit $app ($mode)"
    docker run --rm "${SRC_RO[@]}" -e FLAG="$flag" -e APP="$app" "$NODE_IMG" sh -uc '
      mkdir -p /tmp/audit && cp "/src/$APP/package.json" "/src/$APP/package-lock.json" /tmp/audit/ && cd /tmp/audit || exit 10
      npm audit $FLAG --package-lock-only --json
      rc=$?
      [ "$rc" -eq 0 ] || [ "$rc" -eq 1 ] || exit "$rc"
    ' > "$OUT_REL/npm/audit-$mode.json" 2> "$OUT_REL/npm/audit-$mode.log" \
      || tool_fail "npm audit $mode (see $OUT_REL/npm/audit-$mode.log)"
    grep -q '"auditReportVersion"' "$OUT_REL/npm/audit-$mode.json" || tool_fail "npm audit $mode: output is not an audit report"
  done
}

scan_osv() {
  local args=() f fmt rc
  for f in rendezvous_community/pubspec.lock rendezvous_community/example/pubspec.lock; do
    [ -f "$PKG_DIR/${f#rendezvous_community/}" ] && args+=(-L "/pkg/$f")
  done
  for f in apps/cs-console-react/package-lock.json services/*/go.mod scripts/check-go-comments/go.mod; do
    [ -f "$f" ] && args+=(-L "/src/$f")
  done
  for fmt in json table; do
    echo "==> osv-scanner ($fmt)"
    docker run --rm "${SRC_RO[@]}" "${PKG_RO[@]}" "$OSV_IMG" scan source --format "$fmt" "${args[@]}" \
      > "$OUT_REL/osv/osv.$fmt" 2> "$OUT_REL/osv/osv-$fmt.log"
    rc=$?
    [ "$rc" -eq 0 ] || [ "$rc" -eq 1 ] || tool_fail "osv-scanner $fmt exited $rc (see $OUT_REL/osv/osv-$fmt.log)"
  done
}

trivy() {
  docker run --rm "${DOCKER_SOCK[@]}" -v "$TRIVY_CACHE_VOL:/cache" "$TRIVY_IMG" "$@"
}

trivy_db() {
  echo "==> trivy: download database"
  trivy image --cache-dir /cache --no-progress --download-db-only > /dev/null 2> "$OUT_REL/trivy/db.log" \
    || { tool_fail "trivy DB download (see $OUT_REL/trivy/db.log)"; return 1; }
}

trivy_scan() {
  local dir="$1" ref="$2" label="$3" base
  base="$OUT_REL/$dir/$(safe_name "$label")"
  echo "==> trivy $label"
  trivy image --cache-dir /cache --no-progress --skip-db-update --scanners vuln --format json "$ref" \
    > "$base.json" 2> "$base.log" || { tool_fail "trivy $label (see $base.log)"; return; }
  trivy image --cache-dir /cache --no-progress --skip-db-update --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --format table "$ref" \
    > "$base.txt" 2>> "$base.log" || tool_fail "trivy table $label (see $base.log)"
}

own_images() {
  docker images --format '{{.Repository}}:{{.Tag}}' | grep '^olt-social/' | grep -v '<none>' | sort -u
}

current_images() {
  grep -hoE 'olt-social/[a-z0-9._-]+:[A-Za-z0-9._-]+' docker/compose*.yml docker/stack*.yml 2>/dev/null | sort -u
}

third_party_images() {
  grep -hE '^\s*image:' docker/compose.yml | sed -E 's/^\s*image:\s*//; s/["'\'']//g' | grep -v '^olt-social/' | sort -u
}

scan_trivy() {
  local img
  own_images > "$OUT_REL/trivy/images.txt"
  current_images > "$OUT_REL/trivy/current.txt"
  while read -r img; do
    [ -n "$img" ] && trivy_scan trivy "$img" "$img"
  done < "$OUT_REL/trivy/images.txt"
}

scan_third_party() {
  local img ref
  third_party_images > "$OUT_REL/third-party/images.txt"
  while read -r img; do
    [ -n "$img" ] || continue
    ref="$img"
    [[ "$img" == *@sha256:* ]] && ref="${img%%:*}@${img#*@}"
    trivy_scan third-party "$ref" "${img%%@*}"
  done < "$OUT_REL/third-party/images.txt"
}

summarizer() {
  cat <<'JS'
const fs = require('fs');
const path = require('path');
const OUT = '/out';
const strict = process.env.STRICT === '1';
const sections = new Set((process.env.SECTIONS || '').split(','));
const read = (p) => { try { return fs.readFileSync(p, 'utf8'); } catch { return null; } };
const readJson = (p) => { const t = read(p); if (!t) return null; try { return JSON.parse(t); } catch { return null; } };
const list = (d, ext) => { try { return fs.readdirSync(path.join(OUT, d)).filter((f) => f.endsWith(ext)).sort(); } catch { return []; } };
const lines = (p) => (read(p) || '').split(/\r?\n/).map((s) => s.trim()).filter(Boolean);
const SEV = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'UNKNOWN'];
const blocking = [];
const out = [];
const say = (s = '') => out.push(s);

function table(head, rows) {
  const w = head.map((h, i) => Math.max(h.length, ...rows.map((r) => String(r[i]).length)));
  const fmt = (r) => r.map((c, i) => (i === 0 ? String(c).padEnd(w[i]) : String(c).padStart(w[i]))).join('  ');
  say(fmt(head));
  say(w.map((n) => '-'.repeat(n)).join('  '));
  rows.forEach((r) => say(fmt(r)));
}

function jsonStream(text) {
  const res = [];
  let depth = 0, start = -1, inStr = false, esc = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (inStr) {
      if (esc) esc = false;
      else if (c === '\\') esc = true;
      else if (c === '"') inStr = false;
      continue;
    }
    if (c === '"') inStr = true;
    else if (c === '{') { if (depth++ === 0) start = i; }
    else if (c === '}') { if (--depth === 0) res.push(JSON.parse(text.slice(start, i + 1))); }
  }
  return res;
}

function goSection() {
  const rows = [];
  const byId = new Map();
  for (const f of list('go', '.json')) {
    const mod = f.slice(0, -5);
    let msgs;
    try { msgs = jsonStream(read(path.join(OUT, 'go', f)) || ''); } catch { msgs = []; }
    if (!msgs.some((m) => m.config)) { rows.push([mod, 'ERR', '', '', '']); continue; }
    const osv = new Map();
    const level = new Map();
    const info = new Map();
    for (const m of msgs) {
      if (m.osv) osv.set(m.osv.id, m.osv);
      if (!m.finding) continue;
      const tr = m.finding.trace || [];
      const t = tr[0] || {};
      const l = t.function ? 3 : t.package ? 2 : 1;
      const id = m.finding.osv;
      if ((level.get(id) || 0) >= l && info.has(id)) continue;
      level.set(id, l);
      const entry = tr.length > 1 ? tr[tr.length - 1] : null;
      info.set(id, {
        module: t.module, version: t.version, pkg: t.package || '',
        fn: t.function ? (t.receiver ? `${t.receiver}.${t.function}` : t.function) : '',
        entry: entry && entry.function ? `${entry.package}.${entry.receiver ? entry.receiver + '.' : ''}${entry.function}${entry.position ? ' ' + path.basename(entry.position.filename || '') + ':' + entry.position.line : ''}` : '',
        fixed: m.finding.fixed_version || 'none',
      });
    }
    const n = [0, 0, 0, 0];
    for (const [id, l] of level) {
      n[l]++;
      const i = info.get(id);
      const o = osv.get(id) || {};
      const key = `${id}|${i.module}`;
      if (!byId.has(key)) byId.set(key, { id, aliases: [...new Set(o.aliases || [])].join(','), summary: o.summary || '', module: i.module, version: i.version, fixed: i.fixed, called: [], imported: [], required: [] });
      const rec = byId.get(key);
      const where = l === 3 ? `${mod} (${i.pkg}.${i.fn}${i.entry ? ' <- ' + i.entry : ''})` : mod;
      rec[l === 3 ? 'called' : l === 2 ? 'imported' : 'required'].push(where);
      if (l === 3) blocking.push(`go ${mod}: ${id} ${i.module}@${i.version} called`);
    }
    rows.push([mod, n[3], n[2], n[1], n[1] + n[2] + n[3]]);
  }
  say('== Go (govulncheck, mode source; toolchain = image Go) ==');
  table(['module', 'called', 'imported', 'required', 'total'], rows);
  const recs = [...byId.values()].sort((a, b) => b.called.length - a.called.length || a.id.localeCompare(b.id));
  for (const kind of ['called', 'imported', 'required']) {
    const sel = recs.filter((r) => r[kind].length);
    if (!sel.length) continue;
    say();
    say(`-- Go ${kind} --`);
    for (const r of sel) {
      say(`${r.id} [${r.aliases}] ${r.module}@${r.version} -> fixed ${r.fixed}: ${r.summary}`);
      say(`    ${kind === 'called' ? r.called.join('\n    ') : r[kind].join(', ')}`);
    }
  }
  say();
}

function sevOfScore(s, fallback) {
  const n = parseFloat(s);
  if (!Number.isNaN(n)) return n >= 9 ? 'CRITICAL' : n >= 7 ? 'HIGH' : n >= 4 ? 'MEDIUM' : n > 0 ? 'LOW' : 'UNKNOWN';
  const f = String(fallback || '').toUpperCase();
  if (f === 'MODERATE') return 'MEDIUM';
  return SEV.includes(f) ? f : 'UNKNOWN';
}

function npmSection() {
  const lock = readJson('/src/apps/cs-console-react/package-lock.json') || { packages: {} };
  const rows = [];
  const details = [];
  for (const mode of ['prod', 'all']) {
    const j = readJson(path.join(OUT, 'npm', `audit-${mode}.json`));
    if (!j || !j.metadata) { rows.push([`cs-console-react (${mode})`, 'ERR', '', '', '', '']); continue; }
    const v = j.metadata.vulnerabilities || {};
    rows.push([`cs-console-react (${mode === 'prod' ? '--omit=dev' : 'including dev'})`, v.critical || 0, v.high || 0, v.moderate || 0, v.low || 0, v.total || 0]);
    for (const [name, e] of Object.entries(j.vulnerabilities || {})) {
      if (!['critical', 'high'].includes(e.severity)) continue;
      if (mode === 'all' && readJson(path.join(OUT, 'npm', 'audit-prod.json'))?.vulnerabilities?.[name]) continue;
      const versions = [...new Set((e.nodes || []).map((n) => lock.packages[n]?.version).filter(Boolean))].join(',');
      const adv = (e.via || []).filter((x) => typeof x === 'object').map((x) => `${x.url ? x.url.split('/').pop() : x.source} ${x.title} (range ${x.range})`);
      const via = (e.via || []).filter((x) => typeof x === 'string');
      const fix = e.fixAvailable === true ? 'npm audit fix' : e.fixAvailable ? `${e.fixAvailable.name}@${e.fixAvailable.version}${e.fixAvailable.isSemVerMajor ? ' (major)' : ''}` : 'none';
      details.push(`[${mode === 'prod' ? 'prod' : 'dev'}] ${e.severity.toUpperCase()} ${name}@${versions} fix: ${fix}${adv.length ? '\n    ' + adv.join('\n    ') : ''}${via.length ? '\n    via ' + via.join(',') : ''}`);
      if (mode === 'prod') blocking.push(`npm prod: ${name}@${versions} ${e.severity}`);
    }
  }
  say('== npm audit (apps/cs-console-react, from package-lock) ==');
  table(['target', 'crit', 'high', 'mod', 'low', 'total'], rows);
  if (details.length) { say(); say('-- npm HIGH/CRITICAL --'); details.forEach((d) => say(d)); }
  say();
}

function fixedVersions(vuln, pkgName) {
  const s = new Set();
  for (const a of vuln.affected || []) {
    if (a.package && a.package.name !== pkgName) continue;
    for (const r of a.ranges || []) for (const e of r.events || []) if (e.fixed) s.add(e.fixed);
  }
  return [...s];
}

function osvSection() {
  const j = readJson(path.join(OUT, 'osv', 'osv.json'));
  say('== osv-scanner (lockfile mode) ==');
  if (!j) { say('ERR: osv.json unreadable'); say(); return; }
  const scanned = new Map();
  for (const l of lines(path.join(OUT, 'osv', 'osv-json.log'))) {
    const m = l.match(/^Scanned \/(?:src|pkg)\/(\S+) file and found (\d+) package/);
    if (m) scanned.set(m[1], m[2]);
  }
  const rows = [];
  const details = [];
  const seenSrc = new Set();
  for (const r of j.results || []) {
    const src = (r.source?.path || '').replace(/^\/?(?:src|pkg)\//, '');
    seenSrc.add(src);
    const isGo = src.endsWith('go.mod');
    const c = { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0, UNKNOWN: 0 };
    let stdlib = 0;
    for (const p of r.packages || []) {
      const pkg = p.package || {};
      const vulns = new Map((p.vulnerabilities || []).map((v) => [v.id, v]));
      for (const g of p.groups || [{ ids: [...vulns.keys()] }]) {
        if (isGo && pkg.name === 'stdlib') { stdlib++; continue; }
        const v0 = vulns.get(g.ids[0]) || {};
        const sev = sevOfScore(g.max_severity, v0.database_specific?.severity);
        c[sev]++;
        if (sev !== 'CRITICAL' && sev !== 'HIGH') continue;
        const fixed = [...new Set(g.ids.flatMap((id) => fixedVersions(vulns.get(id) || {}, pkg.name)))];
        details.push(`${sev} ${g.ids.join(',')} ${pkg.ecosystem}:${pkg.name}@${pkg.version} -> fixed ${fixed.join(',') || 'none'} [${src}] ${v0.summary || ''}`);
        if (fixed.length && src === 'rendezvous_community/pubspec.lock') blocking.push(`osv ${src}: ${pkg.name}@${pkg.version} ${sev}`);
      }
    }
    rows.push([src, scanned.get(src) || '?', c.CRITICAL, c.HIGH, c.MEDIUM, c.LOW + c.UNKNOWN, isGo ? stdlib : '-']);
  }
  for (const [src, n] of scanned) if (!seenSrc.has(src)) rows.push([src, n, 0, 0, 0, 0, src.endsWith('go.mod') ? 0 : '-']);
  rows.sort((a, b) => a[0].localeCompare(b[0]));
  table(['lockfile', 'packages', 'crit', 'high', 'med', 'low/unk', 'stdlib*'], rows);
  say('* stdlib from go.mod is counted against the "go" directive, not the image toolchain; govulncheck is the Go reference.');
  if (details.length) { say(); say('-- osv HIGH/CRITICAL --'); details.forEach((d) => say(d)); }
  say();
}

function trivySection(dir, title, own) {
  const files = list(dir, '.json');
  if (!files.length) return;
  const current = new Set(own ? lines(path.join(OUT, dir, 'current.txt')) : []);
  const labels = new Map(lines(path.join(OUT, dir, 'images.txt')).map((l) => [l.includes('@') ? `${l.split(':')[0]}@${l.split('@')[1]}` : l, l.split('@')[0]]));
  const rows = [];
  const agg = new Map();
  const old = { CRITICAL: 0, HIGH: 0, fixable: 0, images: 0 };
  for (const f of files) {
    const j = readJson(path.join(OUT, dir, f));
    if (!j) { rows.push([f, 'ERR', '', '', '', '', '']); continue; }
    const name = labels.get(j.ArtifactName) || j.ArtifactName || f;
    const isCurrent = !own || current.has(name);
    const seen = new Set();
    const c = { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0, UNKNOWN: 0 };
    let fixedCH = 0;
    for (const res of j.Results || []) {
      for (const v of res.Vulnerabilities || []) {
        const k = `${v.VulnerabilityID}|${v.PkgName}|${v.InstalledVersion}`;
        if (seen.has(k)) continue;
        seen.add(k);
        const sev = SEV.includes(v.Severity) ? v.Severity : 'UNKNOWN';
        c[sev]++;
        if (sev !== 'CRITICAL' && sev !== 'HIGH') continue;
        if (v.FixedVersion) fixedCH++;
        if (!isCurrent) continue;
        if (!own && sev !== 'CRITICAL') continue;
        if (!agg.has(k)) agg.set(k, { v, sev, cls: `${res.Class}/${res.Type}`, images: [] });
        agg.get(k).images.push(name);
        if (own && v.FixedVersion) blocking.push(`trivy ${name}: ${v.VulnerabilityID} ${v.PkgName}@${v.InstalledVersion} ${sev}`);
      }
    }
    if (!isCurrent) { old.CRITICAL += c.CRITICAL; old.HIGH += c.HIGH; old.fixable += fixedCH; old.images++; }
    const os = j.Metadata?.OS ? `${j.Metadata.OS.Family} ${j.Metadata.OS.Name}` : '-';
    rows.push([(own ? (isCurrent ? '* ' : '  ') : '') + name, c.CRITICAL, c.HIGH, c.MEDIUM, c.LOW + c.UNKNOWN, fixedCH, os]);
  }
  say(`== ${title} ==`);
  table(['image', 'crit', 'high', 'med', 'low/unk', 'C+H fixable', 'os'], rows);
  if (own) say('* = referenced by docker/compose*.yml / stack (images in use); others are old/unused tags on the local machine, not detailed.');
  if (own && old.images) say(`  old tags (${old.images} images): ${old.CRITICAL} critical, ${old.HIGH} high, ${old.fixable} fixable -> just remove old images (docker image rm).`);
  if (agg.size) {
    say();
    say(own ? `-- ${title}: HIGH/CRITICAL in images in use --` : `-- ${title}: CRITICAL only (for HIGH see ${dir}/*.txt) --`);
    const sorted = [...agg.values()].sort((a, b) => SEV.indexOf(a.sev) - SEV.indexOf(b.sev) || a.v.VulnerabilityID.localeCompare(b.v.VulnerabilityID));
    for (const a of sorted) say(`${a.sev} ${a.v.VulnerabilityID} ${a.v.PkgName}@${a.v.InstalledVersion} -> fixed ${a.v.FixedVersion || 'none'} (${a.v.Status || '-'}) [${a.cls}] ${a.images.join(', ')}`);
  }
  say();
}

if (sections.has('go')) goSection();
if (sections.has('npm')) npmSection();
if (sections.has('osv')) osvSection();
if (sections.has('trivy')) trivySection('trivy', 'Trivy own images (olt-social/*)', true);
if (sections.has('third-party')) trivySection('third-party', 'Trivy third-party images (docker/compose.yml, outside --strict)', false);
say('== --strict blockers (Go called, npm prod HIGH/CRIT, Trivy images in use HIGH/CRIT fixable, osv pubspec.lock HIGH/CRIT fixable) ==');
say(blocking.length ? `${blocking.length} findings` : 'none');
blocking.forEach((b) => say('  ' + b));
process.stdout.write(out.join('\n') + '\n');
process.exitCode = strict && blocking.length ? 3 : 0;
JS
}

if [ -z "$summary_only" ]; then
  want go && scan_go
  want npm && scan_npm
  want osv && scan_osv
  if want trivy || want third-party; then
    if trivy_db; then
      want trivy && scan_trivy
      want third-party && scan_third_party
    fi
  fi
fi

echo
docker run --rm -i "${SRC_RO[@]}" --mount "type=bind,source=$OUT,target=/out,readonly" \
  -e STRICT="$strict" -e SECTIONS="$sections" "$NODE_IMG" node - < <(summarizer) | tee "$OUT_REL/summary.txt"
sum_rc=${PIPESTATUS[0]}

echo
echo "Raw results: $OUT_REL"
if [ "$errors" -gt 0 ]; then
  echo "$errors tools failed to run (see $OUT_REL/errors.txt)" >&2
  exit 2
fi
if [ "$sum_rc" -eq 3 ]; then
  exit 1
fi
[ "$sum_rc" -eq 0 ] || { echo "Failed to build summary" >&2; exit 2; }
exit 0
