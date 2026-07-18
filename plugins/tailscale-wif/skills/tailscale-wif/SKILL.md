---
name: tailscale-wif
description: >-
  Set up and troubleshoot SECRETLESS GitHub Actions -> Tailscale authentication
  using Workload Identity Federation (WIF): each run mints a GitHub OIDC token
  that a Tailscale "Trust Credential" exchanges for a short-lived API token or
  ephemeral auth key, so no Tailscale API key or OAuth client secret is ever
  stored. Use this WHENEVER a GitHub Actions workflow needs to talk to Tailscale
  — pushing an ACL/policy file with tailscale/gitops-acl-action, or joining a CI
  runner to the tailnet with tailscale/github-action — and you want to drop the
  stored credential, OR when such a workflow is failing with "token exchange
  failed with status 403: Unauthorized", "requested tags are invalid or not
  permitted", or "only one of API Key, OAuth secret, or OAuth client ID and
  audience". Reach for it on phrases like "Tailscale OIDC", "Tailscale WIF",
  "federated identity Tailscale", "secretless Tailscale in CI", "remove the
  Tailscale API key / OAuth secret from Actions", or "Tailscale Trust Credential".
license: MIT
compatibility: >-
  Everything here is plain GitHub Actions YAML plus `gh`/`curl`/`jq` — it is
  fully harness-agnostic. The bundled command entry point and the optional
  Claude Code agent under agents/ are conveniences; on any other harness, read
  this SKILL.md and run the same steps and scripts directly. PORTABILITY: the
  setup/troubleshoot procedure ports to any harness — only the invocation wrapper
  is Claude-specific.
---

# Tailscale Workload Identity Federation (WIF) for GitHub Actions

## Invariant

WIF auth is **secretless**. Only the **public** `oauth-client-id` and `audience`
are stored — and they belong in repo **variables**, never secrets. The job that
authenticates to Tailscale always carries `permissions: id-token: write`, and it
passes **exactly one** auth mode. No long-lived Tailscale credential (a REST API
key, an OAuth client secret) is ever stored to enable a run: each run mints a
fresh GitHub OIDC token, and a Tailscale Trust Credential exchanges it for a
short-lived (~1h) API token or an ephemeral auth key that expires on its own.

If a change would put a Tailscale secret back into the workflow, drop
`id-token: write`, or pass two auth modes at once, it breaks this plugin's whole
reason to exist. The cheap eval (`evals/cheap/checks.sh`) defends the marker
facts below.

## Why WIF

Stored Tailscale credentials are the thing you are removing:

- **REST API keys** expire in **90 days or less** — someone has to rotate them,
  and a leaked key is valid until it expires.
- **OAuth client secrets** are long-lived bearer secrets — a leak is worse.

WIF (a GA Tailscale feature) replaces both. Trust flows the other way: instead of
handing Tailscale a stored secret, each workflow run proves its identity with a
GitHub-signed **OIDC token**, and Tailscale's **Trust Credential** (configured in
the admin console) decides whether to trust that identity and, if so, mints a
short-lived token. Because the `client-id` and `audience` are just **public
identifiers** (not secrets), they go in repo **variables** — nothing sensitive is
stored anywhere.

## The two use cases

Pick the one that matches what the workflow does with Tailscale.

### 1. ACL / policy GitOps — `tailscale/gitops-acl-action`

Push your tailnet policy file from CI. Pin the action to a **SHA** (not a moving
tag). The Trust Credential's **scope is `policy_file`**. The action fetches the
GitHub OIDC token itself, so you only give it the client-id and audience.

Template: `skills/tailscale-wif/templates/acl-gitops.yml`

Key change from the old secret-based setup: **remove `api-key`**, add
`oauth-client-id` + `audience`.

### 2. Node join (a CI runner joins the tailnet) — `tailscale/github-action`

