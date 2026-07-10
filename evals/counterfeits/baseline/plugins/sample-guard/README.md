# sample-guard

A minimal known-good plugin. It is **not meant to be installed** — it is the
calibration baseline for the counterfeit corpus (`evals/counterfeits/`), the
smallest possible valid plugin that still ships a real safety invariant.

- **What it does:** emits a destructive cleanup script wrapped in a confirmation
  guard, so a real safety check has something to defend.
- **Why it exists:** every counterfeit fixture is this plugin with exactly one
  defect. The corpus proves the cheap tier rejects each one — and, up front, that
  this unmutated baseline passes.

See `skills/sample-guard/SKILL.md` for the invariant and `evals/cheap/checks.sh`
for the check that defends it.
