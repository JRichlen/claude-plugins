#!/usr/bin/env bash
#
# archive-repo.sh — capture one GitHub repo as a restorable git bundle.
#
# Mirror-clones a repo (fetching ALL refs, including branches, tags, and
# GitHub's refs/pull/*), packs the full history into a single .bundle file,
# verifies the bundle, and writes metadata.json + a per-repo README.md with
# restore instructions.
#
# Usage:
#   archive-repo.sh <owner/repo> <dest-dir> [mirror-cache-dir]
#
# Example:
#   archive-repo.sh octocat/hello-world ./graveyard
#
# Output layout (under <dest-dir>):
#   <repo>/<repo>.bundle   full git bundle (all refs)
#   <repo>/metadata.json   gh repo view JSON snapshot
#   <repo>/README.md       human-readable card + restore commands
#
# Exit codes: 0 ok, 2 usage, 3 clone failed, 4 bundle verify failed.
#
# Requires: git, gh (authenticated). Portable bash — no bashisms beyond 3.2.
set -uo pipefail

die() { echo "error: $*" >&2; exit "${2:-1}"; }

[ $# -ge 2 ] || die "usage: archive-repo.sh <owner/repo> <dest-dir> [mirror-cache-dir]" 2

SLUG="$1"                       # owner/repo
DEST="$2"
OWNER="${SLUG%%/*}"
REPO="${SLUG##*/}"
[ "$OWNER" != "$SLUG" ] || die "first arg must be owner/repo, got: $SLUG" 2

MIRR_ROOT="${3:-$(mktemp -d "${TMPDIR:-/tmp}/graveyard-mirror.XXXXXX")}"
mkdir -p "$MIRR_ROOT"
m="$MIRR_ROOT/$REPO.git"
dir="$DEST/$REPO"
mkdir -p "$dir"

echo "==> $SLUG"

# Mirror clone gets every ref, not just the checked-out branch. Prefer SSH,
# fall back to HTTPS so this works whether or not SSH keys are configured.
rm -rf "$m"
if ! git clone --quiet --mirror "git@github.com:$SLUG.git" "$m" 2>/dev/null; then
  if ! git clone --quiet --mirror "https://github.com/$SLUG.git" "$m" 2>/dev/null; then
    die "clone failed for $SLUG (empty repo? no access?)" 3
  fi
fi

commits=$(git -C "$m" rev-list --all --count 2>/dev/null || echo 0)

# The bundle is the actual backup. --all captures every ref the mirror holds.
git -C "$m" bundle create "$dir/$REPO.bundle" --all >/dev/null 2>&1 \
  || die "bundle create failed for $SLUG" 4

# IMPORTANT: `git bundle verify` needs a repository context. Run it with -C
# pointed at the mirror, not as a bare `git bundle verify <file>` (which fails
# with "need a repository to verify a bundle").
git -C "$m" bundle verify "$dir/$REPO.bundle" >/dev/null 2>&1 \
  || die "bundle verify failed for $SLUG" 4

bsize=$(du -h "$dir/$REPO.bundle" | cut -f1 | tr -d ' ')
defbr=$(git -C "$m" symbolic-ref --short HEAD 2>/dev/null || echo main)
# Join ref names with ", ". Note: `paste -sd', '` is WRONG here — it treats
# ',' and ' ' as alternating delimiters. Join on ',' then space it out.
branches=$(git -C "$m" for-each-ref --format='%(refname:short)' refs/heads | paste -sd, - | sed 's/,/, /g')
tags=$(git -C "$m" for-each-ref --format='%(refname:short)' refs/tags | paste -sd, - | sed 's/,/, /g')
lastcommit=$(git -C "$m" log -1 --format='%h %ci %s' --all 2>/dev/null)

# Best-effort metadata snapshot from the GitHub API. Never fatal — a repo can
# be archived even if `gh` is unavailable or the API call fails.
gh repo view "$SLUG" \
  --json name,nameWithOwner,description,visibility,isFork,isArchived,createdAt,pushedAt,updatedAt,defaultBranchRef,url,primaryLanguage,repositoryTopics,diskUsage \
  > "$dir/metadata.json" 2>/dev/null \
  || echo '{}' > "$dir/metadata.json"
desc=$(gh repo view "$SLUG" --json description --jq '.description // ""' 2>/dev/null || echo "")

{
  echo "# $REPO (archived)"
  echo
  [ -n "$desc" ] && { echo "> $desc"; echo; }
  echo "Retired from \`$SLUG\` and stored here as a full git bundle."
  echo
  echo "| | |"
  echo "|---|---|"
  echo "| Source | \`$SLUG\` |"
  echo "| Commits | $commits |"
  echo "| Default branch | \`$defbr\` |"
  echo "| Branches | ${branches:-none} |"
  echo "| Tags | ${tags:-none} |"
  echo "| Bundle size | $bsize |"
  echo "| Last commit | ${lastcommit:-unknown} |"
  echo
  echo "## Restore"
  echo
  echo '```sh'
  echo "# Clone the whole thing back into a working repo:"
  echo "git clone $REPO.bundle $REPO"
  echo
  echo "# Or verify + fetch every ref (branches, tags, pull refs) into an existing repo:"
  echo "git bundle verify $REPO.bundle"
  echo "git fetch $REPO.bundle '*:refs/bundle/*'"
  echo '```'
  echo
  echo "Original GitHub metadata is in \`metadata.json\`."
} > "$dir/README.md"

echo "    ok  commits=$commits  bundle=$bsize  branches=[${branches:-none}]  tags=[${tags:-none}]"
# Machine-readable line for the caller (the skill parses this).
echo "RESULT	$REPO	OK	commits=$commits	size=$bsize	path=$dir/$REPO.bundle"
