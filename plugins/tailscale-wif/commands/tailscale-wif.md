---
description: Set up or troubleshoot secretless GitHub Actions -> Tailscale auth via Workload Identity Federation (WIF) — drop the stored API key / OAuth secret, or fix a 403 / tags / auth-mode failure
argument-hint: "[repo and what you want — e.g. 'set up ACL GitOps for me/infra' or 'fix the 403 token exchange in me/app']"
---

# /tailscale-wif

Set up or troubleshoot **secretless** GitHub Actions -> Tailscale authentication
via Workload Identity Federation: each run mints a GitHub OIDC token that a
Tailscale Trust Credential exchanges for a short-lived token — no stored API key
or OAuth secret. Reach for it to move a workflow off a stored Tailscale
credential, or to diagnose `token exchange failed with status 403: Unauthorized`,
`requested tags ... are invalid or not permitted`, or `only one of API Key, OAuth
secret, or OAuth client ID and audience`.

**Invoke the `tailscale-wif` skill and follow `skills/tailscale-wif/SKILL.md`.**
It carries the two use cases (ACL GitOps via `tailscale/gitops-acl-action`, node
join via `tailscale/github-action`), the workflow requirements (`id-token:
write`, exactly one auth mode, public client-id + audience in repo variables),
the Trust Credential console fields, the OIDC subject-hardening gotcha and its
ID-embedded-subject fix, the decode-the-sub debug step, and the symptom -> cause
table.

On Claude Code you can hand the whole job to the `tailscale-wif-setup` agent
(`agents/tailscale-wif-setup.md`), which computes the ID-embedded subject, walks
you through the console step, wires the repo variables, and edits the workflow.
On any other harness, follow the skill directly — the procedure is identical.

Task: `$ARGUMENTS`

Before doing anything, settle:
- **Use case** — ACL GitOps (scope `policy_file`) or node join (scope
  `auth_keys` + a tag). This picks the template and the Trust Credential scope.
- **OWNER/REPO** — needed to compute the ID-embedded subject with
  `skills/tailscale-wif/scripts/compute-subject.sh`.
- Whether you are **setting up** fresh or **troubleshooting** an existing run.
