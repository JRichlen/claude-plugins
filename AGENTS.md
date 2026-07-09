# AGENTS.md — Graveyard workflow

This repository packages a portable workflow for **archiving old GitHub repos
into a single private "graveyard" repo as restorable git bundles, then safely
deleting the originals.**

It is designed to work with any coding agent/harness — Claude Code, OpenAI
Codex CLI, Cursor, Gemini CLI, Jules, Zed, Aider, and others — because the core
is plain `bash` + `git` + `gh`, and the instructions live in a standard
`SKILL.md`. This `AGENTS.md` is the cross-harness entry point; harnesses that
read `AGENTS.md` (or a symlink to it, like `CLAUDE.md`/`GEMINI.md`) will find
the workflow here.

## When to run this workflow

The user wants to clean up, retire, back up, archive, mothball, or "put to rest"
GitHub repos they no longer actively use — e.g. "archive my old repos", "I have
too many repos", "back up and delete these projects", "declutter my GitHub", or
anything mentioning a repo "graveyard".

## How to run it

**Read `skills/graveyard/SKILL.md` and follow it step by step.** That file is
the authoritative, harness-agnostic description of the workflow. The two helper
scripts it drives:

- `skills/graveyard/scripts/archive-repo.sh <owner/repo> <dest-dir>` — mirror-
  clone one repo, create + verify a full-history git bundle, write metadata and
  a per-repo restore README into `<dest-dir>/<repo>/`.
- `skills/graveyard/scripts/generate-delete-script.sh <owner> <graveyard> --bundled "..." [--unbundled "..."]`
  — emit a guarded deletion script (to stdout) that the user reviews and runs;
  it re-verifies each bundle exists on GitHub before deleting the original.

## Non-negotiable guardrails

1. **This is the user's GitHub account. Deletion is irreversible.** Keep the
   user in the loop on which repos to archive and on the final delete. Do not
   delete repos yourself — hand the user the generated deletion script to run.
2. **Never delete a repo whose bundle is not verified present** in the graveyard
   on GitHub. The generated script enforces this; don't bypass it.
3. **Default the graveyard repo to private.** It contains full history of code
   the user is removing.
4. When a repo's real state contradicts a label ("empty", "just a fork"),
   surface it and let the user decide rather than silently deleting.

## Requirements

- `git`
- GitHub CLI `gh`, authenticated (`gh auth login`). Deletion additionally needs
  the `delete_repo` scope, which the generated script adds interactively.
