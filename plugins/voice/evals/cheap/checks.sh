# Cheap eval pack for the 'voice' plugin — SOURCED by evals/cheap/run.sh
# with cwd = repo root; inherits ok/bad/group and $PLUGIN_NAME / $PLUGIN_DIR.
#
# This plugin ships only prose, so every check below greps for a load-bearing
# marker: a sentence that, if silently deleted or softened, would weaken the
# invariant while leaving three perfectly valid, well-formed SKILL.md files.
# That is exactly the regression class the structural gates cannot see.
#
# The two clauses being defended:
#   1. ROUTING — the partition is per output ELEMENT and is both exclusive and
#      exhaustive (an explicit out-of-scope list). The original drafts split
#      per response, which put a schema-inside-an-explanation in both skills at
#      once, and named no escape hatch for code or commit messages.
#   2. NO COUNTERFEIT VALIDATION — second-opinion must refuse to emit its own
#      output format when it cannot actually dispatch subagents. A fabricated
#      Verified/Flagged/Conflict block is indistinguishable from a real one to
#      the user who asked "are you sure", which makes it the worst failure in
#      the plugin.

_HV="$PLUGIN_DIR/skills/human-voice/SKILL.md"
_MV="$PLUGIN_DIR/skills/machine-voice/SKILL.md"
_SO="$PLUGIN_DIR/skills/second-opinion/SKILL.md"
_REF="$PLUGIN_DIR/skills/machine-voice/references/lexical-patterns.md"
_AG="$PLUGIN_DIR/AGENTS.md"
_HOOK="$PLUGIN_DIR/hooks/hooks.json"
_HANDLER="$PLUGIN_DIR/hooks-handlers/session-start.sh"
_PROMPT="$PLUGIN_DIR/evals/promptfoo/prompt.txt"

# has FILE PATTERN OK-MSG FAIL-MSG  — fixed-string grep
has()  { if grep -qF "$2" "$1" 2>/dev/null; then ok "$3"; else bad "$4"; fi; }
# hasE FILE REGEX OK-MSG FAIL-MSG   — extended-regex grep
hasE() { if grep -qE "$2" "$1" 2>/dev/null; then ok "$3"; else bad "$4"; fi; }
# lacksE FILE REGEX OK-MSG FAIL-MSG — must NOT match (negative check)
lacksE(){ if grep -qE "$2" "$1" 2>/dev/null; then bad "$4"; else ok "$3"; fi; }

# --- structure: the advertised surface exists ------------------------------
group "voice — structure"
for _f in \
  "$PLUGIN_DIR/.claude-plugin/plugin.json" \
  "$_HV" "$_MV" "$_SO" "$_REF" \
  "$_AG" "$_HOOK" "$_HANDLER" \
  "$PLUGIN_DIR/commands/voice.md" \
  "$PLUGIN_DIR/README.md"; do
  if [ -f "$_f" ]; then ok "present: $_f"; else bad "MISSING: $_f"; fi
done

# --- clause 1: the partition is per ELEMENT, not per response --------------
group "voice — routing is element-level"
has "$_HV" 'per output element, not per response' \
  "human-voice states the partition is per output element" \
  "human-voice lost the per-ELEMENT partition — a reply mixing prose and a trace now matches both skills at once"
has "$_MV" 'per element, not per response' \
  "machine-voice states the partition is per element" \
  "machine-voice lost the per-ELEMENT partition — the two skills can now claim the same output"
has "$_MV" 'These four bullets are the whole list' \
  "machine-voice keeps the closed-list rule (no generalizing the gate)" \
  "machine-voice lost 'these four bullets are the whole list' — the gate is open-ended again and swallows prose"

# Grepping the sentence is not enough: a fifth bullet can be added while the
# words "four bullets are the whole list" remain verbatim. Count them, and
# assert each one, so widening the gate is what goes red.
_n=$(sed -n '/^This skill governs an output element when it is one of:/,/whole list/p' "$_MV" 2>/dev/null | grep -c '^- ')
if [ "$_n" = "4" ]; then
  ok "the closed list still has exactly 4 bullets"
