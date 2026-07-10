#!/usr/bin/env python3
"""Baseline-integrity + iteration-budget guard (winner #14).

Two ways the iterate-on-a-skill loop lies to itself, both checkable offline:

1. CONTAMINATION — the baseline run accidentally saw the skill. If the "no-skill"
   config actually pointed at the skill (a leaked path), or both configs point at
   the SAME skill, then the measured lift is fiction: you're comparing a skill to
   itself. The guard flags a baseline config that carries a skill path, or two
   configs sharing one skill path.

2. STUCK BUDGET — the loop is open-ended, so it needs a written ceiling. `STUCK.md`
   carries `budget_remaining`; once it hits 0 the loop must escalate to a human
   instead of spending forever. `--stuck` reads that number and exits non-zero at 0.

Usage:
  check_baseline_integrity.py --benchmark <benchmark.json>   # contamination
  check_baseline_integrity.py --stuck <STUCK.md>             # budget exhaustion
  check_baseline_integrity.py --self-test

Contamination reads `runs[]` (or `configs[]`) entries of the form
  { "config": "<name>", "skill_path": "<path or null>" }
Baseline configs are named without_skill/old_skill/no_skill/baseline; a skill
config is anything else with a non-empty skill_path. When no skill-path metadata
is present at all, the check reports that it couldn't verify (exit 0) rather than
inventing a verdict.
"""
import json
import re
import sys

BASELINE_MARKERS = ("without_skill", "old_skill", "no_skill", "baseline")


def _entries(bench):
    for key in ("runs", "configs"):
        v = bench.get(key)
        if isinstance(v, list):
            return v
    return []


def check_contamination(bench):
    """Return (ok, messages). ok=False means the baseline is contaminated."""
    msgs = []
    entries = _entries(bench)
    with_path = [(e.get("config", ""), e.get("skill_path"))
                 for e in entries if isinstance(e, dict) and e.get("skill_path")]
    if not with_path:
        msgs.append("no skill-path metadata in benchmark — cannot verify contamination")
        return True, msgs

    ok = True
    # A baseline config must carry NO skill path.
    for name, path in with_path:
        if any(m in name.lower() for m in BASELINE_MARKERS):
            msgs.append(f"CONTAMINATED: baseline config '{name}' carries skill_path '{path}'")
            ok = False

    # No two configs may share the same skill path.
    seen = {}
    for name, path in with_path:
        if path in seen and seen[path] != name:
            msgs.append(f"CONTAMINATED: configs '{seen[path]}' and '{name}' share skill_path '{path}'")
            ok = False
        seen[path] = name

    if ok:
        msgs.append("baseline clean: no baseline config references a skill, no shared skill paths")
    return ok, msgs


def check_stuck(text):
    """Return (ok, remaining, messages). ok=False means the budget is exhausted."""
    m = re.search(r"budget_remaining:\s*(-?\d+)", text)
    if not m:
        return False, None, ["no 'budget_remaining:' line found in STUCK.md"]
    remaining = int(m.group(1))
    if remaining <= 0:
        return False, remaining, [f"budget exhausted (remaining={remaining}) — escalate to a human, do not top up"]
    return True, remaining, [f"budget ok (remaining={remaining})"]


def _emit(ok, msgs):
    for line in msgs:
        print(f"  {line}")
    return 0 if ok else 1


def _self_test():
    passed = True

    def check(name, cond):
        nonlocal passed
        print(f"  {'PASS' if cond else 'FAIL'} {name}")
        passed = passed and cond

    # Clean: baseline has no skill path, skill config has its own.
    clean = {"runs": [
        {"config": "with_skill", "skill_path": "skills/foo/SKILL.md"},
        {"config": "without_skill", "skill_path": None},
    ]}
    ok, _ = check_contamination(clean)
    check("clean baseline passes", ok)

    # Contaminated: baseline carries a skill path.
    leaked = {"runs": [
        {"config": "with_skill", "skill_path": "skills/foo/SKILL.md"},
        {"config": "without_skill", "skill_path": "skills/foo/SKILL.md"},
    ]}
    ok, _ = check_contamination(leaked)
    check("leaked baseline path is caught", not ok)

    # Shared path across two non-baseline configs.
    shared = {"runs": [
        {"config": "new_skill", "skill_path": "skills/foo/SKILL.md"},
        {"config": "variant_a", "skill_path": "skills/foo/SKILL.md"},
    ]}
    ok, _ = check_contamination(shared)
    check("shared skill path is caught", not ok)

    # No metadata → cannot verify, but does not falsely fail.
    ok, _ = check_contamination({"runs": [{"config": "with_skill"}]})
    check("missing metadata does not false-fail", ok)

    # Budget: positive ok, zero/negative exhausted.
    ok, rem, _ = check_stuck("budget_remaining: 3")
    check("positive budget ok", ok and rem == 3)
    ok, rem, _ = check_stuck("budget_remaining: 0")
    check("zero budget exhausted", not ok and rem == 0)
    ok, _, _ = check_stuck("no budget line here")
    check("missing budget line fails closed", not ok)

    print("self-test:", "OK" if passed else "FAILED")
    return 0 if passed else 1


def main(argv):
    if "--self-test" in argv:
        return _self_test()
    if "--benchmark" in argv:
        path = argv[argv.index("--benchmark") + 1]
        with open(path) as fh:
            ok, msgs = check_contamination(json.load(fh))
        return _emit(ok, msgs)
    if "--stuck" in argv:
        path = argv[argv.index("--stuck") + 1]
        with open(path) as fh:
            ok, _, msgs = check_stuck(fh.read())
        return _emit(ok, msgs)
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
