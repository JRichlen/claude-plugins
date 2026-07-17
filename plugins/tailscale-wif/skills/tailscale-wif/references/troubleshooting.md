# Troubleshooting Tailscale WIF in GitHub Actions

Map the exact error string to its cause. When any 403 appears, always
**decode the real `sub`** first (see `templates/debug-oidc-sub.yml`) rather than
guessing.

## Symptom -> cause -> fix

### `token exchange failed with status 403: Unauthorized`
**Cause:** subject mismatch (most often OIDC subject hardening / wrong IDs), or a
wrong audience.

**Fix:**
1. Decode the actual `sub` (`templates/debug-oidc-sub.yml`).
2. Set the Trust Credential Subject to the **ID-embedded** form
   `repo:ORG@<orgId>/REPO@<repoId>:*` — compute it with
   `scripts/compute-subject.sh OWNER/REPO`.
3. Confirm the audience is `api.tailscale.com/<client-id>` and matches
   `vars.TS_OIDC_AUDIENCE`.

### `requested tags [tag:X] are invalid or not permitted`
**Cause:** the tag is missing from the tailnet policy `tagOwners`, **or** the
Trust Credential isn't scoped to assign that tag.

**Fix:** add `tag:X` to `tagOwners` in the policy file **and** assign `tag:X` on
the credential (scope must be `auth_keys`). Both are required.

### `only one of API Key, OAuth secret, or OAuth client ID and audience`
**Cause:** more than one auth mode passed to the action.

**Fix:** pass **exactly one** mode. For WIF, delete any leftover `api-key:` or
`oauth-secret:` input and keep only `oauth-client-id:` + `audience:`.

## Checklist that reproduces a green run

- [ ] The job has `permissions: id-token: write` (and `contents: read`).
- [ ] Exactly one auth mode is present — for WIF, `oauth-client-id` + `audience`,
      and **no** `api-key` / `oauth-secret`.
- [ ] `oauth-client-id` / `audience` come from repo **variables** (`vars.*`), not
      secrets.
- [ ] The Trust Credential Subject is the ID-embedded form with a trailing `:*`.
- [ ] Scope matches the use case: `policy_file` (ACL) or `auth_keys` (join).
- [ ] For `auth_keys`: the tag is in `tagOwners` **and** assigned on the credential.
- [ ] Node join uses `tailscale/github-action` v4.1.3+ and `version: latest`
      (tailscaled >= 1.90.1).
- [ ] No stored Tailscale API key or OAuth secret remains anywhere in the repo.
