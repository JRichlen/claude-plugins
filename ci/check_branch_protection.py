#!/usr/bin/env python3
"""Branch-protection drift guard (winner #15).

Branch protection lives in GitHub settings — invisible to the repo, editable by
anyone with admin, and silently able to drift away from what CI actually emits. A
required check that no job produces blocks every PR forever; a safety path dropped
from the deep-tier filter lets an irreversible-delete change merge without the pier
run. Either way the protection and the workflow disagree and nobody notices.

This guard freezes the contract in `ci/required-checks.json` and asserts, offline,
that every required check name and every deep-tier safety path still appears
verbatim in `.github/workflows/evals.yml`. If a job is renamed or a safety path is
edited without updating the frozen list (or vice versa), the check goes red and the
drift is caught at commit time instead of in production.

It deliberately checks the CI side of the contract — that the workflow still emits
the checks branch protection depends on. Pushing the frozen list *into* GitHub
settings is a privileged, networked action; that belongs in the optional
`apply-branch-protection.sh`, which a human runs, not in an offline eval.

Usage:
  check_branch_protection.py --repo <root>   # verify against that repo's evals.yml
  check_branch_protection.py --self-test
"""
import json
import os
import re
import sys

SPEC_REL = os.path.join("ci", "required-checks.json")
WORKFLOW_REL = os.path.join(".github", "workflows", "evals.yml")


def load_spec(repo_root):
    with open(os.path.join(repo_root, SPEC_REL)) as fh:
        spec = json.load(fh)
    checks = spec.get("required_checks")
    paths = spec.get("deep_safety_paths")
    if not isinstance(checks, list) or not checks:
        raise ValueError("required-checks.json: 'required_checks' must be a non-empty list")
    if not isinstance(paths, list) or not paths:
        raise ValueError("required-checks.json: 'deep_safety_paths' must be a non-empty list")
    return checks, paths


def find_drift(checks, paths, workflow_text):
    """Return the list of frozen strings missing from the workflow text.

    Anchor matches to likely YAML contexts to reduce false positives from comments.
    """
    missing = []
    for c in checks:
        if not re.search(rf"(?m)^[ \t]*name:[ \t]*{re.escape(c)}[ \t]*$", workflow_text):
            missing.append(c)
    for p in paths:
        if not re.search(rf"['\"]{re.escape(p)}['\"]", workflow_text):
            missing.append(p)
    return missing


def check_repo(repo_root):
    """Return (ok, messages) for a real repo tree."""
    msgs = []
    checks, paths = load_spec(repo_root)
    wf_path = os.path.join(repo_root, WORKFLOW_REL)
    if not os.path.exists(wf_path):
        # No workflow to protect (e.g. a synthetic root) — nothing to drift against.
        msgs.append(f"no {WORKFLOW_REL} present — branch-protection check inert here")
        return True, msgs
    with open(wf_path) as fh:
        text = fh.read()
    missing = find_drift(checks, paths, text)
    if missing:
        msgs.append("branch-protection drift: these frozen strings are missing from "
                    f"{WORKFLOW_REL}:")
        msgs.extend(f"    - {m}" for m in missing)
        return False, msgs
    msgs.append(f"branch protection in sync: {len(checks)} checks + {len(paths)} "
                "safety paths all present in the workflow")
    return True, msgs


def _self_test():
    passed = True

    def check(name, cond):
        nonlocal passed
        print(f"  {'PASS' if cond else 'FAIL'} {name}")
        passed = passed and cond

    checks = ["cheap tier (deterministic, offline)", "deep tier (pier)"]
    paths = ["evals/pier/**"]

    # In-sync workflow: every frozen string present → no drift.
    in_sync = "jobs:\n  a:\n    name: cheap tier (deterministic, offline)\n" \
              "  b:\n    name: deep tier (pier)\n    paths: [evals/pier/**]\n"
    check("in-sync workflow reports no drift", find_drift(checks, paths, in_sync) == [])

    # Renamed check → that string is flagged.
    renamed = in_sync.replace("deep tier (pier)", "deep tier (renamed)")
    drift = find_drift(checks, paths, renamed)
    check("renamed check is caught", drift == ["deep tier (pier)"])

    # Dropped safety path → flagged.
    dropped = in_sync.replace("evals/pier/**", "evals/other/**")
    check("dropped safety path is caught", find_drift(checks, paths, dropped) == ["evals/pier/**"])

    # Malformed spec raises rather than passing silently.
    try:
        load_spec_from({"required_checks": [], "deep_safety_paths": ["x"]})
        check("empty required_checks raises", False)
    except ValueError:
        check("empty required_checks raises", True)

    print("self-test:", "OK" if passed else "FAILED")
    return 0 if passed else 1


def load_spec_from(spec):
    """Validation half of load_spec, for self-test without touching disk."""
    checks = spec.get("required_checks")
    paths = spec.get("deep_safety_paths")
    if not isinstance(checks, list) or not checks:
        raise ValueError("required_checks must be a non-empty list")
    if not isinstance(paths, list) or not paths:
        raise ValueError("deep_safety_paths must be a non-empty list")
    return checks, paths


def main(argv):
    if "--self-test" in argv:
        return _self_test()
    if "--repo" in argv:
        repo_root = argv[argv.index("--repo") + 1]
        ok, msgs = check_repo(repo_root)
        for line in msgs:
            print(f"  {line}")
        return 0 if ok else 1
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
