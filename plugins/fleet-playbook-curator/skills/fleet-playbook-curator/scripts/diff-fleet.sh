#!/usr/bin/env bash
# Pure, DETERMINISTIC diff of two fleet manifests. No network, no LLM, no clock.
# Identical inputs -> byte-identical output (this is what the cheap eval asserts).
#
# Usage: diff-fleet.sh <old-manifest.json> <new-manifest.json>
# Emits (stdout) diff.json:
#   { changed: bool, added: [...], removed: [...], renamed: [...], updated: [...] }
# Joined on node_id so a rename is a rename, never a simultaneous remove+add.
# Membership events (added/removed/renamed) are first-class — they matter more
# than content drift and are what most needs a changelog entry.
set -euo pipefail

old="${1:?usage: diff-fleet.sh <old-manifest> <new-manifest>}"
new="${2:?usage: diff-fleet.sh <old-manifest> <new-manifest>}"
[ -f "$old" ] || { echo "diff-fleet: no such file: $old" >&2; exit 2; }
[ -f "$new" ] || { echo "diff-fleet: no such file: $new" >&2; exit 2; }

jq -n --slurpfile o "$old" --slurpfile n "$new" '
  ( ($o[0].members // []) | map({ (.node_id): . }) | add // {} ) as $oi
  | ( ($n[0].members // []) | map({ (.node_id): . }) | add // {} ) as $ni
  | ( $oi | keys ) as $ok
  | ( $ni | keys ) as $nk
  | {
      added:   ( ($nk - $ok) | sort | map($ni[.]) ),
      removed: ( ($ok - $nk) | sort | map($oi[.]) ),
      renamed: ( $nk | sort | map( select($oi[.] != null and $oi[.].full_name != $ni[.].full_name)
                   | { node_id: ., from: $oi[.].full_name, to: $ni[.].full_name } ) ),
      updated: ( $nk | sort | map( select($oi[.] != null and $oi[.].head_sha != $ni[.].head_sha
                   and $oi[.].full_name == $ni[.].full_name)
                   | { node_id: ., full_name: $ni[.].full_name, from: $oi[.].head_sha, to: $ni[.].head_sha } ) )
    }
  | . + { changed: ( ((.added|length)+(.removed|length)+(.renamed|length)+(.updated|length)) > 0 ) }
'