A runner brings up `tailscaled` and joins your tailnet for the duration of the
job. Requires **`tailscale/github-action` v4.1.3+** for federated identity, and
**`tailscaled` >= 1.90.1** for WIF — set `version: latest` so the installed
daemon is new enough. The Trust Credential's **scope is `auth_keys`**, and it
must be allowed to **assign the tag(s)** the runner needs (e.g. `tag:ci`).

Template: `skills/tailscale-wif/templates/node-join.yml`

Key change from the old setup: **remove `oauth-secret`**, add `oauth-client-id` +
`audience` + `tags` + `version: latest`. The tag you pass (e.g. `tag:ci`) must
**also exist in the tailnet policy `tagOwners`**.

## Workflow requirements (both use cases)

1. **`permissions: id-token: write`** on the job (plus `contents: read` for
   `actions/checkout`). Without `id-token: write` the runner cannot mint the
   GitHub OIDC token, so the exchange fails before it starts.
2. **Exactly one auth mode.** `api-key` **XOR** `oauth-secret` **XOR**
   (`oauth-client-id` **+** `audience`). Passing more than one makes the action
   error: *"only one of API Key, OAuth secret, or OAuth client ID and audience"*.
3. Store `oauth-client-id` and `audience` as **repo variables** (e.g.
   `vars.TS_OIDC_CLIENT_ID`, `vars.TS_OIDC_AUDIENCE`). They are public — do not
   waste secrets on them, and do not put a Tailscale secret next to them.

## Trust Credential setup (Tailscale admin console)

Admin console -> **Trust credentials** -> **Credential** -> **OpenID Connect**.
Full annotated walkthrough:
`skills/tailscale-wif/references/trust-credential-console-setup.md`.

Fields:

- **Issuer** — choose **"GitHub Actions"**; the console fills in
  `token.actions.githubusercontent.com`.
- **Subject** — the GitHub OIDC `sub` claim, with a trailing **`:*`** so one
  credential matches **both** `pull_request` (the test/plan runs) **and**
  `ref:refs/heads/main` (the merge/apply run). See the subject-hardening section
  below — for many orgs the correct value is the **ID-embedded** form.
- **Custom claims** — leave empty unless you are deliberately narrowing further.
- **Scope** — **`policy_file`** (ACL GitOps) or **`auth_keys`** (node join). For
  `auth_keys`, also assign the **Tag** (e.g. `tag:ci`); that tag must **also**
  appear in the tailnet policy `tagOwners`, or the join fails.
- **Audience** — **generated by Tailscale** as `api.tailscale.com/<client-id>`.
  You do **not** type your own audience.
- **Output** — a **Client ID** and an **Audience**. Store both as repo variables
  (`TS_OIDC_CLIENT_ID`, `TS_OIDC_AUDIENCE`).

## The big gotcha — OIDC subject hardening

Deep dive: `skills/tailscale-wif/references/oidc-subject-hardening.md`.

Most examples show a **name-only** subject:

```
repo:ORG/REPO:pull_request
```

But some orgs/enterprises **harden** their OIDC config to embed the numeric
org/repo **database IDs** in the `sub`:

```
repo:ORG@306084426/REPO@1304364146:pull_request
```

If your org does this and you configure a **name-only** subject match, the
exchange **silently returns 403** — `token exchange failed with status 403:
Unauthorized` — because the `sub` Tailscale sees never matches what you typed.

**Fix:** match the **ID-embedded** form with a trailing `:*`:

```
repo:ORG@<orgId>/REPO@<repoId>:*
```

This is also **rename-proof** (numeric IDs don't change when you rename the org
or repo), so it is the better match even when the name-only form would work. Get
the IDs with:

```sh
gh api repos/OWNER/REPO --jq '{id, owner_id: .owner.id}'
```

`.id` is the **repo** ID (`@<repoId>`); `.owner_id` is the **org/owner** ID
(`@<orgId>`). The helper `skills/tailscale-wif/scripts/compute-subject.sh
OWNER/REPO` prints the exact ID-embedded subject to paste into the console.

### Debug technique — decode the actual `sub`

