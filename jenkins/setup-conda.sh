#!/bin/zsh
set -eu

# JENKINS SETUP CONDA SH
# Installs Miniconda package file in MINICONDA_SH
# to Miniconda installation directory TARGET

# Defaults:
PYTHON_VERSION=${PYTHON_VERSION:-311}
CONDA_LABEL=${CONDA_LABEL:-23.11.0-1}

DATE_FMT_NICE="%D{%Y-%m-%d} %D{%H:%M:%S}"
log()
# General-purpose log line
{
  print ${(%)DATE_FMT_NICE} "setup-conda.sh:" ${*}
}

log "SETUP CONDA"

# Report uptime-
# this is important to know when/if the machine was rebooted
log "HOSTNAME: $(hostname)"
log "UPTIME:   $(uptime)"

# Clean up prior runs
uninstall()
{
  log "UNINSTALL ..."
  rm -fv $WORKSPACE/$MINICONDA_SH
  log "DELETE: $WORKSPACE/sfw/Miniconda-$CONDA_LABEL ..."
  rm -fr $TARGET
  log "UNINSTALL OK."
}

downloads()
# Download and install Miniconda
{
  log "DOWNLOADS ..."
  (
    mkdir -pv $WORKSPACE
    cd $WORKSPACE
    if [[ ! -f $MINICONDA_SH ]] \
         wget --no-verbose https://repo.anaconda.com/miniconda/$MINICONDA_SH
  )
  log "DOWNLOADS OK."
}

help()
{
  cat <<EOF
-p PYTHON_VERSION  default "$PYTHON_VERSION"
-c CONDA_LABEL     default "$CONDA_LABEL"
-u                 delete prior artifacts, default does not
EOF
}

# Run plain help as needed before possibly affecting settings:
zparseopts h=HELP
if (( ${#HELP} )) help

# Main argument processing
zparseopts -D -E -F c:=CL p:=PV u=UNINSTALL
if (( ${#PV} )) PYTHON_VERSION=${PV[2]}
if (( ${#CL} )) CONDA_LABEL=${CL[2]}

renice --priority 19 --pid ${$} >& /dev/null

MINICONDA_SH=Miniconda3-py${PYTHON_VERSION}_${CONDA_LABEL}-Linux-x86_64.sh
log "MINICONDA: $MINICONDA_SH"
TARGET=$WORKSPACE/Miniconda-${PYTHON_VERSION}_${CONDA_LABEL}
log "TARGET: $TARGET"

if (( ${#UNINSTALL} )) uninstall
downloads

if [[ -d $TARGET ]] {
  log "Installation exists: $TARGET"
} else {
  log "INSTALL ..."
  bash $MINICONDA_SH -b -p $TARGET
  log "INSTALL OK: $TARGET"
}

log "DONE."
