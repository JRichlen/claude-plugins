#!/usr/bin/env python3
"""Delta gate (winner #4) — score a skill by its LIFT over a baseline.

A skill is only worth shipping if a model *given the skill* beats the same model
without it (or the prior version of it). This gate reads a `benchmark.json` as
produced by the wrapped skill-creator's `aggregate_benchmark.py` and reports the
lift: with-skill pass rate minus baseline pass rate.

ADVISORY-ONLY FOR ONE RELEASE. The gate prints the delta and a would-block
verdict but always exits 0. Real benchmarks are noisy, and gating the repo on an
uncalibrated threshold would wall off good changes before we've watched the delta
behave on live data. Flip `MODE` to "blocking" only as a later, deliberate change
once the threshold has earned its keep. This lives in the aggregation + CI step,
never inside the per-run loop — gating a single noisy iteration would make the
loop thrash rather than converge.

Usage:
  delta_gate.py <benchmark.json> [--threshold FLOAT]
  delta_gate.py --self-test

The `benchmark.json` contract (confirmed against upstream aggregate_benchmark.py):
  run_summary:
    <skill-config>:    { pass_rate: { mean, stddev, min, max }, ... }
    <baseline-config>: { pass_rate: { mean, ... }, ... }
    delta:             { pass_rate: "+0.25" }   # primary - baseline, preformatted
Config names are discovered dynamically; skill configs contain with_skill/new_skill,
baselines contain without_skill/old_skill/no_skill/baseline. When the named configs
aren't both present we fall back to the preformatted `delta.pass_rate` string.
"""
import json
import sys

MODE = "advisory"  # advisory | blocking  — SHIPS ADVISORY FOR ONE RELEASE
DEFAULT_THRESHOLD = 0.0  # lift must exceed this to be a "would-pass"

SKILL_MARKERS = ("with_skill", "new_skill")
BASELINE_MARKERS = ("without_skill", "old_skill", "no_skill", "baseline")


def _mean(cfg):
    """pass_rate.mean out of a run_summary config block, or None."""
    if not isinstance(cfg, dict):
        return None
    pr = cfg.get("pass_rate")
    if isinstance(pr, dict) and isinstance(pr.get("mean"), (int, float)):
        return float(pr["mean"])
    if isinstance(pr, (int, float)):
        return float(pr)
    return None


def _find(summary, markers):
    """First config whose name matches any marker, returned as (name, mean)."""
    for name, cfg in summary.items():
        if name == "delta":
            continue
        low = name.lower()
        if any(m in low for m in markers):
            m = _mean(cfg)
            if m is not None:
                return name, m
    return None, None


def compute_lift(bench):
    """Return (lift, how) where how explains which path produced the number.

    Prefers named configs (skill.mean - baseline.mean); falls back to the
    preformatted delta.pass_rate string. Raises ValueError if neither is usable.
    """
    summary = bench.get("run_summary")
    if not isinstance(summary, dict):
        raise ValueError("benchmark.json has no run_summary object")

    skill_name, skill_mean = _find(summary, SKILL_MARKERS)
    base_name, base_mean = _find(summary, BASELINE_MARKERS)
    if skill_mean is not None and base_mean is not None:
        return skill_mean - base_mean, f"means: {skill_name} - {base_name}"

    delta = summary.get("delta")
    if isinstance(delta, dict) and delta.get("pass_rate") is not None:
        try:
            return float(str(delta["pass_rate"]).replace("+", "")), "delta.pass_rate fallback"
        except ValueError:
            pass
    raise ValueError(
        "could not resolve lift: no with/without configs and no numeric delta.pass_rate"
    )


def report(bench, threshold=DEFAULT_THRESHOLD):
    """Print the verdict. Returns the exit code the gate WOULD use if blocking."""
    lift, how = compute_lift(bench)
    would_pass = lift > threshold
    verdict = "would-PASS" if would_pass else "would-BLOCK"
    print(f"delta gate: MODE={MODE.upper()}")
    print(f"  lift = {lift:+.4f}  (threshold {threshold:+.4f}, via {how})")
    print(f"  verdict: {verdict}")
    if MODE == "advisory":
        print("  advisory — reporting only, not blocking this release.")
    return 0 if would_pass else 1


def _self_test():
    ok = True

    def check(name, cond):
        nonlocal ok
        print(f"  {'PASS' if cond else 'FAIL'} {name}")
        ok = ok and cond

    # The gate must be advisory for this release.
    check("MODE is advisory", MODE == "advisory")

    # Named-config path: lift = 0.80 - 0.55 = +0.25.
    named = {"run_summary": {
        "with_skill": {"pass_rate": {"mean": 0.80}},
        "without_skill": {"pass_rate": {"mean": 0.55}},
        "delta": {"pass_rate": "+0.25"},
    }}
    lift, how = compute_lift(named)
    check("named configs give +0.25 lift", abs(lift - 0.25) < 1e-9 and "means" in how)

    # Fallback path: no with/without configs, only a preformatted delta.
    fb = {"run_summary": {"delta": {"pass_rate": "-0.10"}}}
    lift, how = compute_lift(fb)
    check("delta.pass_rate fallback gives -0.10", abs(lift + 0.10) < 1e-9 and "fallback" in how)

    # Advisory must exit 0 even when the lift is negative (would-block).
    neg = {"run_summary": {
        "new_skill": {"pass_rate": {"mean": 0.30}},
        "old_skill": {"pass_rate": {"mean": 0.60}},
    }}
    check("negative lift still exits 0 while advisory", report(neg) == 1 and MODE == "advisory")

    # Malformed input raises rather than silently passing.
    try:
        compute_lift({"run_summary": {}})
        check("empty run_summary raises", False)
    except ValueError:
        check("empty run_summary raises", True)

    print("self-test:", "OK" if ok else "FAILED")
    return 0 if ok else 1


def main(argv):
    if "--self-test" in argv:
        return _self_test()
    args = [a for a in argv if not a.startswith("--")]
    threshold = DEFAULT_THRESHOLD
    if "--threshold" in argv:
        threshold = float(argv[argv.index("--threshold") + 1])
        args = [a for a in args if a != argv[argv.index("--threshold") + 1]]
    if not args:
        print(__doc__)
        return 2
    with open(args[0]) as fh:
        bench = json.load(fh)
    would = report(bench, threshold)
    # Advisory: always green regardless of the would-block verdict.
    return 0 if MODE == "advisory" else would


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
