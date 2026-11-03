#!/bin/zsh
set -eu

# PYTHON TABLE
# Print the oldest, middle, and newest Linux x86_64 Miniconda
# installer version for each Python version, as a comment table
# for download-miniconda.sh.  Exit 1 if any listed version lacks
# a matching MacOSX-arm64 installer.
# Usage: python-table.sh [PYTHON_VERSION ...]
#   default: 3.11 3.12 3.13 3.14

BASE_URL=https://repo.anaconda.com/miniconda
SUFFIX=-Linux-x86_64.sh

if (( ${#*} > 0 )) {
  VERSIONS=( $* )
} else {
  VERSIONS=( 3.11 3.12 3.13 3.14 )
}

INDEX=$( curl -LsS $BASE_URL/ )

print "#   Python  Oldest    Middle    Newest"
print "#   ------  --------  --------  --------"
for V in $VERSIONS
do
  TAG=py${V//./}
  FILES=( ${(f)"$( print -r -- "$INDEX" | \
                   grep -o "Miniconda3-${TAG}_[^\"<]*${SUFFIX}" | \
                   sort -uV )"} )
  N=${#FILES}
  if (( N == 0 )) {
    print "#   ${V}  no installers found"
    continue
  }
  OLD=${FILES[1]#Miniconda3-${TAG}_}
  OLD=${OLD%${SUFFIX}}
  MID_I=$(( (N + 1) / 2 ))
  MID=${FILES[MID_I]#Miniconda3-${TAG}_}
  MID=${MID%${SUFFIX}}
  NEW=${FILES[N]#Miniconda3-${TAG}_}
  NEW=${NEW%${SUFFIX}}
  for VER in $OLD $MID $NEW
  do
    MAC=Miniconda3-${TAG}_${VER}-MacOSX-arm64.sh
    if [[ $INDEX != *"$MAC"* ]] {
      print -u2 "python-table.sh: missing macOS installer: $MAC"
      exit 1
    }
  done
  printf "#   %-6s  %-8s  %-8s  %-8s\n" $V $OLD $MID $NEW
done
