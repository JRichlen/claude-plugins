# How it works

The whole design serves one goal: make deleting a repo safe by making the backup
provably complete. Here's the mechanism.

## Git bundles vs. zip archives

A zip of a repo's working tree captures the *current files*. It loses history,
branches, and tags — and you can't `git clone` from it.

A [`git bundle`](https://git-scm.com/docs/git-bundle) is different: it's a single
file containing actual git objects (commits, trees, blobs) plus a set of refs. Git
treats a bundle as a valid transport, so you can clone or fetch directly from it:

```sh
git clone project.bundle project      # full working repo, full history
```

That means a bundle *is* the repository, serialized to one file — the right
primitive for a backup you intend to restore.

## Why mirror-clone first

A normal `git clone` only brings down the default branch's history (and sets up
remote-tracking refs). If you bundle from that, you can miss other branches.

```sh
git clone --mirror git@github.com:<owner>/<repo>.git repo.git
git -C repo.git bundle create repo.bundle --all
```

`--mirror` fetches **every** ref the remote exposes into a bare repo:

- all branches (`refs/heads/*`),
- all tags (`refs/tags/*`),
- and GitHub's pull-request refs (`refs/pull/*`).

Then `bundle create --all` packs all of them. The result is a bundle that holds
the repo's complete state, not just one branch.

## The pull-ref detail (why commit counts can differ)

You may notice the mirror reports **more** commits than a plain clone of the
bundle checks out. Example: a mirror shows 12, a fresh `git clone repo.bundle`
shows 11.

That's expected and not data loss. The extra object is usually a synthetic
GitHub ref like `refs/pull/1/merge` — a merge commit GitHub generates for a pull
request. The bundle *does* contain it (mirror clones fetch `refs/pull/*`), but a
plain `git clone` only checks out branch heads, so it doesn't surface it. Recover
everything with a wildcard fetch:

```sh
git bundle verify repo.bundle
git fetch repo.bundle '*:refs/bundle/*'   # brings in ALL refs, including pull refs
git for-each-ref refs/bundle              # see them
```

So: `git clone` from a bundle = convenient restore of the branches; `git fetch
'*:refs/bundle/*'` = exhaustive restore of every ref. Both come from the same
bundle.

## Verifying a bundle (the gotcha)

Before trusting a bundle, verify it. The catch: `git bundle verify` needs a
repository context to check that its prerequisite objects are satisfiable.

```sh
# WRONG — fails with "need a repository to verify a bundle":
git bundle verify repo.bundle

# RIGHT — run it with a repo as context (the mirror works fine):
git -C repo.git bundle verify repo.bundle
```

`archive-repo.sh` always uses the `-C <mirror>` form. If you're adapting the
workflow, keep that — the bare form's error message is misleading and easy to
misdiagnose as a corrupt bundle.

## The safety guarantee for deletion

`generate-delete-script.sh` never deletes anything itself — it emits a script you
review and run. That script encodes the core invariant:

```sh
# For each repo that was supposed to be backed up:
if gh api "repos/$OWNER/$GRAVEYARD/contents/$r/$r.bundle" >/dev/null 2>&1; then
  gh repo delete "$OWNER/$r" --yes      # backup confirmed on GitHub → safe to delete
else
  echo "SKIP  $r (bundle NOT found -- not deleting)"
fi
```

The check hits the GitHub *API*, not your local disk — so it proves the bundle
survived the push and is retrievable, which is exactly the condition under which
losing the original is acceptable. Repos deliberately deleted without a backup
(empty repos, forks) are passed separately via `--unbundled` and listed in the
script explicitly, so a reader can see every deletion and why.

## Size limits

GitHub warns on files larger than 50 MB and rejects files over 100 MB. Bundles
are compressed git packs, so they're typically small, but a repo with large
binaries or long history can produce a big bundle. Check before committing:

```sh
du -h graveyard/*/*.bundle | sort -h
```

If a bundle approaches 100 MB, either:
- enable [Git LFS](https://git-lfs.com/) in the graveyard repo and track
  `*.bundle`, or
- attach that bundle as a [GitHub Release](https://docs.github.com/en/repositories/releasing-projects-on-github)
  asset (up to 2 GB each) instead of committing it into the tree.

## Privacy note

A bundle contains the **entire** history, including anything ever committed —
secrets, keys, large blobs that were later deleted. That's a feature for a faithful
backup, but it's why the graveyard repo defaults to **private**. If a repo's
history contains secrets you don't want retained even privately, scrub them (e.g.
`git filter-repo`) before bundling, or don't archive that repo.
