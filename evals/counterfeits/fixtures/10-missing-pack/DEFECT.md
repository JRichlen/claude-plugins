# Counterfeit: registered plugin with no cheap eval pack

**Gate exercised:** cheap tier section 10 — fail-closed per-plugin pack discovery.

**Defect:** the plugin's `evals/cheap/checks.sh` is deleted. A registered plugin
with no safety pack must be a FAILURE, never a silent skip — otherwise a plugin
could ship with zero safety coverage and still show green.

EXPECT_FAIL_SUBSTRING=has no cheap eval pack
