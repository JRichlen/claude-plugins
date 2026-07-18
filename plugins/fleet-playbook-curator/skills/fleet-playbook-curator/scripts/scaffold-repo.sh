#!/usr/bin/env bash
# Materialize the per-fleet playbook repo's files into a target directory.
# DETERMINISTIC + IDEMPOTENT: identical inputs produce byte-identical scaffolding,
# and re-running NEVER clobbers curator-owned prose (the playbook body / CHANGELOG
# once they exist). No LLM. The deploy COMMAND is what carries the human
# confirm/dry-run gate and the actual `gh repo create` + commit; this script only
# writes files so it can be reviewed and re-run safely.
#
# Usage: scaffold-repo.sh <fleet-name> <owner> <glob> <target-dir> [--plan]
#   --plan  print what WOULD be written and exit 0 without touching anything.
set -euo pipefail

name="${1:?usage: scaffold-repo.sh <fleet-name> <owner> <glob> <target-dir> [--plan]}"
owner="${2:?owner required}"
glob="${3:?glob required}"
target="${4:?target-dir required}"
plan=0; [ "${5:-}" = "--plan" ] && plan=1

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # the skill dir
tpl="$here/templates"

# curator-owned = written once, never overwritten on re-run.
curator_owned() { case "$1" in fleet-playbook/SKILL.md|fleet-playbook/CHANGELOG.md) return 0;; *) return 1;; esac; }

emit() {  # emit <rel-path> <source-file-or-"MANIFEST">
  local rel="$1" src="$2" dst="$target/$1"
  if curator_owned "$rel" && [ -e "$dst" ]; then
    echo "keep   $rel (curator-owned, exists)"; return
  fi
  if [ "$plan" = 1 ]; then echo "write  $rel"; return; fi
  mkdir -p "$(dirname "$dst")"
  if [ "$src" = "MANIFEST" ]; then
    # An EMPTY facts manifest; the detector fills it on first run.
    printf '{"as_of":null,"members":[]}\n' > "$dst"
  else
    # Substitute the three deterministic tokens (no {{ }} — that style is banned
    # in the marketplace's own tree; the placeholders below are plain literals).
    sed -e "s|__FLEET_NAME__|$name|g" -e "s|__OWNER__|$owner|g" -e "s|__GLOB__|$glob|g" "$src" > "$dst"
  fi
  echo "write  $rel"
}

copy_verbatim() {  # copy_verbatim <rel-path> <source-file>  — no token substitution
  local rel="$1" src="$2" dst="$target/$1"
  if [ "$plan" = 1 ]; then echo "vendor $rel"; return; fi
  mkdir -p "$(dirname "$dst")"; cp "$src" "$dst"; chmod +x "$dst" 2>/dev/null || true
  echo "vendor $rel"
}

echo "# fleet '$name'  owner=$owner  glob=$glob  ->  $target  ${plan:+(plan)}"
emit ".github/workflows/fleet-sync.yml" "$tpl/fleet-sync.yml"
emit "fleet.yaml"                        "$tpl/fleet.example.yaml"
emit "fleet-manifest.json"               "MANIFEST"
emit "fleet-playbook/SKILL.md"           "$tpl/fleet-playbook/SKILL.md"
emit "fleet-playbook/index.json"         "$tpl/fleet-playbook/index.seed.json"
emit "fleet-playbook/index.schema.json"  "$tpl/fleet-playbook/index.schema.json"
emit "fleet-playbook/CHANGELOG.md"       "$tpl/fleet-playbook/CHANGELOG.md"
# Vendor the deterministic runtime the workflow calls (verbatim, no substitution).
copy_verbatim "scripts/list-fleet-members.sh" "$here/scripts/list-fleet-members.sh"
copy_verbatim "scripts/diff-fleet.sh"         "$here/scripts/diff-fleet.sh"
copy_verbatim "scripts/gather-context.sh"     "$here/scripts/gather-context.sh"
copy_verbatim "scripts/validate-citations.sh" "$here/scripts/validate-citations.sh"
copy_verbatim "PROMPT.md"                     "$here/PROMPT.md"
[ "$plan" = 1 ] && echo "# plan only — nothing written"
exit 0
