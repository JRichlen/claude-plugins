# Installation

Graveyard is a small, portable workflow (plain `bash` + `git` + `gh`) wrapped so
that it drops cleanly into whatever coding agent you use. Pick your harness below.

## Prerequisites (all harnesses)

- [`git`](https://git-scm.com/)
- [GitHub CLI `gh`](https://cli.github.com/), authenticated:
  ```sh
  gh auth login
  ```
- Deleting repos needs the `delete_repo` scope. You don't have to add it up
  front — the generated deletion script adds it interactively the first time you
  run it. To add it manually:
  ```sh
  gh auth refresh -h github.com -s delete_repo
  ```

---

## Claude Code (plugin)

Install straight from the GitHub repo as a marketplace:

```
/plugin marketplace add JRichlen/graveyard-plugin
/plugin install graveyard@graveyard-plugin
```

This registers:
- the **`graveyard` skill** — triggers automatically when you talk about
  archiving/cleaning up old repos, and
- the **`/graveyard` slash command** — an explicit entry point.

Verify:
```
/plugin
```
You should see `graveyard` listed and enabled.

---

## OpenAI Codex CLI

Codex reads `AGENTS.md`. Clone the repo and either work inside it, or copy the
pieces into your project:

```sh
git clone https://github.com/JRichlen/graveyard-plugin
cd graveyard-plugin
codex   # then: "archive my old GitHub repos into a graveyard"
```

Codex will pick up `AGENTS.md`, which points it at `skills/graveyard/SKILL.md`
and the scripts.

---

## Cursor

Cursor reads `AGENTS.md` at the project root (and `.cursor/rules/`). Clone the
repo and open it in Cursor, or add this repo as a submodule/subfolder of your
workspace so `AGENTS.md` is visible. Then ask the agent to archive your old repos.

To make it a persistent rule, you can add a thin `.cursor/rules/graveyard.mdc`
that says "For archiving/retiring GitHub repos, follow ./AGENTS.md".

---

## Gemini CLI

Gemini CLI reads `GEMINI.md` (and increasingly `AGENTS.md`). Point it at the
workflow with a one-line symlink so you don't duplicate content:

```sh
git clone https://github.com/JRichlen/graveyard-plugin
cd graveyard-plugin
ln -s AGENTS.md GEMINI.md   # if your Gemini version prefers GEMINI.md
gemini   # "back up and delete my old GitHub repos"
```

---

## Aider / other agents

Any agent that can read a markdown instruction file and run shell commands works:

```sh
git clone https://github.com/JRichlen/graveyard-plugin
cd graveyard-plugin
```

Add `AGENTS.md` (or `SKILL.md`) to the agent's context and ask it to follow the
workflow.

---

## No agent at all (manual)

The scripts stand on their own:

```sh
git clone https://github.com/JRichlen/graveyard-plugin
cd graveyard-plugin

# 1. Create a private graveyard repo and clone it
gh repo create <owner>/graveyard --private --description "Archived repos as git bundles"
git clone git@github.com:<owner>/graveyard.git

# 2. Bundle each repo you want to retire
skills/graveyard/scripts/archive-repo.sh <owner>/<repo> ./graveyard

# 3. Commit and push the graveyard
git -C graveyard add -A && git -C graveyard commit -m "Archive repos" && git -C graveyard push

# 4. Generate and review a guarded deletion script
skills/graveyard/scripts/generate-delete-script.sh <owner> graveyard \
  --bundled "repo1 repo2" > delete-originals.sh
less delete-originals.sh    # review!
bash delete-originals.sh
```

See [usage.md](usage.md) for a narrated end-to-end walkthrough.
