# Counterfeit: manifest name != marketplace name

**Gate exercised:** cheap tier section 3 — marketplace→plugin wiring.

**Defect:** `plugin.json`'s `name` is changed so it no longer matches the name the
marketplace registers for that source path. A mismatched manifest means the
marketplace points at the wrong thing.

EXPECT_FAIL_SUBSTRING=!= marketplace
