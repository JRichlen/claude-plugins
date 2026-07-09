# Usage walkthrough

A narrated end-to-end example of retiring a handful of old repos. Whether an
agent drives this or you run it by hand, the shape is the same.

## 1. Decide what to retire

List your repos, sorted by how long since they were last touched, with the
signals that help you decide:

```sh
gh repo list <owner> --limit 200 \
  --json name,visibility,isFork,isArchived,pushedAt,diskUsage,description \
  --jq 'sort_by(.pushedAt) | .[] | "\(.name)\t\(.visibility)\tfork=\(.isFork)\tpushed=\(.pushedAt[:10])\t\(.diskUsage)KB\t\(.description // "")"'
```

You'll get something like:

```
old-experiment   private  fork=false  pushed=2021-03-14  120KB   quick spike, never finished
some-fork         public   fork=true   pushed=2020-11-02  8400KB  forked to read the code
empty-idea        private  fork=false  pushed=2022-01-01  0KB
harbinger         private  fork=false  pushed=2023-06-20  2100KB  old game prototype
```

Two things to flag before choosing:

- **`empty-idea` (0 KB)** — likely no commits, so there's nothing to bundle.
  Candidate for delete-without-backup. (Double-check: a 0 KB repo can still have
  one real commit. `gh api repos/<owner>/empty-idea/commits` tells you.)
- **`some-fork` (fork=true)** — the upstream still exists, so a bundle is
  usually redundant. Candidate for delete-without-backup — unless you added
  unique work to your fork.

## 2. Create the graveyard

```sh
gh repo create <owner>/graveyard --private \
  --description "Archived repositories, stored as restorable git bundles"
git clone git@github.com:<owner>/graveyard.git
```

## 3. Bundle the keepers-as-history

For each repo whose history you want to preserve:

```sh
skills/graveyard/scripts/archive-repo.sh <owner>/old-experiment ./graveyard
skills/graveyard/scripts/archive-repo.sh <owner>/harbinger      ./graveyard
```

Each run mirror-clones the repo, creates and **verifies** a full-history bundle,
and writes a folder like:

```
graveyard/harbinger/
├── harbinger.bundle     # full git history, all refs
├── metadata.json        # GitHub metadata snapshot
└── README.md            # restore instructions + stats
```

and prints a machine-readable success line:

```
RESULT	harbinger	OK	commits=214	size=2.1M	path=./graveyard/harbinger/harbinger.bundle
```

Keep track of which repos produced an `OK` — those are your **bundled** set.

## 4. Add an index, commit, and push

Write a top-level `graveyard/README.md` linking every archived folder, then:

```sh
# If you have global commit signing on but no matching key, disable it just here:
git -C graveyard -c commit.gpgsign=false add -A
git -C graveyard -c commit.gpgsign=false commit -m "Archive 2 repositories"
git -C graveyard push
```

## 5. Verify the backups are really on GitHub

Local commit isn't proof. Confirm each bundle is fetchable from the remote:

```sh
for r in old-experiment harbinger; do
  gh api "repos/<owner>/graveyard/contents/$r/$r.bundle" >/dev/null \
    && echo "backed up: $r" || echo "MISSING: $r"
done
```

For extra confidence, do a real round-trip on one:

```sh
git clone graveyard/harbinger/harbinger.bundle /tmp/restore-check
git -C /tmp/restore-check log --oneline | head
```

## 6. Generate the deletion script — then run it yourself

```sh
skills/graveyard/scripts/generate-delete-script.sh <owner> graveyard \
  --bundled  "old-experiment harbinger" \
  --unbundled "empty-idea some-fork" \
  > delete-originals.sh
```

**Review it**, then:

```sh
less delete-originals.sh
bash delete-originals.sh
```

The script:
- adds the `delete_repo` scope to your `gh` token if missing (one-time browser step),
- for each **bundled** repo, re-checks the bundle exists in the graveyard on
  GitHub and only then deletes the original,
- deletes the **unbundled** repos (which you explicitly listed) after the
  guarded set.

Sample output:

```
DELETE  old-experiment  (bundle verified in graveyard)
DELETE  harbinger  (bundle verified in graveyard)
DELETE  empty-idea  (intentionally not bundled)
DELETE  some-fork  (intentionally not bundled)
Done.
```

## Restoring later

From inside the graveyard repo:

```sh
git clone harbinger/harbinger.bundle harbinger    # back to a working repo
```

Or push it live again:

```sh
gh repo create <owner>/harbinger --private --source=harbinger --push
```

See [how-it-works.md](how-it-works.md) for what the bundle actually contains and
why the restore is complete.
