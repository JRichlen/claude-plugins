# Counterfeit: AGENTS.md points at a file that doesn't exist

**Gate exercised:** cheap tier section 7 — every backticked path in AGENTS.md resolves.

**Defect:** a backticked path to a non-existent file is added to AGENTS.md. A
plugin's AGENTS.md is the map another harness follows in; a broken link is a broken map.

EXPECT_FAIL_SUBSTRING=which does not exist
