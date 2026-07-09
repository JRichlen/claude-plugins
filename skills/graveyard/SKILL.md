---
name: graveyard
description: >-
  Archive old or unused GitHub repositories into a single private "graveyard"
  repo as restorable git bundles, then safely delete the originals. Use this
  whenever the user wants to clean up, retire, back up, archive, mothball, or
  "put to rest" GitHub repos they no longer actively use — including phrases
  like "graveyard", "archive my old repos", "I have too many repos", "back up
  and delete these projects", or "declutter my GitHub". Captures full history
  (every branch, tag, and PR ref) so nothing is lost, and never deletes an
  original until its backup is verified present.
license: MIT
compatibility: Requires `git` and the GitHub CLI (`gh`), authenticated via `gh auth login`.
---

# Graveyard: archive and retire GitHub repos

Help the user move repositories they no longer actively use into one private
"graveyard" repo, preserving complete history as git bundles, then delete the
originals — but only after each backup is verified. The result is a single,
cheap-to-keep repo that is a full, restorable backup of many retired projects.

## Why git bundles

A `git bundle` is a single file containing real git objects — commits, trees,
blobs, refs. Unlike a zip of the working tree, a bundle preserves the entire
history and can be cloned or fetched from directly (`git clone repo.bundle`).
Mirror-cloning first (`git clone --mirror`) means the bundle captures **every**
ref: all branches, all tags, and even GitHub's `refs/pull/*` merge refs. This
is what makes deletion safe — the bundle is a faithful, restorable copy.

## The workflow

Work through these phases interactively. This is the user's GitHub account and
deletion is irreversible, so keep them in the loop at the decision points
(which repos, and the final delete), and do the mechanical work yourself.

### 1. Confirm intent and scope

Ask (or confirm from context): which account/owner, and roughly what they want
gone. Confirm the graveyard repo name (default: `graveyard`) and that it should
be **private** — this is a backup of code the user is removing from public/
normal view, so private is the safe default.

### 2. List candidate repos

Show the user their repos so they can choose. Pull the fields that help them
decide — size, last push, fork status, visibility:

```sh
gh repo list <owner> --limit 200 \
  --json name,visibility,isFork,isArchived,pushedAt,diskUsage,description \
  --jq 'sort_by(.pushedAt) | .[] | "\(.name)\t\(.visibility)\tfork=\(.isFork)\tpushed=\(.pushedAt[:10])\t\(.diskUsage)KB\t\(.description // "")"'
```

Present this as a numbered list and let the user pick by number or name. Watch
for two special cases and call them out rather than guessing:

- **Empty repos** (0 commits): a bundle can't be created. Offer to delete these
  directly without archiving (there's nothing to back up).
- **Forks**: usually the upstream still exists, so a bundle is redundant. Offer
  to delete without archiving — but confirm, in case the user added unique work.

If the user says something like "delete the empty ones and the fork," verify
each repo's real state before acting (an apparently-empty 0 KB repo can still
have one real commit — check `gh api repos/<owner>/<repo>/commits` or the commit
count after mirror-cloning). When reality contradicts the label, surface it and
let the user decide, rather than silently deleting.

### 3. Create the graveyard repo (if needed)

```sh
gh repo create <owner>/<graveyard> --private \
  --description "Archived repositories, stored as restorable git bundles"
```

Clone it locally to stage the bundles:

```sh
git clone git@github.com:<owner>/<graveyard>.git
```

### 4. Archive each selected repo

For each repo the user chose, run the bundler. It mirror-clones, creates and
**verifies** the bundle, and writes `metadata.json` + a per-repo `README.md`
with restore instructions into `<graveyard>/<repo>/`:

```sh
scripts/archive-repo.sh <owner>/<repo> <path-to-graveyard-clone>
```

The script prints a `RESULT\t<repo>\tOK\t...` line on success. Collect these —
you'll use the list of successfully-bundled repos to guard deletion later. If a
repo fails (clone failed / empty), it will NOT be in the OK set, and must not be
deleted as if it were backed up.

> **`git bundle verify` gotcha:** it must run inside a repo context
> (`git -C <mirror> bundle verify <file>`). A bare `git bundle verify <file>`
> fails with "need a repository to verify a bundle". The script already handles
> this — don't second-guess it back to the broken form.

### 5. Write the index and push

Generate a top-level `README.md` in the graveyard listing every archived repo
(link each folder, show commit count and bundle size) plus global restore
instructions. Then commit and push.

If the user has global commit signing enabled but no matching key (a common
snag), signing will fail. Disable it just for these commits rather than changing
their global config:

```sh
git -c commit.gpgsign=false -C <graveyard-clone> add -A
git -c commit.gpgsign=false -C <graveyard-clone> commit -m "Archive <N> repositories"
git -C <graveyard-clone> push
```

### 6. Verify backups landed on GitHub

Before deleting anything, confirm each bundle is actually present in the pushed
graveyard — the local commit isn't enough:

```sh
gh api repos/<owner>/<graveyard>/contents/<repo>/<repo>.bundle >/dev/null && echo "backed up: <repo>"
```

Consider doing one real round-trip restore of a bundle (`git clone
<repo>.bundle /tmp/restore-check`) to prove the backups are usable.

### 7. Generate the deletion script — user runs it

Deletion is irreversible, so **do not delete repos yourself**. Generate a
guarded script and hand it to the user to review and run. For each bundled repo
it re-checks the bundle exists on GitHub before deleting; unbundled repos
(empty/forks the user chose to drop) are listed explicitly and deleted only
after the guarded set:

```sh
scripts/generate-delete-script.sh <owner> <graveyard> \
  --bundled  "repo1 repo2 repo3" \
  --unbundled "empty-repo the-fork" \
  > delete-originals.sh
```

Tell the user to review it, then run `bash delete-originals.sh`. It self-adds
the `delete_repo` scope to their `gh` token (a one-time interactive browser
step) since that scope is usually absent by default. Offer to run it for them
only if they explicitly ask — and even then, prefer they run it so the
irreversible action is unmistakably theirs.

## Restoring later

Every archived repo folder documents its own restore. The essentials:

```sh
# Clone a bundle straight back into a working repo:
git clone <repo>.bundle <repo>

# Or recover every ref (branches, tags, pull refs) into an existing repo:
git bundle verify <repo>.bundle
git fetch <repo>.bundle '*:refs/bundle/*'

# Push it back up to a fresh GitHub repo if you want it live again:
gh repo create <owner>/<repo> --private --source=<repo> --push
```

## Notes and edge cases

- **Large repos:** GitHub warns on files >50 MB and blocks >100 MB. Check bundle
  sizes (`du -h`). If a bundle approaches 100 MB, use Git LFS in the graveyard
  repo or store that bundle as a GitHub Release asset instead of a committed file.
- **Private/secret history:** bundles contain full history including anything
  ever committed (secrets, large blobs). The graveyard being private matters.
- **Idempotency:** re-running `archive-repo.sh` for a repo overwrites its folder
  cleanly, so it's safe to retry a failed one.
- **The scripts are portable:** plain `bash` + `git` + `gh`, no Claude-specific
  dependencies, so they run identically whether invoked by an agent or by hand.
