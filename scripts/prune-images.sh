#!/usr/bin/env bash
# Removes old versions of this stack's images: olt-social/* tags and upstream images of repos used in
# docker/*.yml that no compose file, Makefile, make.ps1 or Dockerfile refers to any more, plus untagged
# build leftovers. Images used by a container are kept (docker rmi refuses them). Build cache unused for
# 7 days is pruned. DRY_RUN=1 only prints what would be removed.
set -uo pipefail
cd "$(dirname "$0")/.."

pattern='[a-z0-9][a-z0-9._/-]*:[A-Za-z0-9._-]+(@sha256:[0-9a-f]{64})?'
sources=(docker/*.yml make.ps1 Makefile)
while IFS= read -r f; do sources+=("$f"); done < <(find services docker -name 'Dockerfile*' -type f)
[[ -n "${HUB_DIR:-}" && -f "$HUB_DIR/Dockerfile" ]] && sources+=("$HUB_DIR/Dockerfile")

declare -A tags digests repos digest_repos
while IFS= read -r ref; do
  base="${ref%@sha256:*}"
  repo="${base%:*}"
  tags["$base"]=1
  if [[ "$ref" == *@sha256:* ]]; then
    digests["$repo@${ref#*@}"]=1
    digest_repos["$repo"]=1
  fi
done < <(cat "${sources[@]}" 2>/dev/null | grep -oE "$pattern" | sort -u)
while IFS= read -r ref; do
  base="${ref%@sha256:*}"
  repos["${base%:*}"]=1
done < <(cat docker/*.yml | grep -oE "$pattern" | sort -u)

removed=0
while IFS='|' read -r repo tag digest id; do
  ours=0
  [[ "$repo" == olt-social/* || -n "${repos[$repo]:-}" ]] && ours=1
  [[ "$repo" != "<none>" && $ours -eq 0 ]] && continue
  [[ "$tag" != "<none>" && -n "${tags[$repo:$tag]:-}" ]] && continue
  [[ "$digest" != "<none>" && -n "${digests[$repo@$digest]:-}" ]] && continue
  if [[ "$tag" == "<none>" && "$digest" != "<none>" && "$repo" != olt-social/* && -z "${digest_repos[$repo]:-}" ]]; then
    continue
  fi
  if [[ "$tag" != "<none>" ]]; then ref="$repo:$tag"
  elif [[ "$digest" != "<none>" && "$repo" != "<none>" ]]; then ref="$repo@$digest"
  else ref="$id"; fi
  if [[ -n "${DRY_RUN:-}" ]]; then echo "would remove $ref"; continue; fi
  docker rmi "$ref" >/dev/null 2>&1 && removed=$((removed + 1))
done < <(docker image ls --digests --format '{{.Repository}}|{{.Tag}}|{{.Digest}}|{{.ID}}')

[[ -n "${DRY_RUN:-}" ]] && exit 0
docker builder prune -f --filter until=168h >/dev/null 2>&1 || true
echo "Image prune: removed $removed old image reference(s); build cache older than 7 days pruned"
