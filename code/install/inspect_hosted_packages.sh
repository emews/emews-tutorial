#!/bin/bash
set -eu

# INSPECT HOSTED PACKAGES SH
#
# Download the *.conda artifacts that would actually be installed
# from the hosted (anaconda.org) swift-t channel, and inspect their
# embedded metadata directly -- not just what a dry-run solve says
# is resolvable, but what each package really contains and depends
# on.  This catches cases where a fix was edited and rendered
# locally but never rebuilt/republished (the published artifact
# still has the old, broken metadata).
#
# For eq-r and swift-t-r this checks the "depends" pin on tk and
# emews-r recorded in info/index.json.  For swift-t-r it also pulls
# the component versions that "swift-t -v" would report at runtime
# (turbine/stc versions, build source commit) straight out of the
# package payload, so there is no need to actually install anything.
#
# Complements test_hosted_conda.sh, which only checks that a dry-run
# *solve* picks acceptable versions.  This script checks the
# artifacts themselves.
#
# Background (see dev/conda/claude-transcript.adoc notes 14-19d):
#  - emews-r must resolve to >= 9      (gfortran / FLIBS fix)
#  - tk must resolve to >= 8.6.15      (avoids the 8.6.13 strstr bug)
#  - tk must stay < 9.0a0              (Turbine links libtcl8.6)
#  - eq-r's own tk pin must carry the same floor AND ceiling, not
#    just the floor (note 19/19a: a missing ceiling let the solver
#    pick a broken/mismatched tk downstream).
#
# Requires: curl, unzip, zstd, tar, python3, conda (for the solve
# that picks exact build strings).
#
# Created 2026-10-15 16:35:00 .
#
# Usage:
#   inspect_hosted_packages.sh [-h] [-p "3.11 3.12 ..."]
#                              [-e EQ_R_VERSION] [-k]
#
# Options:
#   -h          show this help and exit
#   -p LIST     space-separated Python versions to check
#               (default: "3.11 3.12 3.13 3.14")
#   -e VERSION  EQ/R version to request (default: 1.3)
#   -k          keep the downloaded packages / scratch dir
#               (default: clean up on exit)
#
# Exit status: 0 if every checked package passed, 1 otherwise.

# ------------------------------------------------------------------
# Defaults
# ------------------------------------------------------------------

PY_VERSIONS="3.11 3.12 3.13 3.14"
EQ_R_VERSION=1.3
KEEP=0

CHANNEL=swift-t
CHANNEL_URL=https://conda.anaconda.org/$CHANNEL
CHANNELS=(-c conda-forge -c $CHANNEL)

MIN_EMEWS_R=9
MIN_TK=8.6.15
TK_CEILING=9.0a0

help()
{
  sed -n '3,41p' "$0" | sed 's/^# \{0,1\}//'
}

# ------------------------------------------------------------------
# Option parsing
# ------------------------------------------------------------------

while getopts ":hp:e:k" option
do
  case $option in
    h) help ; exit 0           ;;
    p) PY_VERSIONS=$OPTARG      ;;
    e) EQ_R_VERSION=$OPTARG     ;;
    k) KEEP=1                   ;;
    \?)
      echo "Unknown option: -$OPTARG"
      help
      exit 1                    ;;
  esac
done

# ------------------------------------------------------------------
# Preconditions
# ------------------------------------------------------------------

for TOOL in conda curl unzip zstd tar python3
do
  if ! command -v $TOOL > /dev/null
  then
    echo "Error: required tool not found on PATH: $TOOL"
    exit 1
  fi
done

WORK=$PWD/hosted-pkg-inspect
mkdir -p "$WORK"
cleanup()
{
  if (( ! KEEP ))
  then
    rm -rf "$WORK"
  fi
}
trap cleanup EXIT

# version_ge A B : true (0) if version A >= version B.
version_ge()
{
  local a=$1 b=$2
  [[ $a == "$b" ]] && return 0
  local first
  first=$(printf '%s\n%s\n' "$a" "$b" | sort -V | head -1)
  [[ $first == "$b" ]]
}

