# Counterfeit: plugin on disk with no marketplace entry

**Gate exercised:** cheap tier section 5 — reverse lockfile.

**Defect:** a second plugin directory (`plugins/orphan/`) with a valid manifest is
added, but no matching marketplace entry. An unregistered plugin is never
enumerated for its safety pack, so it could ship with zero coverage — fail closed.

EXPECT_FAIL_SUBSTRING=has a plugin.json but no marketplace entry
