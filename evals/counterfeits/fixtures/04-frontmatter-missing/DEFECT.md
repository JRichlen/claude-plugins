# Counterfeit: SKILL.md missing a frontmatter field

**Gate exercised:** cheap tier section 4 — SKILL.md frontmatter has name + description.

**Defect:** the `description:` line is stripped from the skill frontmatter. The
description is the skill's primary triggering signal; shipping without it is broken.

EXPECT_FAIL_SUBSTRING=missing description:
