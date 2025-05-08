#!/bin/zsh
# Postpone 'set -eu' for conda activate below

# TEST SWIFT-T
# Test Swift/T under GitHub Actions or Jenkins
# Provide -E to skip activating an environment
#         This is good for interactive use
#         when an environment is already activated.

E=""
USE_ENV=1
zparseopts -D -E E=E
if (( ${#E} )) USE_ENV=0

echo "test-swift-t.sh: START"

if (( ${#} != 1 ))
then
    echo "test-swift-t.sh: Provide Python version!"
    exit 1
fi

PY_VERSION=$1
THIS=$( dirname $0 )

# Are we running under an automated testing environment?
if (( ${#JENKINS_URL} > 0 ))
then
    echo "test-swift-t.sh: detected auto test Jenkins"
    AUTO_TEST="Jenkins"
elif (( ${GITHUB_ACTIONS:-false} == true ))
then
    echo "test-swift-t.sh: detected auto test GitHub"
    AUTO_TEST="GitHub"
else
    # Other- possibly interactive user run.  Set to empty string.
    AUTO_TEST=""
fi

if (( $AUTO_TEST == "Jenkins" ))
then
    # CELS Jenkins environment
    CONDA_BIN_DIR=$WORKSPACE/../EMEWS-Conda/Miniconda-311_23.11.0-1/bin
    PATH=$CONDA_BIN_DIR:$PATH
    # Otherwise, we are on GitHub, and GitHub provides python, conda
elif (( $AUTO_TEST == "GitHub" ))
then
    # CONDA_EXE is set by conda
    # The installation is a bit different on GitHub
    # conda    is in $CONDA_HOME/condabin
    # activate is in $CONDA_HOME/bin
    CONDA_HOME=$(dirname $(dirname $CONDA_EXE))
    CONDA_BIN_DIR=$CONDA_HOME/bin

    # Placeholder with no content:
    echo > test.log
fi

# Optionally activate the environment in which EMEWS was installed:
if (( USE_ENV )) {
    ENV_NAME=emews-py${PY_VERSION}

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
}

set -eu

if [[ $AUTO_TEST == "Jenkins" ]]
then
    # See code/install/README.  Sync this with install_emews.sh
    COLON=${LD_LIBRARY_PATH:+:} # Conditional colon
    export LD_LIBRARY_PATH=$CONDA_PREFIX/x86_64-conda-linux-gnu/lib$COLON${LD_LIBRARY_PATH:-}
    echo "Setting LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
fi

PYTHON_EXE=$(which python)
ENV_HOME=$(dirname $(dirname $PYTHON_EXE))

echo "python:  " $PYTHON_EXE
echo "version: " $(python -V)
echo "conda:   " $(which conda)
echo "env:     " $ENV_HOME
echo "Rscript: " $(which Rscript)
echo "version: " $(Rscript --version)

# EQ/R files EQR.swift and pkgIndex.tcl should be under ENV/lib:
SWIFT_LIBS=$ENV_HOME/lib

# Run tests!

export TURBINE_RESIDENT_WORK_WORKERS=1
FLAGS=( -n 4 -I $SWIFT_LIBS -r $SWIFT_LIBS )

setopt LOCAL_OPTIONS
() {
    # Anonymous function for 'set -x'
    # For 'set -x' including newline:
    set -x
    setopt LOCAL_OPTIONS
    PS4="
TEST: "

    which swift-t
    swift-t -v
    swift-t -E 'trace(42);'
    swift-t $FLAGS -E 'import EQR;'
    swift-t $FLAGS $THIS/test-eqr-1.swift
    swift-t $FLAGS $THIS/test-apps-1.swift
    Rscript $THIS/install-graphics.R
    swift-t $FLAGS $THIS/test-apps-2.swift
}

echo "..."
echo "test-swift-t.sh: STOP: OK"

if [[ $AUTO_TEST == "GitHub" ]]
then
    # For inspect-tests.sh
    echo "TESTS SUCCESS." > test.log
fi

# Local Variables:
# sh-basic-offset: 4
# End:
