# Counterfeit: broken shell syntax

**Gate exercised:** cheap tier section 1 — `bash -n` over every plugin/evals script.

**Defect:** `scripts/emit.sh` is rewritten to an unterminated `if` — a real shell
syntax error. A plugin whose scripts don't parse must never show green.

EXPECT_FAIL_SUBSTRING=(syntax error)