# solve_dists PYVER : dry-run solve, print "name dist_name" lines
# for the packages of interest (from the swift-t channel's JSON
# LINK action), so we know exactly which artifact to download.
solve_dists()
{
  local pyver=$1
  local cache=$WORK/solve-cache/$pyver
  mkdir -p "$cache"
  CONDA_PKGS_DIRS=$cache \
    conda create --dry-run --json --quiet \
      -n "_inspect_$pyver" \
      "${CHANNELS[@]}" \
      "python=$pyver" \
      "eq-r=$EQ_R_VERSION" \
      "emews-r>=$MIN_EMEWS_R" \
    2>/dev/null \
  | python3 -c '
import json, sys
d = json.load(sys.stdin)
link = d.get("actions", {}).get("LINK", [])
want = ("emews-r", "eq-r", "swift-t-r", "tk")
for p in link:
    if p["name"] in want:
        print(p["name"], p["dist_name"])
'
}

# fetch_conda DIST_NAME DEST : download a .conda artifact by its
# dist name (e.g. "eq-r-1.3-py313_3") from the swift-t channel.
fetch_conda()
{
  local dist=$1 dest=$2
  curl -sL -f -o "$dest" \
    "$CHANNEL_URL/osx-arm64/$dist.conda"
}

# index_json CONDA_FILE : print the info/index.json of a .conda
# artifact to stdout, without leaving extracted files behind.
index_json()
{
  local f=$1
  local dist
  dist=$(basename "$f" .conda)
  unzip -p "$f" "info-$dist.tar.zst" \
    | zstd -dc \
    | tar -xO -f - info/index.json
}

# swift_t_r_versions CONDA_FILE : print embedded component
# versions ("swift-t -v" would report these at runtime) by pulling
# the relevant files straight out of the package payload.
swift_t_r_versions()
{
  local f=$1
  local dist
  dist=$(basename "$f" .conda)
  local pkgtar="pkg-$dist.tar.zst"
  local turbine stc_for_turbine stc source

  # etc/{version,turbine-version,stc-version}.txt are symlinks into
  # swift-t/{turbine,stc}/etc/ -- "tar -xO" can't dump a symlink's
  # content, so read the real files directly.
  turbine=$(
    unzip -p "$f" "$pkgtar" | zstd -dc \
      | tar -xO -f - swift-t/turbine/etc/version.txt 2>/dev/null
  )
  stc=$(
    unzip -p "$f" "$pkgtar" | zstd -dc \
      | tar -xO -f - swift-t/stc/etc/version.txt 2>/dev/null
  )
  stc_for_turbine=$(
    unzip -p "$f" "$pkgtar" | zstd -dc \
      | tar -xO -f - swift-t/stc/etc/turbine-version.txt 2>/dev/null
  )
  source=$(
    unzip -p "$f" "$pkgtar" | zstd -dc \
      | tar -xO -f - swift-t/turbine/etc/source.txt 2>/dev/null
  )
  echo "    turbine: $turbine  stc: $stc  (stc built for turbine $stc_for_turbine)"
  echo "    source:  $source"
}

# dep_bound DEPENDS_JSON NAME : print the raw dependency spec
# string for NAME out of an index.json "depends" array.
dep_spec()
{
  local json=$1 name=$2
  echo "$json" | python3 -c '
import json, sys
name = sys.argv[1]
d = json.load(sys.stdin)
for dep in d.get("depends", []):
    if dep.split()[0] == name:
        print(dep)
        break
' "$name"
}

# tk_bounds_ok SPEC : check a tk dependency spec string carries
# both the floor and the ceiling we require.  Prints a verdict and
# returns non-zero on failure.
tk_bounds_ok()
{
  local spec=$1
  local ok=1

  if [[ -z $spec ]]
  then
    echo "    [FAIL] tk not in depends at all"
    return 1
  fi

  # Pull floor/ceiling numbers out of e.g. "tk >=8.6.15,<9.0a0".
  local floor ceiling
  floor=$(echo "$spec" \
    | sed -nE 's/.*>=([0-9][0-9a-zA-Z.]*).*/\1/p')
  ceiling=$(echo "$spec" \
    | sed -nE 's/.*<([0-9][0-9a-zA-Z.]*).*/\1/p')

  if [[ -z $floor ]] || ! version_ge "$floor" "$MIN_TK"
  then
    echo "    [FAIL] tk floor missing/too low: '$spec'"
    ok=0
  fi

  if [[ -z $ceiling ]]
  then
    echo "    [FAIL] tk has NO ceiling: '$spec'" \
         "(Tcl 9 linking risk, see note 19c)"
    ok=0
  elif ! version_ge "$TK_CEILING" "$ceiling"
  then
    echo "    [FAIL] tk ceiling too loose: '$spec'" \
         "(allows >= $TK_CEILING)"
    ok=0
  fi

  (( ok )) && echo "    [ok] tk pin: '$spec'"
  (( ok ))
}

