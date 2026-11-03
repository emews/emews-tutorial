#!/bin/zsh
set -eu

# DOWNLOAD MINICONDA
# Install a Miniconda whose Python matches PYTHON_VERSION.
# Usage: download-miniconda.sh PYTHON_VERSION INSTALL_DIR [LABEL]
#   LABEL is OLD, MID, or NEW (default NEW), picking the oldest,
#   middle, or newest installer in the table above.
#   LABEL NOW installs Miniconda3-latest.  If its Python is not
#   PYTHON_VERSION, print a message, set proceed=false in
#   GITHUB_OUTPUT, and exit 0.
#   e.g. download-miniconda.sh 3.11 $HOME/miniconda MID
# On GitHub Actions, INSTALL_DIR/bin is added to PATH for later steps.
#
# Sample Linux x86_64 installers from repo.anaconda.com/miniconda,
# as of 2026-10-27.  Files are Miniconda3-pyXXX_VERSION-Linux-x86_64.sh.
#
# Use ./python-table.sh to refresh this table
#
#   Python  Oldest    Middle    Newest
#   ------  --------  --------  --------
#   3.11    23.5.0-3  25.1.1-1  26.9.4-0
#   3.12    24.1.2-0  25.5.1-1  26.9.4-0
#   3.13    25.3.1-1  26.1.1-1  26.9.4-0
#   3.14    26.5.3-1  26.7.1-0  26.9.4-0

if (( ${#*} < 2 || ${#*} > 3 )) {
  print "download-miniconda.sh:" \
        "Provide PYTHON_VERSION INSTALL_DIR [LABEL]"
  exit 1
}
PY_VERSION=$1
INSTALL_DIR=$2
LABEL=${3:-NEW}

print "download-miniconda.sh:" \
      "START $PYTHON_VERSION $INSTALL_DIR $LABEL"

BASE_URL=https://repo.anaconda.com/miniconda
PY_TAG=py${PY_VERSION//./}

if [[ $( uname -s ) == Darwin ]] {
  OS=MacOSX
} else {
  OS=Linux
}
ARCH=$( uname -m )

if [[ $LABEL == "NOW" ]] {
  INSTALLER=Miniconda3-latest-${OS}-${ARCH}.sh
  # The installer header names its Python, e.g. "# VER: py314_...".
  HEAD_BYTES=$( curl -LsS -r 0-200000 $BASE_URL/$INSTALLER )
  VER_LINE=$( grep -a -m1 '^# VER:' <<< "$HEAD_BYTES" )
  if [[ -z $VER_LINE ]] {
    print "download-miniconda.sh: No VER line in $INSTALLER"
    exit 1
  }
  LATEST_TAG=${VER_LINE##*VER:}
  LATEST_TAG=${LATEST_TAG// /}
  LATEST_TAG=${LATEST_TAG%%_*}
  if [[ $LATEST_TAG != $PY_TAG ]] {
    print "NOW is not ${PY_VERSION} - exiting with success."
    if [[ -n ${GITHUB_OUTPUT:-} ]] {
      print "proceed=false" >> $GITHUB_OUTPUT
    }
    exit 0
  }
} else {
  PATTERN="Miniconda3-${PY_TAG}_[^\"<]*-${OS}-${ARCH}.sh"

  INSTALLERS=( ${(f)"$( curl -LsS $BASE_URL/ | \
                        grep -o $PATTERN     | \
                        sort -uV )"} )
  N=${#INSTALLERS}
  if (( N == 0 )) {
    print "download-miniconda.sh:" \
          "No installer for ${PY_TAG} ${OS} ${ARCH}"
    exit 1
  }
  case $LABEL {
    OLD) I=1 ;;
    MID) I=$(( (N + 1) / 2 )) ;;
    NEW) I=$N ;;
    *)
      print "download-miniconda.sh: Unknown LABEL: '$LABEL'"
      exit 1
      ;;
  }
  INSTALLER=${INSTALLERS[I]}
}

if [[ -n ${GITHUB_OUTPUT:-} ]] {
  print "proceed=true" >> $GITHUB_OUTPUT
}
print "download-miniconda.sh: $INSTALLER"
curl -LsSo installer.sh $BASE_URL/$INSTALLER
bash installer.sh -b -p $INSTALL_DIR
rm installer.sh

print $INSTALL_DIR/bin >> $GITHUB_PATH