else
  bad "the closed list has $_n bullets, not 4 — the gate was widened while its 'four bullets' sentence stayed intact"
fi
has "$_MV" 'Agent trace or tool-call log' \
  "closed list keeps the trace/log bullet" \
  "closed list lost the trace/log bullet"
has "$_MV" 'Status line, progress update, handoff note' \
  "closed list keeps the status/progress bullet" \
  "closed list lost the status/progress bullet"
has "$_MV" 'State dump, config, schema, reference card' \
  "closed list keeps the state/config/schema bullet" \
  "closed list lost the state/config/schema bullet"
has "$_MV" 'Structured data block another agent will parse' \
  "closed list keeps the structured-data bullet" \
  "closed list lost the structured-data bullet"

# --- clause 1: the partition is EXHAUSTIVE (explicit out-of-scope) ---------
group "voice — routing is exhaustive"
has "$_HV" 'Out of scope for both skills' \
  "human-voice names the out-of-scope set (code, commit messages, creative writing)" \
  "human-voice lost the out-of-scope block — code and commit messages fall into neither voice with no instruction"
# The carve-out has to be readable from EITHER entry point. A model that routes
# a config to machine-voice must learn there that authored files are exempt;
# stating it only in human-voice leaves that path unguarded.
has "$_MV" 'Out of scope beats the list' \
  "machine-voice restates the out-of-scope carve-out and its precedence" \
  "machine-voice does not mention the out-of-scope set — a model entering via machine-voice would compress an authored config file"
has "$_MV" 'Serving prose beats the list' \
  "machine-voice yields tables that serve surrounding explanation to human-voice" \
  "machine-voice lost the serving-prose rule — a comparison table inside a recommendation matches both skills with no tiebreak"
has "$_HV" 'Out of scope wins over machine-voice' \
  "human-voice states the same precedence from its side" \
  "human-voice lost the out-of-scope precedence statement — the two skills can disagree on an authored config"
has "$_HV" 'commit messages' \
  "human-voice exempts commit messages from styling" \
  "human-voice no longer exempts commit messages — verdict-first formatting would leak into git history"
hasE "$_MV" 'this skill does not apply; follow .human-voice.' \
  "machine-voice hands non-matching elements to human-voice by name" \
  "machine-voice's exit path no longer names human-voice — non-matching output falls through to nothing"

# --- clause 1: one closed tag vocabulary across the three skills -----------
group "voice — confidence vocabulary is closed and shared"
has "$_HV" 'belongs to `second-opinion` alone' \
  "human-voice reserves the conflict glyph for second-opinion alone" \
  "human-voice lost the reserved-glyph carve-out — the tag vocabularies of the two skills now collide"
has "$_MV" 'Vocabulary collision' \
  "machine-voice distinguishes execution-status glyphs from confidence tags" \
  "machine-voice lost the vocabulary-collision warning — status and confidence markers become ambiguous"

# --- clause 2: second-opinion is offer-only --------------------------------
group "voice — second-opinion never runs unbidden"
has "$_SO" 'Never auto-run.' \
  "second-opinion keeps never-auto-run as a standalone statement" \
  "second-opinion lost 'Never auto-run' — the pipeline can fire (and bill) without the user asking"
has "$_HV" 'never invoke it unprompted' \
  "human-voice OFFERS second-opinion rather than invoking it" \
  "human-voice no longer says 'never invoke it unprompted' — it can now order the run second-opinion forbids"
lacksE "$_HV" 'Escalate to' \
  "human-voice does not command escalation" \
  "human-voice says 'Escalate to' — the imperative verb directly contradicts second-opinion's never-auto-run rule"

