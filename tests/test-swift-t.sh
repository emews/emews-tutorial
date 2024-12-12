#!/bin/bash

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
)

echo "..."
echo "test-swift-t.sh: STOP: OK"

# Local Variables:
# sh-basic-offset: 4
# End:
