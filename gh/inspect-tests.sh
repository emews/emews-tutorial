#!/bin/sh
set -eu

# GH INSPECT TESTS
# Checks that the install succeeded, prints log if necessary.

msg()
{
  echo "inspect-tests.sh:" ${*}
}

TEST_LOG=test.log
INSTALL_LOG=code/install/emews_install.log

if ! [ -f $TEST_LOG ]
then
  msg "NO TEST LOG"
  exit 1
fi

if ! grep -q "TESTS SUCCESS." $TEST_LOG
then
  msg "TESTS FAILED"
  echo
  echo "TEST LOG: $TEST_LOG"
  echo
  echo "INSTALL LOG: $INSTALL_LOG"
  echo
  cat $LOG
  exit 1
fi

msg "INSTALL OK."