# --- clause 2: the ungated case must refuse, not simulate ------------------
group "voice — no counterfeit validation"
has "$_SO" 'Name the tool you will call' \
  "second-opinion requires naming the subagent tool first (a positive precondition)" \
  "second-opinion lost the name-the-tool precondition — the environment gate has no detection test again"
has "$_SO" "output format is forbidden" \
  "second-opinion forbids its own output format in the ungated case" \
  "second-opinion no longer forbids emitting its format without dispatching — a fabricated validation now satisfies the letter of the gate"
has "$_SO" 'Counts equal reality.' \
  "second-opinion binds reported counts to calls actually dispatched" \
  "second-opinion lost the counts-equal-reality rule — the delta can report work that never happened"
has "$_SO" 'Never cite a source you have not read.' \
  "second-opinion forbids citing sources no subagent returned" \
  "second-opinion lost the no-invented-sources rule — the dispatched-but-not-returned state is where fabrication happens, and a fake citation is what makes a counterfeit believable"
has "$_SO" 'A plan is not a result.' \
  "second-opinion distinguishes a dispatch plan from findings" \
  "second-opinion lost the plan-is-not-a-result rule — nothing stops it reporting outcomes before any subagent has reported back"
has "$_SO" 'The tell is the structure, not the glyphs.' \
  "second-opinion distinguishes forbidden validation STRUCTURE from legitimate human-voice glyphs" \
  "second-opinion lost the structure-not-glyphs boundary — the forbidden format and ordinary confidence tagging become indistinguishable, so the rule cannot be followed or judged"
has "$_SO" 'Name personas, don' \
  "second-opinion requires personas be named, not counted" \
  "second-opinion lost the name-the-personas rule — a bare number hides over-cap and fabricated runs"

# --- clause 2: the pipeline's budget is internally consistent -------------
group "voice — second-opinion budget is coherent"
has "$_SO" 'Hard cap 6 units' \
  "second-opinion states one countable hard cap" \
  "second-opinion lost its hard cap — the fan-out has no ceiling"
has "$_SO" 'not a second gate' \
  "second-opinion marks the typical advisor count as guidance, not a second threshold" \
  "second-opinion's advisor guidance reads as a cap again — two numbers that can disagree, so a plan can satisfy one and violate the other"
has "$_SO" 'Never one call per claim' \
  "second-opinion batches fact-checking so the cap is reachable" \
  "second-opinion reverted to per-claim fan-out, which blows the cap before any advisor runs"
has "$_SO" 'Cut > Conflict > Flagged > Verified' \
  "second-opinion states group precedence, so merges are deterministic" \
  "second-opinion lost the group precedence order — a claim can land in two groups and two runs disagree"

# --- cross-harness: the hook is a convenience, never a dependency ---------
group "voice — hook degrades gracefully"
has "$_HOOK" 'SessionStart' \
  "hooks.json registers the SessionStart injection" \
  "hooks.json no longer registers SessionStart — the always-on routing rule never loads"
has "$_HOOK" 'startup|clear|compact' \
  "hooks.json re-fires after compaction so routing survives context loss" \
  "hooks.json lost the compact matcher — routing silently disappears after a compaction"
has "$_HANDLER" 'additionalContext' \
  "the handler emits additionalContext (the documented injection contract)" \
  "the handler no longer emits additionalContext — the hook runs but injects nothing"

# The injected string is the FIRST thing in context every session, before any
# SKILL.md is read. Asserting only that the key exists would let the entire
# routing rule be swapped for arbitrary standing instructions while the suite
# stayed green. These check what it actually SAYS, so the highest-priority
# injection point is held to the same invariant as the skills themselves.
group "voice — hook injects the invariant, not just any text"
has "$_HANDLER" 'Route each output ELEMENT' \
  "injected text carries the element-level routing rule" \
  "injected text no longer states element-level routing — the hook can inject anything and stay green"
