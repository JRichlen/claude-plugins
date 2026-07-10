# Counterfeit: red-by-default sentinel shipped

**Gate exercised:** cheap tier section 8 — the scaffold sentinel never ships.

**Defect:** the UUID-shaped "unimplemented" sentinel the scaffolder writes into a
fresh plugin's checks.sh is left in place. Its survival means a plugin shipped with
a placeholder eval that was never implemented — fail closed.

EXPECT_FAIL_SUBSTRING=carries the red-by-default sentinel
