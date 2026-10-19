#!/bin/bash
set -eu

# TEST HOSTED CONDA SH
#
# Verify that the hosted (anaconda.org) EMEWS conda packages solve
# into a correct environment, WITHOUT actually installing anything.
#
# This reproduces, via dry-run solves, the package resolution that a
# real `install_emews.sh` run performs on each Python version, and
# checks that the resolved packages are the fixed ones -- not an old
# build that would reintroduce a known bug.
#
# Background (see dev/conda/claude-transcript.adoc notes 14-19d):
#  - emews-r must resolve to >= 9      (gfortran / FLIBS fix)
#  - tk must resolve to >= 8.6.15      (avoids the 8.6.13 strstr crash)
#  - tk must stay < 9.0a0              (Turbine links libtcl8.6)
#
# Created 2026-10-14 19:55:00 .
#
# Usage:
#   test_hosted_conda.sh [-h] [-p "3.11 3.12 ..."] [-e EQ_R_VER]
#
# Options:
#   -h          show this help and exit
#   -p LIST     space-separated Python versions to test
#               (default: "3.11 3.12 3.13 3.14")
#   -e VERSION  EQ/R version to request (default: 1.3)
#
# Exit status: 0 if every checked solve passed, 1 otherwise.

# ------------------------------------------------------------------
# Defaults
# ------------------------------------------------------------------

PY_VERSIONS="3.11 3.12 3.13 3.14"
EQ_R_VERSION=1.3

# Channels, in priority order, matching install_emews.sh:
CHANNELS=(-c conda-forge -c swift-t)

# Minimum acceptable versions / bounds to assert:
MIN_EMEWS_R=9
MIN_TK=8.6.15
# tk must be strictly below this (Tcl 9 exclusion):
TK_CEILING=9.0a0

help()
{
  # Print the header comment block as help text.
  sed -n '3,30p' "$0" | sed 's/^# \{0,1\}//'
}

# ------------------------------------------------------------------
# Option parsing
# ------------------------------------------------------------------

while getopts ":hp:e:" option
do
  case $option in
    h) help ; exit 0           ;;
    p) PY_VERSIONS=$OPTARG      ;;
    e) EQ_R_VERSION=$OPTARG     ;;
    \?)
      echo "Unknown option: -$OPTARG"
      help
      exit 1                    ;;
  esac
done

# ------------------------------------------------------------------
# Preconditions
# ------------------------------------------------------------------

if ! command -v conda > /dev/null
then
  echo "Error: conda not found on PATH."
  echo "Activate a conda base environment first."
  exit 1
fi

# Keep each test's package cache isolated and out of the shared
# user cache, so a dry-run here never touches a real build's cache
# (see transcript note 12 on shared-cache corruption).  Put it in
# PWD so it is easy to find and clean up.
WORK_CACHE=$PWD/test-hosted-cache
mkdir -p "$WORK_CACHE"

# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

# version_ge A B : true (0) if version A >= version B.
# Uses sort -V so it understands dotted versions.
version_ge()
{
  local a=$1 b=$2
  [[ $a == "$b" ]] && return 0
  local first
  first=$(printf '%s\n%s\n' "$a" "$b" | sort -V | head -1)
  # A >= B iff B sorts first (is the smaller one).
  [[ $first == "$b" ]]
}

# solve_one PYVER : run one dry-run solve, emit the resolved
# packages for the names we care about, one "name version" per line.
solve_one()
{
  local pyver=$1
  CONDA_PKGS_DIRS=$WORK_CACHE/$pyver \
    conda create --dry-run --json --quiet \
      -n "_test_$pyver" \
      "${CHANNELS[@]}" \
      "python=$pyver" \
      "eq-r=$EQ_R_VERSION" \
      "emews-r>=$MIN_EMEWS_R" \
    2>/dev/null
}

# Overall result accumulator:
FAILURES=0

# ------------------------------------------------------------------
# Main loop
# ------------------------------------------------------------------

echo "Testing hosted EMEWS conda packages (dry-run solves)."
echo "Channels: ${CHANNELS[*]}"
echo "EQ/R: $EQ_R_VERSION   Python: $PY_VERSIONS"
echo

for PY in $PY_VERSIONS
do
  echo "=== Python $PY ==="

  # Run the solve; capture JSON.  A failed solve is itself a failure.
  if ! JSON=$(solve_one "$PY")
  then
    echo "  [FAIL] solve failed (unsatisfiable or error)"
    FAILURES=$(( FAILURES + 1 ))
    echo
    continue
  fi

  # Extract "name version build" for the packages of interest.
  # The dry-run JSON lists them under .actions.LINK[].
  REPORT=$(
    echo "$JSON" | python3 -c '
import json, sys
d = json.load(sys.stdin)
link = d.get("actions", {}).get("LINK", [])
want = ("emews-r", "eq-r", "swift-t-r", "tk")
for p in link:
    if p["name"] in want:
        print(p["name"], p["version"], p.get("build_string",
                                             p.get("build", "")))
'
  )

  # Pull individual versions out of the report.
  emews_r_ver=$(echo "$REPORT" | awk '$1=="emews-r"    {print $2}')
  tk_ver=$(echo      "$REPORT" | awk '$1=="tk"         {print $2}')
  swift_t_r=$(echo   "$REPORT" | awk '$1=="swift-t-r"  {print $2, $3}')
  eq_r=$(echo        "$REPORT" | awk '$1=="eq-r"       {print $2, $3}')

  echo "  resolved: eq-r $eq_r | swift-t-r $swift_t_r"
  echo "            emews-r $emews_r_ver | tk $tk_ver"

  ok=1

  # Check emews-r >= MIN_EMEWS_R
  if [[ -z $emews_r_ver ]]
  then
    echo "  [FAIL] emews-r not in solve"
    ok=0
  elif ! version_ge "$emews_r_ver" "$MIN_EMEWS_R"
  then
    echo "  [FAIL] emews-r $emews_r_ver < $MIN_EMEWS_R"
    ok=0
  fi

  # Check tk floor: tk >= MIN_TK
  if [[ -z $tk_ver ]]
  then
    echo "  [FAIL] tk not in solve"
    ok=0
  else
    if ! version_ge "$tk_ver" "$MIN_TK"
    then
      echo "  [FAIL] tk $tk_ver < $MIN_TK (strstr-bug risk)"
      ok=0
    fi
    # Check tk ceiling: tk < TK_CEILING (no Tcl 9)
    if version_ge "$tk_ver" "$TK_CEILING"
    then
      echo "  [FAIL] tk $tk_ver >= $TK_CEILING (Tcl 9 linking risk)"
      ok=0
    fi
  fi

  if (( ok ))
  then
    echo "  [PASS]"
  else
    FAILURES=$(( FAILURES + 1 ))
  fi
  echo
done

# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------

if (( FAILURES == 0 ))
then
  echo "ALL PASS."
  exit 0
else
  echo "FAILURES: $FAILURES"
  exit 1
fi
