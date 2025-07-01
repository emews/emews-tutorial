#!/bin/bash
# Postpone 'set -eu' for conda activate below
# Use bash, not ZSH, because we are running in a
#     raw GitHub environment

# TEST SWIFT-T
# Test Swift/T under GitHub Actions or Jenkins
# Provide Python version as MAJOR.MINOR
# Provide -E to skip activating an environment
#         This is good for interactive use
#         when an environment is already activated.
# Provide -I to skip installing R packages
# Provide -R to skip testing R cases

log()
{
  echo "test-swift-t.sh:" ${*}
}

log "START: ARGS: ${*}"

# Defaults:
USE_ENV=1
USE_R=1
DO_INSTALL=1

while getopts "EIR" option
do
    case $option in
      E) USE_ENV=0    ;;
      I) DO_INSTALL=0 ;;
      R) USE_R=0      ;;
      *) # Bash prints an error message
         exit 1 ;;
    esac
done
shift $(( OPTIND - 1 ))

if (( ${#} != 1 ))
then
    log "Provide Python version!"
    exit 1
fi

PY_VERSION=$1
echo "PY_VERSION=$PY_VERSION"
THIS=$( dirname $0 )

# Are we running under an automated testing environment?
if (( ${#JENKINS_URL} > 0 ))
then
    log "detected auto test Jenkins"
    AUTO_TEST="Jenkins"
elif [[ ${GITHUB_ACTIONS:-false} == true ]]
then
    log "detected auto test GitHub"
    AUTO_TEST="GitHub"
else
    # Other- possibly interactive user run.  Set to empty string.
    AUTO_TEST=""
fi

if [[ $AUTO_TEST == "Jenkins" ]]
then
    # CELS Jenkins environment
    CONDA_BIN_DIR=$WORKSPACE/../EMEWS-Conda/Miniconda-311_23.11.0-1/bin
    PATH=${CONDA_BIN_DIR:a}:$PATH
elif [[ $AUTO_TEST == "GitHub" ]]
then
    # The installation is a bit different on GitHub
    # conda    is in $CONDA_HOME/condabin
    # activate is in $CONDA_HOME/bin
    CONDA_EXE=$(which conda)
    CONDA_HOME=$(dirname $(dirname $CONDA_EXE))
    CONDA_BIN_DIR=$CONDA_HOME/bin

    # Placeholder with no content:
    echo > test.log
else
    : Assume user set up Anaconda!
fi

# Optionally activate the environment in which EMEWS was installed:
if (( USE_ENV ))
then
    ENV_NAME=emews-py${PY_VERSION}

    log "activating: $CONDA_BIN_DIR/activate '$ENV_NAME'"
    if ! [[ -f $CONDA_BIN_DIR/activate ]]
    then
        log "File not found: '$CONDA_BIN_DIR/activate'"
        exit 1
    fi
    if ! source $CONDA_BIN_DIR/activate $ENV_NAME
    then
        log "could not activate: $ENV_NAME"
        exit 1
    fi
fi

set -eu

if [[ $AUTO_TEST == "Jenkins" ]]
then
    # See code/install/README.  Sync this with install_emews.sh
    COLON=${LD_LIBRARY_PATH:+:} # Conditional colon
    export LD_LIBRARY_PATH=$CONDA_PREFIX/x86_64-conda-linux-gnu/lib$COLON${LD_LIBRARY_PATH:-}
    log "Setting LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
fi

PYTHON_EXE=$(which python)
ENV_HOME=$(dirname $(dirname $PYTHON_EXE))

log "python:  " $PYTHON_EXE
log "version: " $(python -V)
log "conda:   " $(which conda)
log "env:     " $ENV_HOME
log "Rscript: " $(which Rscript)
log "version: " $(Rscript --version)

# EQ/R files EQR.swift and pkgIndex.tcl should be under ENV/lib:
SWIFT_LIBS=$ENV_HOME/lib

# Run tests!

export TURBINE_RESIDENT_WORK_WORKERS=1
FLAGS=( -n 4 -I $SWIFT_LIBS -r $SWIFT_LIBS )

R_install()
{
    Rscript $THIS/../code/install/install_list.R ${*}
}

(
    # Subshells for 'set -x' and exit from R tests
    (
        set -x
        which swift-t
        swift-t -v
        swift-t -E 'trace(42);'
    )
    if (( ! USE_R ))
    then
        log "skipping R tests."
        exit # from subshell
    fi
    if (( DO_INSTALL ))
    then
        (
            set -x
            R_install $THIS/pkgs-graphics.txt
            R_install $THIS/pkgs-lattice.txt
        )
    fi
    (
        set -x
        # Simply load EQ/R:
        swift-t ${FLAGS[@]} -E 'import EQR;'
        swift-t ${FLAGS[@]} $THIS/test-eqr-1.swift
        # Purrr:
        swift-t ${FLAGS[@]} $THIS/test-apps-1.swift
        # Farver:
        swift-t ${FLAGS[@]} $THIS/test-apps-2.swift
        # Lattice:
        swift-t ${FLAGS[@]} $THIS/test-apps-3.swift
    )
)

log "STOP: OK"

if [[ $AUTO_TEST == "GitHub" ]]
then
    # For inspect-tests.sh
    echo "TESTS SUCCESS." > test.log
fi

# Local Variables:
# sh-basic-offset: 4
# End:
