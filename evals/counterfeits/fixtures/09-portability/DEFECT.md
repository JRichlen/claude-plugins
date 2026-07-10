# Counterfeit: undeclared Claude-Code-only prose

**Gate exercised:** cheap tier section 9 — portability lint (per plugin).

**Defect:** the skill prose is made to lean on a Claude-Code-only primitive
(`PreToolUse` hooks) with no portability caveat. Undeclared CC-only prose breaks
anyone porting the plugin to another harness.

EXPECT_FAIL_SUBSTRING=without a portability caveat
