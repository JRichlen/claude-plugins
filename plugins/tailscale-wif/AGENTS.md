# AGENTS.md — tailscale-wif

This plugin sets up and troubleshoots **secretless GitHub Actions -> Tailscale
authentication** via Workload Identity Federation (WIF). Each workflow run mints
a GitHub-signed OIDC token; a Tailscale **Trust Credential** exchanges it for a
short-lived (~1h) API token or an ephemeral auth key. Nothing is stored: the
`oauth-client-id` and `audience` are **public** identifiers that live in repo
variables, replacing the old stored API key (expires <=90d) or OAuth client
secret (a long-lived bearer secret).

Everything here is plain GitHub Actions YAML plus `gh`/`curl`/`jq`, so it is
harness-agnostic. This `AGENTS.md` is the cross-harness entry point; harnesses
that read it (or a symlink like `CLAUDE.md`/`GEMINI.md`) land on the same content.

## When to use this

- A GitHub Actions workflow needs to talk to Tailscale — push an ACL/policy file
  (with the gitops-acl-action) or join a CI runner to the tailnet (with the
  github-action) — and you want to drop the stored credential.
- An existing WIF workflow is failing with `token exchange failed with status
  403: Unauthorized`, a tags-not-permitted error, or "only one of API Key, OAuth
  secret, or OAuth client ID and audience".

## How to use it

**Read `skills/tailscale-wif/SKILL.md` and follow it.** It is the authoritative,
harness-agnostic description: the two use cases, the workflow requirements, the
Trust Credential console fields, the OIDC subject-hardening gotcha and its fix,
the decode-the-sub debug step, and the symptom -> cause table.

Supporting files it drives:

- `skills/tailscale-wif/scripts/compute-subject.sh` — prints the ID-embedded
  OIDC subject (`repo:ORG@<orgId>/REPO@<repoId>:*`) to paste into the console.
- `skills/tailscale-wif/templates/acl-gitops.yml` — ACL / policy GitOps workflow.
- `skills/tailscale-wif/templates/node-join.yml` — node-join workflow.
- `skills/tailscale-wif/templates/debug-oidc-sub.yml` — temporary job that decodes
  the real `sub` claim.
- `skills/tailscale-wif/references/trust-credential-console-setup.md` — admin
  console walkthrough.
- `skills/tailscale-wif/references/oidc-subject-hardening.md` — the silent-403
  deep dive.
- `skills/tailscale-wif/references/troubleshooting.md` — full symptom table.

The command a user invokes is `commands/tailscale-wif.md`.

On Claude Code specifically, the agent `agents/tailscale-wif-setup.md` can run the
whole setup/troubleshoot loop. PORTABILITY: that agent is only a Claude-Code
wrapper — the same procedure ports to any harness by following the skill and
running the scripts directly.

## The invariant this plugin defends

> WIF auth is **secretless**: only the public `oauth-client-id` and `audience`
> are stored (as repo **variables**, never secrets), the job always carries
> `permissions: id-token: write`, and **exactly one** auth mode is passed. No
> long-lived Tailscale credential (API key, OAuth client secret) is ever stored
> to enable a run.

The deterministic checks that defend it live in `evals/cheap/checks.sh` and run
as part of the marketplace cheap tier.

## Requirements

- `gh` (authenticated) and `jq` for `skills/tailscale-wif/scripts/compute-subject.sh`.
- For node join: the github-action at v4.1.3+ and `version: latest` (so
  `tailscaled` is >= 1.90.1), plus the tag present in the tailnet policy
  `tagOwners`.
