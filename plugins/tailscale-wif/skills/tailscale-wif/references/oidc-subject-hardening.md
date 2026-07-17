# OIDC subject hardening — the silent 403

This is the single most common reason a correctly-wired Tailscale WIF setup still
returns `token exchange failed with status 403: Unauthorized`.

## What GitHub puts in `sub`

Every GitHub Actions OIDC token carries a `sub` (subject) claim identifying the
workload. The common, documented shape is **name-only**:

```
repo:ORG/REPO:pull_request
repo:ORG/REPO:ref:refs/heads/main
```

But GitHub lets an org/enterprise **customize** (harden) the subject claim
template. A frequent hardening embeds the numeric **database IDs** of the org and
repo so the identity can't be spoofed by re-creating a repo with the same name:

```
repo:ORG@306084426/REPO@1304364146:pull_request
```

Here `306084426` is the org/owner database ID and `1304364146` is the repo
database ID. Your org may or may not do this — you often can't tell by looking at
the workflow.

## Why it 403s silently

Tailscale's Trust Credential does an **exact** subject match. If you configured
the name-only `repo:ORG/REPO:*` but GitHub is actually signing
`repo:ORG@306084426/REPO@1304364146:pull_request`, the strings never match, so
the exchange is rejected. The error is a generic `403: Unauthorized` — it does
**not** tell you the subject was the problem. That's what makes it a time sink.

## The fix

Match the **ID-embedded** form, with a trailing `:*` so one credential covers
both `pull_request` and `refs/heads/main`:

```
repo:ORG@<orgId>/REPO@<repoId>:*
```

Get the two IDs:

```sh
gh api repos/OWNER/REPO --jq '{id, owner_id: .owner.id}'
# .id       -> the repo ID   -> @<repoId>
# .owner.id -> the owner ID  -> @<orgId>
```

or let the helper assemble the whole subject for you:

```sh
scripts/compute-subject.sh OWNER/REPO
```

Use the ID-embedded form **even if the name-only form currently works** — it is
rename-proof (renaming the org or repo doesn't change the numeric IDs, so the
credential keeps matching).

## Confirm before you guess — decode the real `sub`

Don't assume which form your org uses. Mint a token in CI and decode it (see
`templates/debug-oidc-sub.yml`). The `sub` it prints is exactly what the Trust
Credential must match. Set the Subject to that (swapping the event suffix for
`:*`), then remove the debug step.
