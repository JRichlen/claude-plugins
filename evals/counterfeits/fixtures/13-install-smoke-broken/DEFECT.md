# Counterfeit: install-smoke coverage failure

**Gate exercised:** cheap tier section 12 — install-smoke coverage (every registered plugin installs structurally).

**Defect:** the baseline plugin's manifest declares an `agents` component directory
that doesn't exist. A real installer walking marketplace -> plugin.json -> component
dirs would choke; the install-smoke gate must reject it.

EXPECT_FAIL_SUBSTRING=is not covered by a passing smoke test
