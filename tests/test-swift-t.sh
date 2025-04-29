#!/bin/bash
# Postpone 'set -eu' for conda activate below

# TEST SWIFT-T
# Test Swift/T under GitHub Actions or Jenkins

echo "test-swift-t.sh: START"

if (( ${#} != 1 ))
then
    echo "test-swift-t.sh: Provide Python version!"
    exit 1
fi

PY_VERSION=$1

THIS=$( dirname $0 )

if (( ${#JENKINS_URL} > 0 ))
then
    # CELS Jenkins environment
    PATH=$WORKSPACE/../EMEWS-Conda/Miniconda-311_23.11.0-1/bin:$PATH
    # Otherwise, we are on GitHub, and GitHub provides python, conda
fi

if (( ${#GITHUB_ACTION} > 0))
then
    # Placeholder with no content:
    echo > test.log
fi

ENV_NAME=emews-py${PY_VERSION}

CONDA_EXE=$(which conda)
# The installation is a bit different on GitHub
# conda    is in $CONDA_HOME/condabin
# activate is in $CONDA_HOME/bin
CONDA_HOME=$(dirname $(dirname $CONDA_EXE))
CONDA_BIN_DIR=$CONDA_HOME/bin

echo "activating: $CONDA_BIN_DIR/activate '$ENV_NAME'"
if ! [[ -f $CONDA_BIN_DIR/activate ]]
then
    echo "File not found: '$CONDA_BIN_DIR/activate'"
    exit 1
fi
if ! source $CONDA_BIN_DIR/activate $ENV_NAME
then
    echo "could not activate: $ENV_NAME"
    exit 1
fi

if [[ $AUTO_TEST == "Jenkins" ]]
then
    # See code/install/README.  Sync this with install_emews.sh
    COLON=${LD_LIBRARY_PATH:+:} # Conditional colon
    export LD_LIBRARY_PATH=$CONDA_PREFIX/x86_64-conda-linux-gnu/lib$COLON${LD_LIBRARY_PATH:-}
    echo "Setting LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
fi

set -eu

PYTHON_EXE=$(which python)
ENV_HOME=$(dirname $(dirname $PYTHON_EXE))

echo "python:  " $PYTHON_EXE
echo "version: " $(python -V)
echo "conda:   " $(which conda)
echo "env:     " $ENV_HOME

# EQ/R files EQR.swift and pkgIndex.tcl should be under ENV/lib:
SWIFT_LIBS=$ENV_HOME/lib

# Run tests!

export TURBINE_RESIDENT_WORK_WORKERS=1
FLAGS=( -n 4 -I $SWIFT_LIBS -r $SWIFT_LIBS )

(
    set -x
    which swift-t
    swift-t -v
    swift-t -E 'trace(42);'
    swift-t ${FLAGS[@]} -E 'import EQR;'
    swift-t ${FLAGS[@]} $THIS/test-eqr-1.swift
    swift-t ${FLAGS[@]} $THIS/test-apps-1.swift
)

echo "..."
echo "test-swift-t.sh: STOP: OK"

if [[ ${GITHUB_ACTION:-} != "" ]]
then
    # For inspect-tests.sh
    echo "TESTS SUCCESS." > test.log
fi

# Local Variables:
# sh-basic-offset: 4
# End:
