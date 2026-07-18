# Counterfeit: paid-pack discovery contract drift

**Gate exercised:** cheap tier section 11b — paid-pack discovery self-test.

**Defect:** the fail-closed validation is removed from `discover-paid-packs.sh` so a
declared-but-broken paid pack no longer fails closed. The discovery script's own
--self-test (wired into the cheap tier) must catch that its contract drifted.

EXPECT_FAIL_SUBSTRING=paid-pack discovery contract drifted
