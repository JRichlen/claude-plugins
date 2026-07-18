# Cheap eval pack for the 'tailscale-wif' plugin — SOURCED by evals/cheap/run.sh
# with cwd = repo root; inherits ok/bad/group and $PLUGIN_NAME / $PLUGIN_DIR.
#
# Nothing here is destructive — this plugin ships prose, workflow templates, and a
# helper script. What the cheap tier defends is the plugin's SECRETLESS invariant
# and the load-bearing correctness facts a reader relies on. Each is a marker that
# is easy to silently gut (delete `id-token: write`, soften the subject-hardening
# fix, re-introduce a stored api-key/oauth-secret in a template) while the file
# still parses and reads fine. These greps make that kind of regression a red build.

SKILL="$PLUGIN_DIR/skills/tailscale-wif/SKILL.md"
AGENT="$PLUGIN_DIR/agents/tailscale-wif-setup.md"
SCRIPT="$PLUGIN_DIR/skills/tailscale-wif/scripts/compute-subject.sh"
T_ACL="$PLUGIN_DIR/skills/tailscale-wif/templates/acl-gitops.yml"
T_JOIN="$PLUGIN_DIR/skills/tailscale-wif/templates/node-join.yml"
T_DBG="$PLUGIN_DIR/skills/tailscale-wif/templates/debug-oidc-sub.yml"

# has/hasE/lacksE (fixed-string / regex / negative grep helpers) are provided by
# evals/cheap/run.sh as a single shared definition, inherited by every pack.

# --- structure: the advertised surface exists ------------------------------
group "tailscale-wif — structure"
for f in \
  "$PLUGIN_DIR/.claude-plugin/plugin.json" \
  "$SKILL" \
  "$AGENT" \
  "$PLUGIN_DIR/commands/tailscale-wif.md" \
  "$SCRIPT" \
  "$T_ACL" "$T_JOIN" "$T_DBG" \
  "$PLUGIN_DIR/skills/tailscale-wif/references/trust-credential-console-setup.md" \
  "$PLUGIN_DIR/skills/tailscale-wif/references/oidc-subject-hardening.md" \
  "$PLUGIN_DIR/skills/tailscale-wif/references/troubleshooting.md"; do
  if [ -f "$f" ]; then ok "present: $f"; else bad "MISSING: $f"; fi
done

# --- the secretless invariant is stated and taught -------------------------
group "tailscale-wif — secretless invariant"
has "$SKILL" 'id-token: write' \
  "SKILL keeps the id-token: write requirement" \
  "SKILL dropped 'id-token: write' — the OIDC token can no longer be minted"
has "$SKILL" 'never secrets' \
  "SKILL keeps 'public vars, never secrets' guidance" \
  "SKILL no longer says the client-id/audience go in variables, never secrets"
hasE "$SKILL" 'exactly \*?\*?one\*?\*? auth mode|only one of API Key' \
  "SKILL keeps the exactly-one-auth-mode rule" \
  "SKILL dropped the exactly-one-auth-mode rule (api-key XOR oauth-secret XOR client-id+audience)"
# Negation guard: the positive checks above are satisfied by any line containing
# the keyword, even one that INVERTS the rule ("the client-id IS a secret"). Reject
# the inverted secretless claim so a weakening rewrite that keeps the words fails.
lacksE "$SKILL" '(client-id|audience|oauth-client-id)[^.]{0,40}(is|are)( a)? secret|store[^.]{0,30}(client-id|audience)[^.]{0,20}(as|in)( a)? secret|must be (kept )?secret' \
  "SKILL never inverts the public-identifier rule" \
  "SKILL INVERTS the secretless rule — a public identifier (client-id/audience) is described as a secret"

# --- correctness facts from the knowledge pack -----------------------------
group "tailscale-wif — WIF correctness facts"
has "$SKILL" 'tailscale/gitops-acl-action' \
  "SKILL documents the ACL GitOps action (policy_file)" \
  "SKILL lost the gitops-acl-action use case"
