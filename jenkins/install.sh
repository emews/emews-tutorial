#!/bin/zsh
set -eu

# JENKINS INSTALL SH
# Runs install_emews.sh

DATE_FMT_NICE="%D{%Y-%m-%d} %D{%H:%M:%S}"
log()
# General-purpose log line
{
  print ${(%)DATE_FMT_NICE} "install.sh:" ${*}
}

log "JENKINS INSTALL SH"

THIS=${0:h:A}
EMEWS=${THIS:h}
WORKSPACES=${EMEWS:h}

# Defaults:
PYTHON_VERSION=${PYTHON_VERSION:-311}
CONDA_LABEL=${CONDA_LABEL:-23.11.0-1}
DB=$WORKSPACE/DB

# Main argument processing
zparseopts -D -E -F c:=CL p:=PV u=UNINSTALL
if (( ${#PV} )) PYTHON_VERSION=${PV[2]}
if (( ${#CL} )) CONDA_LABEL=${CL[2]}

MINICONDA=$WORKSPACES/EMEWS-Conda/Miniconda-${PYTHON_VERSION}_${CONDA_LABEL}
log "MINICONDA: $MINICONDA"
if [[ ! -d $MINICONDA ]] {
  log "Not found: MINICONDA=$MINICONDA"
  exit 1
}

# Convert, e.g., "311" -> "3.11"
PV_DOT=3.${PYTHON_VERSION[2,-1]}

renice --priority 19 --pid ${$} >& /dev/null

PATH=$MINICONDA/bin:$PATH

if [[ -d $DB ]] {
  log "Removing existing DB=$DB"
  rm -rf $DB
}

(
  # Install it!
  set -x
  which python conda
  $EMEWS/code/install/install_emews.sh -t $PV_DOT $DB
)

log "INSTALL SUCCESS"
print
