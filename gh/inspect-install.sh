#!/bin/sh
set -eu

# GH INSPECT INSTALL
# Checks that the install succeeded, prints log if necessary.

msg()
{
  echo "inspect-install.sh:" ${*}
}

LOG=code/install/emews_install.log

if ! [ -f $LOG ]
then
  msg "NO LOG"
  exit 1
fi

if ! grep -q "INSTALL SUCCESS." $LOG
then
  msg "INSTALL FAILED"
  echo
  echo "LOG: $LOG"
  echo
  cat $LOG
  exit 1
fi

msg "INSTALL OK."