When in doubt, find out what GitHub is really signing. Add a **temporary**
workflow step (the job needs `id-token: write`) that mints a token and decodes
its payload:

```sh
# In a workflow `run:` step (the job needs id-token: write). Set AUD from your
# audience repo variable — the ready-made template wires it via the vars context.
AUD="api.tailscale.com/<your-client-id>"
TOK=$(curl -sH "Authorization: Bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=$AUD" | jq -r .value)
PAYLOAD=$(echo "$TOK" | cut -d. -f2)                 # JWT payload = 2nd dot-segment
case $(( ${#PAYLOAD} % 4 )) in 2) PAYLOAD="$PAYLOAD==";; 3) PAYLOAD="$PAYLOAD=";; esac  # pad to len%4
echo "$PAYLOAD" | tr '_-' '/+' | base64 -d | jq '{iss, aud, sub}'   # base64url -> base64 -> decode
```

The `sub` it prints is **exactly** what your Trust Credential's Subject must
match. A ready-made standalone job (with the audience wired from the repo
variable) is `skills/tailscale-wif/templates/debug-oidc-sub.yml` — delete the
step once the real subject is confirmed.

## Symptom -> cause table

| Symptom | Cause | Fix |
|---|---|---|
| `token exchange failed with status 403: Unauthorized` | Subject mismatch (usually OIDC subject hardening / wrong IDs), or wrong audience | Decode the real `sub` (above); set the Trust Credential Subject to the **ID-embedded** `repo:ORG@<orgId>/REPO@<repoId>:*`; confirm audience is `api.tailscale.com/<client-id>` |
| `requested tags [tag:X] are invalid or not permitted` | The tag is missing from the tailnet policy `tagOwners`, **or** the Trust Credential isn't scoped to assign that tag | Add `tag:X` to `tagOwners` in the policy file **and** assign it on the credential (scope `auth_keys`) |
| `only one of API Key, OAuth secret, or OAuth client ID and audience` | More than one auth mode passed to the action | Pass **exactly one** mode; for WIF, remove `api-key` / `oauth-secret` and keep only `oauth-client-id` + `audience` |

## Workflow to follow — set up

1. **Identify the use case** — ACL GitOps (`policy_file`) or node join
   (`auth_keys`). This decides the scope and the template.
2. **Compute the subject.** Run `skills/tailscale-wif/scripts/compute-subject.sh OWNER/REPO` (or the
   `gh api` command above) to get the ID-embedded
   `repo:ORG@<orgId>/REPO@<repoId>:*`.
3. **Create the Trust Credential** in the admin console with Issuer = GitHub
   Actions, the subject from step 2, the correct scope (and tag for `auth_keys`).
   Copy out the generated **Client ID** and **Audience**.
4. **Store the two public values** as repo variables `TS_OIDC_CLIENT_ID` and
   `TS_OIDC_AUDIENCE` (`gh variable set TS_OIDC_CLIENT_ID --body "..."`).
5. **Edit the workflow** from the matching template: add `permissions:
   id-token: write`, switch to `oauth-client-id` + `audience`, and **remove** the
   old `api-key` / `oauth-secret`. For node join add `tags:` and `version: latest`.
6. **Verify** on a PR and on `main`. If it 403s, use the decode-the-sub debug
   step, then reconcile the Subject.

## Workflow to follow — troubleshoot

1. Read the exact error and map it with the **symptom -> cause table**.
2. For any 403, **decode the real `sub`** with the debug step and compare it to
   the Trust Credential Subject character-for-character. The usual culprit is
   subject hardening — switch to the ID-embedded form.
3. For a tags error, check **both** `tagOwners` in the policy **and** the
   credential's assigned tag.
4. For the "only one of…" error, grep the workflow for a leftover `api-key:` or
   `oauth-secret:` and delete it.
5. Confirm the invariant still holds: no stored Tailscale secret, `id-token:
   write` present, exactly one auth mode.

Full troubleshooting reference:
`skills/tailscale-wif/references/troubleshooting.md`.
