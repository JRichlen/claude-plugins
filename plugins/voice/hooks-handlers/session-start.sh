#!/usr/bin/env bash
#
# Emit the voice routing rule as additionalContext at session start.
#
# This is a CONVENIENCE, not a dependency. The three skills under skills/ are
# complete and usable on their own; this handler only makes the routing decision
# salient early so the model consults the right one without being asked. On any
# harness that does not run this handler, the skills still work — they are
# selected the ordinary way, by their descriptions.
#
# Fires on startup, clear, and compact so the routing rule survives context
# compaction. Keep the injected text short: it is a pointer to the skills, not a
# copy of them.
#
# Contract: print a single JSON object on stdout with
# hookSpecificOutput.additionalContext, then exit 0.

cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "The `voice` plugin is installed. Route each output ELEMENT (not the whole response) to exactly one voice.\n\nMachine-read elements — agent traces, tool-call logs, status lines, progress updates, handoff notes, state dumps, config, schemas, reference cards, and structured data another agent parses — follow the `machine-voice` skill: compress lexically, use markdown as navigation, use emojis as typed status markers.\n\nEvery other element is prose a human reads and follows the `human-voice` skill: verdict first, paragraphs of 4 sentences or fewer, load-bearing claims tagged with the closed vocabulary ✅ verified / ⚠️ inferred / ❓ unverified.\n\nOut of scope for both: code and file contents, commit messages, creative or persona writing, and turns that are only a clarifying question or only tool calls. Ship those unstyled.\n\nNever run the `second-opinion` skill unbidden — offer it and wait for the user to accept. Read the relevant SKILL.md before applying any of this in detail."
  }
}
JSON

exit 0
