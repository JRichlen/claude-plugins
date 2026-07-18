---
description: Discover today's work from local sessions/commits/prompts, interview, and record a scannable dated diary entry.
argument-hint: "[YYYY-MM-DD]   (defaults to today, local time)"
---

Invoke the `dev-diary` skill and follow `skills/dev-diary/SKILL.md`.

Run the end-of-day loop for the target day (the argument, or today in local time):
discover the day's signals with `skills/dev-diary/scripts/discover-today.sh`, drill
into anything significant, **interview the user** about what actually mattered and
why, then write `entries/<YYYY>/<date>.md` in the journal repo `~/projects/dev-diary`
and update its changelog. Redact secrets; never skip the interview.