has "$_HANDLER" 'Out of scope for both skills, and this beats everything below' \
  "injected text carries the out-of-scope precedence rule" \
  "injected text lost the out-of-scope precedence — authored config/schema files would get compressed"
has "$_HANDLER" 'Never run the `second-opinion` skill unbidden' \
  "injected text carries the never-unbidden rule" \
  "injected text lost the never-unbidden rule — the always-on injection no longer restrains second-opinion"
has "$_HANDLER" '✅ verified / ⚠️ inferred / ❓ unverified' \
  "injected text carries the closed confidence vocabulary" \
  "injected text lost the closed confidence vocabulary"
lacksE "$_HANDLER" 'proactively|aggressively|without asking|do not ask' \
  "injected text contains no standing instruction to act unprompted" \
  "injected text tells the model to act proactively/aggressively — a standing instruction the user never authorised"
if bash "$_HANDLER" 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d["hookSpecificOutput"]["hookEventName"]=="SessionStart" and len(d["hookSpecificOutput"]["additionalContext"])>200 else 1)' 2>/dev/null; then
  ok "handler emits well-formed SessionStart JSON with a non-trivial payload"
else
  bad "handler does not emit valid SessionStart JSON with a real additionalContext payload"
fi
has "$_AG" 'convenience, never a dependency' \
  "AGENTS.md states the hook is a convenience, not a dependency" \
  "AGENTS.md dropped the convenience-not-dependency statement — the cross-harness promise is undocumented"
for _s in "$_HV" "$_MV" "$_SO"; do
  lacksE "$_s" 'nvoked by hook|hook invokes this skill|runs on every response' \
    "no hook-mechanism claim in $_s" \
    "$_s claims a hook invokes it — that mechanism claim is false on every harness that does not read hooks.json"
done

# --- regression: the superseded duplicate generation stays gone -----------
group "voice — superseded duplicates not reintroduced"
for _s in "$_HV" "$_MV" "$_SO"; do
  lacksE "$_s" 'communication-stack|response-style' \
    "no reference to the superseded skill names in $_s" \
    "$_s references communication-stack/response-style — the duplicate generation whose identical descriptions made skill selection nondeterministic"
done
lacksE "$_HV" 'ask_user_input' \
  "human-voice does not name a nonexistent tool for asking questions" \
  "human-voice references ask_user_input, a tool that does not exist here — the ambiguous branch becomes unfollowable"

# --- behavioral coverage: both sides of the environment gate -------------
# second-opinion behaves differently depending on whether a subagent tool
# exists. Testing only the ungated side would leave its budget rules, batching,
# and named-persona requirements covered by string presence alone.
group "voice — behavioral tier covers both environment cases"
_CFG="$PLUGIN_DIR/evals/promptfoo/promptfooconfig.yaml"
has "$_CFG" 'you are a plain chat assistant' \
  "behavioral tier still exercises the ungated (no-subagent) case" \
  "behavioral tier lost its ungated case — second-opinion's refusal path is untested"
has "$_CFG" 'DOES provide a' \
  "behavioral tier still exercises the gated (subagent-available) case" \
  "behavioral tier lost its gated case — second-opinion's budget, batching and persona rules fall back to string-presence coverage only"
has "$_PROMPT" 'Your environment: {{environment}}' \
  "the harness parameterises the environment so both cases share one prompt" \
  "the prompt no longer takes an environment variable — the gated tests cannot select their environment"

# --- prose rules a behavioral judge is scored against --------------------
group "voice — human-voice rules are single-valued"
has "$_HV" 'No paragraph exceeds 4 sentences.' \
  "human-voice states one paragraph limit" \
  "human-voice's paragraph limit is no longer single-valued — a judge cannot score it"
has "$_HV" 'first line of the response' \
  "human-voice makes verdict placement text-observable" \
  "human-voice lost the observable verdict-placement predicate"

unset _HV _MV _SO _REF _AG _HOOK _HANDLER _PROMPT _CFG _n _s _f
