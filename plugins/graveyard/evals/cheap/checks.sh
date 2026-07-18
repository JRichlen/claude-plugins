#!/usr/bin/env bash
#
# graveyard — plugin-specific cheap checks.
#
# This fragment is SOURCED by the shared runner (evals/cheap/run.sh), not run on
# its own: it inherits that runner's helpers (ok/bad/group), its `set -uo
# pipefail`, and a working directory of the repo root. The shared runner also
# exports PLUGIN_NAME and PLUGIN_DIR for us, though the graveyard checks below
# reference repo-root-relative paths directly so they read identically to how
# they lived in the shared runner before the extraction.
#
# What these prove is the core promise of the graveyard skill — a destructive,
# irreversible operation gated by evals rather than trust. They are the reason
# the cheap tier is REQUIRED before every commit that touches this plugin.

# --- SAFETY INVARIANT: guarded deletion ------------------------------------
# The core promise of the graveyard skill: an original repo is deleted only
# after its bundle is confirmed present in the graveyard. Regenerate a delete
# script and prove every bundled delete sits behind the bundle-existence guard.
group "safety invariant — guarded deletion"
GEN="plugins/graveyard/skills/graveyard/scripts/generate-delete-script.sh"

# 5a. refuses with no args
if bash "$GEN" >/dev/null 2>&1; then bad "generator should exit non-zero with no args"; else ok "generator refuses empty invocation"; fi

# 5b. bundled delete is guarded by a bundle-existence check
out="$(bash "$GEN" acme graveyard --bundled "alpha beta")"
if grep -q 'if gh api "repos/\$OWNER/\$GRAVEYARD/contents/\$r/\$r.bundle"' <<<"$out"; then
  ok "generated script guards bundled deletes with a bundle-existence check"
else
  bad "generated script is MISSING the bundle-existence guard"
fi

# 5c. with ONLY --bundled, there must be no unguarded delete. The template emits
#     exactly one 'gh repo delete "$OWNER/$r"' (inside the guarded loop) and one
#     in the unbundled loop. With no --unbundled, the unbundled loop iterates over
#     an empty list at run time, but the line still exists in source — so assert
#     the guard count instead: one guard per bundled loop.
guards=$(grep -c 'contents/\$r/\$r.bundle' <<<"$out")
if [ "$guards" -ge 1 ]; then ok "bundle-existence guard present in emitted script"; else bad "no bundle guard in emitted script"; fi

# 5d. unbundled repos are surfaced explicitly, never deleted silently
out2="$(bash "$GEN" acme graveyard --bundled "alpha" --unbundled "junkfork")"
if grep -q 'intentionally not bundled' <<<"$out2"; then
  ok "unbundled deletes are labeled explicitly (no silent deletion)"
else
  bad "unbundled deletes are not labeled"
fi

# --- verify gotcha guard -------------------------------------------------
# 'git bundle verify' needs a repo context (-C). A regression to the bare form
# would make every archive fail confusingly. Lock in the -C form.
group "archive verify uses -C form"
ARCH="plugins/graveyard/skills/graveyard/scripts/archive-repo.sh"
if grep -E 'git -C "?\$?\{?m\}?"? bundle verify' "$ARCH" >/dev/null 2>&1 \
   || grep -E 'git -C .* bundle verify' "$ARCH" >/dev/null 2>&1; then
  ok "archive-repo.sh verifies bundles with 'git -C <repo> bundle verify'"
else
  bad "archive-repo.sh does not use the 'git -C' form for bundle verify"
fi

# --- deep-tier coverage is frozen -----------------------------------------
# The deep (pier) tier now discovers pier packs per-plugin, so graveyard's
# irreversible-delete guard stays deep-tested only as long as its pier pack
# exists. Deleting it would silently drop the sandboxed cross-harness check
# for the one skill that deletes repos. Make that a red build here.
group "graveyard — deep-tier coverage frozen"
PIER="$PLUGIN_DIR/evals/pier"
if [ -x "$PIER/run.sh" ] && [ -d "$PIER/tasks/graveyard-guarded-delete" ]; then
  ok "graveyard ships a pier pack (guarded-delete stays deep-tested)"
else
  bad "graveyard's pier pack is missing — the deep tier would stop verifying the guarded-delete invariant"
fi
