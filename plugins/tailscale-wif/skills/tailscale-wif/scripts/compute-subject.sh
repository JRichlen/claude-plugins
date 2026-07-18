#!/usr/bin/env bash
#
# compute-subject.sh — print the ID-embedded GitHub OIDC subject to paste into a
# Tailscale Trust Credential's Subject field.
#
# Many orgs/enterprises harden their OIDC config so the `sub` claim embeds the
# numeric org/repo database IDs:
#
#     repo:ORG@<orgId>/REPO@<repoId>:pull_request
#
# A name-only match (repo:ORG/REPO:...) then silently 403s. The ID-embedded form
# is also rename-proof, so it's the right match either way. This script fetches
# the two IDs via `gh api` and assembles the subject with a trailing :* so ONE
# credential matches both pull_request and ref:refs/heads/main.
#
# Usage:
#   compute-subject.sh OWNER/REPO
#   compute-subject.sh OWNER REPO
#
# Requires: gh (authenticated), jq.
# Exit 0 on success; nonzero with a message on stderr on any failure.
set -euo pipefail

die() { echo "compute-subject: $*" >&2; exit 1; }

command -v gh >/dev/null 2>&1 || die "the GitHub CLI 'gh' is required and must be authenticated (gh auth login)"
command -v jq >/dev/null 2>&1 || die "'jq' is required"

case "$#" in
  1) case "$1" in
       */*) OWNER="${1%%/*}"; REPO="${1##*/}" ;;
       *)   die "usage: compute-subject.sh OWNER/REPO  (or  OWNER REPO)" ;;
     esac ;;
  2) OWNER="$1"; REPO="$2" ;;
  *) die "usage: compute-subject.sh OWNER/REPO  (or  OWNER REPO)" ;;
esac

[ -n "$OWNER" ] && [ -n "$REPO" ] || die "usage: compute-subject.sh OWNER/REPO  (or  OWNER REPO)"

# .id = repo database ID (@<repoId>); .owner.id = org/owner database ID (@<orgId>).
ids="$(gh api "repos/$OWNER/$REPO" --jq '{id, owner_id: .owner.id}')" \
  || die "gh api repos/$OWNER/$REPO failed — check the name and that gh is authenticated"

REPO_ID="$(printf '%s' "$ids" | jq -r '.id')"
OWNER_ID="$(printf '%s' "$ids" | jq -r '.owner_id')"

[ "$REPO_ID" != "null" ] && [ -n "$REPO_ID" ]   || die "could not read repo id from gh api response"
[ "$OWNER_ID" != "null" ] && [ -n "$OWNER_ID" ] || die "could not read owner id from gh api response"

# ID-embedded subject, trailing :* to match both pull_request and refs/heads/main.
SUBJECT="repo:${OWNER}@${OWNER_ID}/${REPO}@${REPO_ID}:*"

echo "$SUBJECT"
echo "" >&2
echo "Paste the line above into the Trust Credential's Subject field." >&2
echo "(name-only equivalent for reference: repo:${OWNER}/${REPO}:* )" >&2
