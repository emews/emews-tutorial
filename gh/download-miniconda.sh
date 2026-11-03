#!/bin/zsh
set -eu

# DOWNLOAD MINICONDA
# Install the newest Miniconda whose Python matches PYTHON_VERSION.
# Usage: download-miniconda.sh PYTHON_VERSION INSTALL_DIR
#   e.g. download-miniconda.sh 3.11 $HOME/miniconda
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

if (( ${#*} != 2 )) {
  print "download-miniconda.sh: Provide PYTHON_VERSION and INSTALL_DIR!"
  exit 1
}
PY_VERSION=$1
INSTALL_DIR=$2

BASE_URL=https://repo.anaconda.com/miniconda
PY_TAG=py${PY_VERSION//./}

if [[ $( uname -s ) == Darwin ]] {
  OS=MacOSX
} else {
  OS=Linux
}
ARCH=$( uname -m )

PATTERN="Miniconda3-${PY_TAG}_[^\"<]*-${OS}-${ARCH}.sh"

INSTALLER=$( curl -LsS $BASE_URL/ | \
             grep -o $PATTERN     | \
             sort -uV | tail -1   )
if [[ $INSTALLER == "" ]] {
  print "download-miniconda.sh:" \
        "No installer for ${PY_TAG} ${OS} ${ARCH}"
  exit 1
}

print "download-miniconda.sh: $INSTALLER"
curl -LsSo installer.sh $BASE_URL/$INSTALLER
bash installer.sh -b -p $INSTALL_DIR
rm installer.sh

print $INSTALL_DIR/bin >> $GITHUB_PATH