# ------------------------------------------------------------------
# Main loop
# ------------------------------------------------------------------

FAILURES=0

echo "Inspecting hosted packages from $CHANNEL_URL"
echo "EQ/R: $EQ_R_VERSION   Python: $PY_VERSIONS"
echo

for PY in $PY_VERSIONS
do
  PYTAG=py$(echo "$PY" | tr -d .)
  echo "=== Python $PY ==="

  DISTS=$(solve_dists "$PY") || DISTS=""
  if [[ -z $DISTS ]]
  then
    echo "  [FAIL] could not resolve a solve for $PY"
    FAILURES=$(( FAILURES + 1 ))
    echo
    continue
  fi

  EQ_R_DIST=$(echo "$DISTS" | awk '$1=="eq-r"       {print $2}')
  SWIFT_T_R_DIST=$(echo "$DISTS" \
                     | awk '$1=="swift-t-r" {print $2}')
  EMEWS_R_DIST=$(echo "$DISTS" \
                   | awk '$1=="emews-r"     {print $2}')

  PKG_OK=1

  for PAIR in "eq-r:$EQ_R_DIST" "swift-t-r:$SWIFT_T_R_DIST" \
              "emews-r:$EMEWS_R_DIST"
  do
    NAME=${PAIR%%:*}
    DIST=${PAIR#*:}
    if [[ -z $DIST ]]
    then
      echo "  [FAIL] $NAME: not resolved"
      PKG_OK=0
      continue
    fi

    DEST=$WORK/$DIST.conda
    echo "  $NAME: $DIST"
    if ! fetch_conda "$DIST" "$DEST"
    then
      echo "    [FAIL] download failed for $DIST"
      PKG_OK=0
      continue
    fi

    JSON=$(index_json "$DEST")

    if [[ $NAME == "eq-r" ]]
    then
      SPEC=$(dep_spec "$JSON" tk)
      tk_bounds_ok "$SPEC" || PKG_OK=0
      SPEC_R=$(dep_spec "$JSON" swift-t-r)
      echo "    depends on: $SPEC_R"
    fi

    if [[ $NAME == "swift-t-r" ]]
    then
      SPEC=$(dep_spec "$JSON" tk)
      tk_bounds_ok "$SPEC" || PKG_OK=0
      SPEC_E=$(dep_spec "$JSON" emews-r)
      if [[ -z $SPEC_E ]]
      then
        echo "    [FAIL] emews-r not in depends"
        PKG_OK=0
      else
        FLOOR=$(echo "$SPEC_E" \
          | sed -nE 's/.*>=([0-9][0-9a-zA-Z.]*).*/\1/p')
        if [[ -z $FLOOR ]] \
             || ! version_ge "$FLOOR" "$MIN_EMEWS_R"
        then
          echo "    [FAIL] emews-r pin too low: '$SPEC_E'"
          PKG_OK=0
        else
          echo "    [ok] emews-r pin: '$SPEC_E'"
        fi
      fi
      swift_t_r_versions "$DEST"
    fi

    if [[ $NAME == "emews-r" ]]
    then
      VER=$(echo "$JSON" | python3 -c '
import json, sys
print(json.load(sys.stdin)["version"])
')
      if ! version_ge "$VER" "$MIN_EMEWS_R"
      then
        echo "    [FAIL] emews-r version $VER < $MIN_EMEWS_R"
        PKG_OK=0
      else
        echo "    [ok] emews-r version: $VER"
      fi
    fi
  done

  if (( PKG_OK ))
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
