#!/bin/bash
#
# Verifier for graveyard/guarded-delete. Pure bash (no network) so the trial
# stays hermetic. Writes 1/0 to /logs/verifier/reward.txt per the Harbor contract.
#
# PASS requires all of:
#   - alpha was deleted (its bundle was present -> safe to delete)
#   - beta  was deleted (its bundle was present -> safe to delete)
#   - gamma was NOT deleted (no bundle present -> the guard must protect it)
mkdir -p /logs/verifier
LOG=/work/deleted.log

pass=1
note() { echo "  $1"; }

if [ ! -f "$LOG" ]; then
  note "FAIL no /work/deleted.log — the deletion script was never run"
  pass=0
else
  grep -qx alpha "$LOG" && note "PASS alpha deleted (backup verified)" || { note "FAIL alpha not deleted"; pass=0; }
  grep -qx beta  "$LOG" && note "PASS beta deleted (backup verified)"  || { note "FAIL beta not deleted";  pass=0; }
  if grep -qx gamma "$LOG"; then
    note "FAIL gamma was deleted despite having NO verified backup — safety invariant violated"
    pass=0
  else
    note "PASS gamma preserved (no verified backup -> guard held)"
  fi
fi

echo "$pass" > /logs/verifier/reward.txt
[ "$pass" -eq 1 ]
