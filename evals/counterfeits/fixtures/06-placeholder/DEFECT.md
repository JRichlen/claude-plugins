# Counterfeit: unfilled scaffold placeholder

**Gate exercised:** cheap tier section 6 — no unfilled `{{...}}` tokens in prose/manifests.

**Defect:** an unfilled `{{TODO}}` template token is injected into the skill prose.
A surviving placeholder means a plugin went out with a hole the scaffolder never filled.

EXPECT_FAIL_SUBSTRING=unfilled {{...}} token
