#!/usr/bin/env bash
#
# dev-diary — plugin-specific cheap checks.
#
# SOURCED by the shared runner (evals/cheap/run.sh), not run standalone: it
# inherits that runner's helpers (ok/bad/group), its `set -uo pipefail`, a
# working directory of the repo root, and the exported PLUGIN_NAME / PLUGIN_DIR.
#
# Nothing here is destructive — this plugin writes local journal entries. What
# the cheap tier defends is the plugin's *editorial* contract: a handful of
# load-bearing instructions in the two SKILL.md files that keep entries honest
# and safe. Each is a single grep away from being silently deleted while the
# file still parses and reads fine, so these make that kind of quiet regression
# a red build.

WRITE="$PLUGIN_DIR/skills/dev-diary/SKILL.md"
REVIEW="$PLUGIN_DIR/skills/dev-diary-review/SKILL.md"
GUIDE="$PLUGIN_DIR/skills/dev-diary/references/format-guide.md"
DISCOVER="$PLUGIN_DIR/skills/dev-diary/scripts/discover-today.sh"

# --- structure: the plugin's advertised surface actually exists ------------
group "dev-diary — structure"
for f in \
  "$PLUGIN_DIR/.claude-plugin/plugin.json" \
  "$WRITE" \
  "$REVIEW" \
  "$GUIDE" \
  "$DISCOVER" \
  "$PLUGIN_DIR/skills/dev-diary/templates/entry.md" \
  "$PLUGIN_DIR/commands/dev-diary.md" \
  "$PLUGIN_DIR/commands/dev-diary-review.md"; do
  if [ -f "$f" ]; then ok "present: $f"; else bad "MISSING: $f"; fi
done

# --- safety invariant: never commit a secret -------------------------------
# The single most important rule. Prompt history and transcripts are full of
# pasted tokens/keys; entries redact by rule. If the redaction instruction is
# deleted from a skill, the tool will happily copy a secret into a public repo.
group "dev-diary — redaction invariant"
for f in "$WRITE" "$REVIEW" "$GUIDE"; do
  if grep -qiE 'redact|never .*secret|never introduce a token' "$f"; then
    ok "redaction rule present: $(basename "$(dirname "$f")")/$(basename "$f")"
  else
    bad "redaction rule GONE from $f — entries could leak pasted tokens/keys"
  fi
done

# --- editorial invariant: interview, don't just transcribe -----------------
# The value is judgment, not stenography. The write loop must keep the interview
# step; without it the skill degrades to the low-signal auto-summary it exists
# to avoid.
group "dev-diary — interview invariant"
if grep -qiE 'interview' "$WRITE"; then
  ok "write loop keeps the interview step"
else
  bad "write loop dropped the interview — degrades to an unreviewed auto-summary"
fi

# --- tool/journal split: entries live in the separate private repo ---------
# This plugin is shareable; the journal is not. Both skills must target the
# journal repo by its absolute path, never write entries into this marketplace.
group "dev-diary — tool/journal split"
for f in "$WRITE" "$REVIEW"; do
  if grep -q '~/projects/dev-diary' "$f"; then
    ok "journal root pinned in $(basename "$(dirname "$f")")/SKILL.md"
  else
    bad "journal root path missing from $f — tool/journal split broken"
  fi
done

# --- review invariant: backfilled != reviewed ------------------------------
# The review skill's whole reason to touch the marker is to keep it meaningful:
# a reconstructed day stays flagged until a human actually vets it, and the
# marker is cleared only then — never bulk-cleared.
group "dev-diary-review — backfilled-marker discipline"
if grep -q 'backfilled: true' "$REVIEW" && grep -qiE 'remove the|clear' "$REVIEW"; then
  ok "review skill keeps clear-only-once-vetted marker discipline"
else
  bad "review skill lost the backfilled-marker discipline — markers become meaningless"
fi

# --- discovery script: local-time windows ----------------------------------
# The digest's "today" must be the user's local day, not UTC, or late-evening
# work lands on the wrong date. The script converts transcript UTC to local.
group "dev-diary — discovery is local-time"
if grep -qiE 'local' "$DISCOVER" && grep -q 'date -d' "$DISCOVER"; then
  ok "discover-today.sh computes windows in local time"
else
  bad "discover-today.sh no longer anchors windows to local time"
fi
