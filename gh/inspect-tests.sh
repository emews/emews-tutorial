#!/bin/sh
set -eu

# GH INSPECT TESTS
# Checks that the install succeeded, prints log if necessary.

msg()
{
  echo "inspect-tests.sh:" ${*}
}

# Created by install_emews.sh:
INSTALL_LOG=code/install/emews_install.log
# Created by test-swift-t.sh:
TEST_LOG=test.log

if ! [ -f $TEST_LOG ]
then
  msg "NO TEST LOG"
  echo
  exit 1
fi

if ! grep -q "TESTS SUCCESS." $TEST_LOG
then
  echo
  msg "TESTS FAILED"
  echo
  echo "INSTALL LOG BEGIN: $INSTALL_LOG"
  echo
  cat $INSTALL_LOG
  echo
  echo "INSTALL LOG END: $INSTALL_LOG"
  echo
  echo "TEST LOG: $TEST_LOG"
  echo
  cat $TEST_LOG
  echo
  echo "TEST LOG END: $TEST_LOG"
  echo
  exit 1
fi

echo
msg "INSTALL OK."
echo
