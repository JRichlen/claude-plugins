# Counterfeit: branch-protection lock drift

**Gate exercised:** cheap tier section 11 — branch-protection lock (required checks in sync with the workflow).

**Defect:** a required-check name in `ci/required-checks.json` is renamed so it no
longer appears verbatim in `.github/workflows/evals.yml`. Branch protection would
then require a check CI never emits, deadlocking every PR — the drift this gate exists to catch.

EXPECT_FAIL_SUBSTRING=branch-protection drift
