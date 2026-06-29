#!/bin/zsh
set -eu
setopt NULL_GLOB

# JENKINS SETUP CONDA SH
# Installs Miniconda package file in MINICONDA_SH
# to Miniconda installation directory TARGET

# Defaults:
PYTHON_VERSION=${PYTHON_VERSION:-311}
CONDA_LABEL_DEFAULT=26.1.1-1
: ${CONDA_LABEL:=$CONDA_LABEL_DEFAULT}

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

help()
{
  cat <<EOF
-p PYTHON_VERSION  default "$PYTHON_VERSION"
-c CONDA_LABEL     default "$CONDA_LABEL"
-u                 delete prior artifacts, default does not
EOF
}

tm()
{
  =time --format "TIME: %E" ${*}
}

# Clean up prior installations
uninstall()
{
  log "UNINSTALL ..."
  log "DELETE INSTALLERS:"
  ls -l  $WORKSPACE/downloads
  rm -fv $WORKSPACE/downloads/*
  log "DELETE INSTALLATIONS: $WORKSPACE/sfw/Miniconda-* ..."
  ls -ld $WORKSPACE/sfw/Miniconda-*
  rm -fr $WORKSPACE/sfw/Miniconda-*
  log "UNINSTALL OK."
}

do-download()
{
  log "DOWNLOADS ..."
  (
    cd $WORKSPACE/downloads
    if [[ ! -f $MINICONDA_SH ]] \
         wget --no-verbose https://repo.anaconda.com/miniconda/$MINICONDA_SH
  )
  log "DOWNLOADS OK."
}

report-disk-space()
{
  print
  log "DISK SPACE: WORKSPACE:"
  tm du -sh $WORKSPACE
  print
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
TARGET=$WORKSPACE/sfw/Miniconda-${PYTHON_VERSION}_${CONDA_LABEL}
log "TARGET: $TARGET"

mkdir -pv $WORKSPACE/downloads
if (( ${#UNINSTALL} )) uninstall
do-download

if [[ -d $TARGET ]] {
  log "Installation exists: $TARGET"
} else {
  log "INSTALL ..."
  bash downloads/$MINICONDA_SH -b -p $TARGET
  log "INSTALL OK: $TARGET"
}

report-disk-space

log "DONE."