has "$SKILL" 'tailscale/github-action' \
  "SKILL documents the node-join action (auth_keys)" \
  "SKILL lost the github-action node-join use case"
has "$SKILL" 'api.tailscale.com/' \
  "SKILL states the audience is generated as api.tailscale.com/<client-id>" \
  "SKILL lost the generated-audience fact"
has "$SKILL" 'gh api repos/OWNER/REPO --jq' \
  "SKILL keeps the gh api command that fetches the org/repo IDs" \
  "SKILL lost the 'gh api repos/OWNER/REPO --jq' ID-lookup command"
has "$SKILL" 'repo:ORG@<orgId>/REPO@<repoId>' \
  "SKILL keeps the ID-embedded subject fix for OIDC subject hardening" \
  "SKILL lost the ID-embedded subject fix — the silent-403 hardening gotcha is undefended"
has "$SKILL" 'ACTIONS_ID_TOKEN_REQUEST_TOKEN' \
  "SKILL keeps the decode-the-sub debug technique" \
  "SKILL lost the decode-the-sub debug step"
has "$SKILL" 'token exchange failed with status 403' \
  "SKILL keeps the 403 symptom in the symptom->cause table" \
  "SKILL lost the 403 'token exchange failed' symptom row"

# --- templates stay secretless (no stored credential re-introduced) --------
group "tailscale-wif — templates are secretless"
has  "$T_ACL"  'id-token: write' \
  "acl-gitops.yml has id-token: write" \
  "acl-gitops.yml dropped id-token: write"
has  "$T_ACL"  'oauth-client-id:' \
  "acl-gitops.yml uses oauth-client-id (WIF)" \
  "acl-gitops.yml no longer uses oauth-client-id"
lacksE "$T_ACL" '^[[:space:]]*api-key:' \
  "acl-gitops.yml passes NO stored api-key (secretless)" \
  "acl-gitops.yml re-introduced a stored api-key input — breaks the secretless invariant"
has  "$T_JOIN" 'id-token: write' \
  "node-join.yml has id-token: write" \
  "node-join.yml dropped id-token: write"
has  "$T_JOIN" 'oauth-client-id:' \
  "node-join.yml uses oauth-client-id (WIF)" \
  "node-join.yml no longer uses oauth-client-id"
has  "$T_JOIN" 'version: latest' \
  "node-join.yml pins version: latest (tailscaled >= 1.90.1)" \
  "node-join.yml dropped 'version: latest' — WIF needs tailscaled >= 1.90.1"
lacksE "$T_JOIN" '^[[:space:]]*oauth-secret:' \
  "node-join.yml passes NO stored oauth-secret (secretless)" \
  "node-join.yml re-introduced a stored oauth-secret input — breaks the secretless invariant"
has  "$T_DBG"  'ACTIONS_ID_TOKEN_REQUEST_URL' \
  "debug-oidc-sub.yml mints and decodes the real OIDC token" \
  "debug-oidc-sub.yml lost the OIDC token request that makes it useful"

# --- the subject helper actually computes the ID-embedded form -------------
group "tailscale-wif — compute-subject helper"
has "$SCRIPT" 'gh api "repos/' \
  "compute-subject.sh fetches the IDs via gh api repos/" \
  "compute-subject.sh no longer calls gh api repos/ to fetch the IDs"
hasE "$SCRIPT" 'repo:.*@.*/.*@.*:\*' \
  "compute-subject.sh assembles the ID-embedded subject repo:ORG@id/REPO@id:*" \
  "compute-subject.sh no longer emits the ID-embedded subject with a trailing :*"

# --- the agent can compute the subject and drive the console step ----------
group "tailscale-wif — setup agent"
has "$AGENT" 'compute-subject.sh' \
  "agent computes the ID-embedded subject via compute-subject.sh" \
  "agent no longer computes the subject"
has "$AGENT" 'Trust credentials' \
  "agent walks the user through the Trust credentials console step" \
  "agent lost the admin-console walkthrough step"
