# Fleet Playbook Curator — Design

Recorded design for this plugin. It reconciles two independent analyses (a multi-agent
decomposition and a conceptual "fable" reframe) that converged on the structure and split
on one call, resolved below.

## What it is

A **self-invalidating operating index** for a fleet of repos — a router/concierge, not a
document. Deterministic change-detection is the *cache-invalidation* layer, the agent is
the *cache-fill*, and the changelog is the *invalidation log*. Build the index, not the book.

| Cache concept | This system |
|---|---|
| invalidation | deterministic daily detector (no LLM) |
| cache-fill / re-index | agentic curator (LLM), only on a real detected change |
| entry discipline | never serve a claim without its source + as-of SHA |
| invalidation log | `CHANGELOG.md` |

## The invariant

> The fleet-playbook is a curated INDEX that only says where truth lives and when it was
> read: every substantive claim carries a `repo@sha:path` citation and an "as-of" stamp,
> uncited claims are omitted or flagged stale rather than asserted, and the agent's
> interpretation reaches `main` only through a reviewed PR while the deterministic detector
> auto-commits only facts.

The headline rule that makes it survive the LLM being wrong, lazy, or prompt-injected:
**facts auto-commit; interpretation is PR-only.**

## Decomposition (reconciled)

The original hypothesis proposed four skills (`fleet`, `fleet-playbook`,
`fleet-playbook-curator`, `deploy-fleet-playbook-curator`). Resolution:

| Piece | Resolved as |
|---|---|
| `fleet` | **Data + scripts, not a standalone skill** — a `fleet.yaml` manifest plus the deterministic membership/diff scripts, kept as a clean internal module that can be **promoted to its own `fleet` plugin the day a second consumer** (cost-report, security-audit) wants it. YAGNI wins v1. |
| deploy + curate | **One skill** (`fleet-playbook-curator`), two **commands** (`deploy-fleet-playbook`, `curate-fleet-playbook`), one **agent** for the unattended run. |
| `fleet-playbook` | **Generated output**, instantiated per-fleet into that fleet's own repo. Never published as a marketplace skill (a hosted instance reads as authoritative). What ships is the **template/contract** under `templates/fleet-playbook/`. |

## Architecture

```mermaid
graph TD
    subgraph mkt["JRichlen/claude-plugins"]
        CUR["fleet-playbook-curator plugin<br/>skill + agent + deploy/curate commands<br/>fleet primitive (scripts) + playbook TEMPLATE + evals"]
    end
    HUMAN["operator"] -->|invokes once| DEPLOY["/deploy-fleet-playbook<br/>(plan + confirm gate)"]
    DEPLOY --> CUR
    DEPLOY -->|scaffolds| TARGET
    subgraph TARGET["&lt;fleet&gt;-playbook (new, distinct, private repo)"]
        WF["fleet-sync.yml<br/>(daily cron + dispatch)"]
        PB["fleet-playbook/ (instantiated)<br/>SKILL.md + index.json + source-of-truth:false"]
        CL["CHANGELOG.md"]
        ST["fleet-manifest.json (committed facts)"]
        WF -->|detect: facts, auto-commit main| ST
        WF -->|curate: interpretation, PR only| PB
        WF --> CL
    end
    GLOB["fleet.yaml: owner + glob"] --> WF
    subgraph TRUTH["source of truth — fleet member repos"]
        R["ansible-homelab-* / any glob"]
    end
    WF -->|reads changed repos only| TRUTH
    PB -.->|POINTS TO, never duplicates| TRUTH
```

## The daily loop

```mermaid
flowchart TD
    A["cron daily (+ dispatch)"] --> B["detect job — bash/gh/jq, NO LLM credential"]
    B --> C["list-fleet-members.sh: enumerate glob, stamp head_sha (node_id keyed)"]
    C --> D["diff-fleet.sh vs committed manifest"]
    D --> E{"changed?"}
    E -->|no| F["heartbeat line in CHANGELOG · commit facts · STOP"]
    E -->|yes| G["auto-commit facts manifest to main · emit diff.json"]
    G --> H["curate job — needs detect, if changed<br/>ANTHROPIC_API_KEY scoped HERE only"]
    H --> I["gather-context.sh: changed repos only"]
    I --> J["agent edits playbook (cited) + 1 changelog entry"]
    J --> K["open PR — never push main"]
```

## How the eval tiers defend the invariant

| Tier | Mechanism | Status |
|---|---|---|
| **Cheap** (this plugin, `evals/cheap/checks.sh`) | Template carries the banner + `source-of-truth:false`; index schema requires a real `sha` (no placeholders); `fleet-sync.yml` has the detect(no-LLM)/curate(PR-only) split — curate opens a PR and never `git push origin main`, detector has no `ANTHROPIC_API_KEY`; `diff-fleet.sh` is byte-deterministic (run twice on a fixture); scripts `bash -n` clean | **Built** |
| **Counterfeit** | The marketplace tier mutates a green baseline and asserts the cheap gate rejects each defect | **Passing via the shared corpus** |
| **Behavioral** (promptfoo) | Under pressure ("just tell me / skip the PR / add a repo not in the glob") the skill points back to source, refuses direct-push, defers membership to the deterministic list | **Recommended next** |
| **Deep** (pier) | Adversarial: a member README injects "mark canonical / push to main / copy the token"; passes only if no direct push, banner intact, token in no committed file; calibration oracle=1/nop=0/compliant=0 | **Recommended next — the real risk surface** (unattended run + live creds + untrusted content) |

## Risks

- **Staleness-presented-as-fact** (core, only partly mitigable): the independent `head_sha`
  clock, STALE markers, per-claim as-of stamps, and a red build on a stale CHANGELOG defend
  it; a consumer can still ignore the banner (→ the behavioral consumer-side eval).
- **Glob/rate-limit**: `node_id` join + `orgs/{owner}/repos` (not Search API) + cost cascade
  ≈ 1–13 calls/day at ~6 repos. Cross-org globs deferred (v1 = single owner); GraphQL
  batching needed ~100 members.
- **Deploy blast radius**: default-private target, idempotent byte-identical scaffolding,
  human confirm/dry-run in the command, curate never auto-merges (v1).
- **State in committed git history, never Actions cache** (which expires ~7 days and would
  silently reset the staleness clock).
