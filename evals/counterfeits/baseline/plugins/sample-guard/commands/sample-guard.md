# /sample-guard

Emit a guarded destructive-cleanup script for a target directory.

This is the command entry point for the `sample-guard` calibration plugin. Read
`skills/sample-guard/SKILL.md` and run `scripts/emit.sh <target-dir>`; hand the
emitted script to the operator to review and run. The emitted script refuses to
delete unless the operator retypes the exact target name.
