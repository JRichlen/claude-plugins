# Counterfeit: invalid JSON manifest

**Gate exercised:** cheap tier section 2 — every `*.json` parses.

**Defect:** `plugin.json` is corrupted into unparseable JSON. A malformed manifest
must be caught before it can be installed.

EXPECT_FAIL_SUBSTRING=(invalid JSON)
