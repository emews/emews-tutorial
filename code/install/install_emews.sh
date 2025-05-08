#!/bin/bash

# INSTALL EMEWS SH
# See README.adoc

# Are we running under an automated testing environment?
if (( ${#JENKINS_URL} > 0 ))
then
    echo "install_emews.sh: detected auto test Jenkins"
    AUTO_TEST="Jenkins"
elif [[ ${GITHUB_ACTIONS:-false} == true ]]
then
    echo "install_emews.sh: detected auto test GitHub"
    AUTO_TEST="GitHub"
else
    # Other- possibly interactive user run.  Set to empty string.
    AUTO_TEST=""
fi

function start_step {
    if (( ! ${#AUTO_TEST} ))
    then
        # Normal shell run
        echo -en "[ ] $1 "
    elif [[ $AUTO_TEST == "Jenkins" ]]
    then
        echo -e  "[ ] $1 "
    elif [[ $AUTO_TEST == "GitHub" ]]
    then
        # Duplicate output to visible output and log
        echo -e "[ ] $1 "
        echo -e "[ ] $1 " >> "$EMEWS_INSTALL_LOG"
    else
        echo "Invalid AUTO_TEST=$AUTO_TEST"
        exit 1
    fi
}

function end_step {
    if (( ! ${#AUTO_TEST} ))
    then
        # Normal shell run - overwrite last line and show check mark
        echo -e "\r[\xE2\x9C\x94] $1 "
    elif [[ $AUTO_TEST == "Jenkins" ]]
    then
        echo -e "[X] $1 "
    elif [[ $AUTO_TEST == "GitHub" ]]
    then
        # Duplicate output to visible output and log
        echo -e "[X] $1 "
        echo -e "[X] $1 " >> "$EMEWS_INSTALL_LOG"
    else
        echo "Invalid AUTO_TEST=$AUTO_TEST"
        exit 1
    fi
}

function on_error {
    msg="$1"
    # Log may be blank if the step does not use a log
    log="$2"

    echo -e "\n\ninstall_emews.sh: Error: $msg"

    if (( ${#log} ))
    then
        if [[ ${AUTO_TEST} != "GitHub" ]]
        then
            # Non-GitHub run - user can retrieve log
            echo "install_emews.sh: see log: $log"
        else
            # GitHub run - must show log now
            echo "install_emews.sh: showing log: $log"
            cat $log
            echo "install_emews.sh: End of log."
        fi
    fi
    echo "install_emews.sh: exit 1"
    exit 1
}

VALID_VERSIONS=("3.8" "3.9" "3.10" "3.11" "3.12")
V_PREFIX=(${VALID_VERSIONS[@]::${#VALID_VERSIONS[@]}-1})
V_SUFFIX="${VALID_VERSIONS[@]: -1}"
printf -v joined '%s, ' "${V_PREFIX[@]}"
V_STRING="${joined% } or $V_SUFFIX"

help() {
   echo "Usage: install_emews.sh <python-version> <database-directory>"
   echo "       install_emews.sh -h"
   echo
   echo "Arguments:"
   echo "  -h                     display this help and exit"
   echo "  -q                     quieter: pass -q to conda install"
   echo "  -t                     run additional short tests"
   echo "  -v                     verbose mode for debugging"
   echo "  python-version         python version to use ($V_STRING)"
   echo "  database-directory     EQ/SQL Database installation directory"
   echo
   echo "Example:"
   echo "  install_emews.sh 3.11 ~/Documents/db/eqsql_db"
}

# Default: Tests off
# It is good to be able to run short tests
# before the long install_pkgs.R step
RUN_TESTS=0

# Default: Not verbose
# Turning this on reports intermediate Anaconda package lists
VERBOSE=0

while getopts ":hqtv" option; do
   case $option in
      h) # display user help
         help
         exit        ;;
      q) QUIET="-q"  ;;
      t) RUN_TESTS=1 ;;
      v) VERBOSE=1   ;;
      \?) # incorrect option
         help
         exit 1      ;;
   esac
done
shift $(( OPTIND - 1 ))

if [ "$#" -ne 2 ]; then
    help
    # Invalid argument count is an error:
    exit 1
fi

PY_VERSION=''
for V in "${VALID_VERSIONS[@]}"; do
    if [ $V = $1 ]; then
        PY_VERSION=$V
    fi
done

if [ -z "$PY_VERSION" ]; then
    echo "Error: python version must be one of $V_STRING."
    exit 1
fi

if [ -d $2 ]; then
    echo "Error: Database directory already exists: $2"
    echo "       This script will not overwrite an existing database."
    echo "       Remove it or specify a different directory."
    exit 1
fi

if [ ! $(command -v conda) ]; then
    echo "Error: conda executable not found. Conda must be activated."
    echo "Try \"source ~/anaconda3/bin/activate\""
    exit 1
fi

CONDA_EXE=$(which conda)
if [[ ${AUTO_TEST} != "GitHub" ]]
then
    CONDA_BIN_DIR=$(dirname $CONDA_EXE)
else
    # The installation is a bit different on GitHub
    # conda    is in $CONDA_HOME/condabin
    # activate is in $CONDA_HOME/bin
    CONDA_HOME=$(dirname $(dirname $CONDA_EXE))
    CONDA_BIN_DIR=$CONDA_HOME/bin
fi

THIS=$( cd $( dirname $0 ) ; /bin/pwd )
EMEWS_INSTALL_LOG="$THIS/emews_install.log"
# Get Operating System name
OS=$( uname -o )

echo "Starting EMEWS stack installation"
echo "See detailed output in: ${THIS}/emews_install.log"
if [[ -f ${THIS}/emews_install.log ]]
then
    echo "Resetting log..."
    echo > ${THIS}/emews_install.log
fi
echo

echo "Using conda bin: $CONDA_BIN_DIR"

ENV_NAME=emews-py${PY_VERSION}
TEXT="Creating conda environment '${ENV_NAME}' using Python ${PY_VERSION}"
start_step "$TEXT"
conda create -y $QUIET -n $ENV_NAME python=${PY_VERSION} >> "$EMEWS_INSTALL_LOG" 2>&1 || on_error "$TEXT" "$EMEWS_INSTALL_LOG"
end_step "$TEXT"

TEXT="Activating conda environment"
if (( ${#AUTO_TEST} ))
then
    echo "activating: $CONDA_BIN_DIR/activate '$ENV_NAME'"
fi
start_step "$TEXT"
if ! [[ -f $CONDA_BIN_DIR/activate ]]
then
    on_error "File not found: '$CONDA_BIN_DIR/activate'"
fi
source $CONDA_BIN_DIR/activate $ENV_NAME || on_error "$TEXT"
end_step "$TEXT"

if (( ${#AUTO_TEST} ))
then
    echo "python:  " $(which python)
    echo "version: " $(python -V)
    echo "conda:   " $(which conda)
fi

function conda-list
# If VERBOSE, debug conda state during installations
{
    if (( ! VERBOSE ))
    then
        return
    fi
    {
        echo
        echo "conda-list:" ${*}
        echo
        conda list 2>&1
        echo
    } >> "$EMEWS_INSTALL_LOG"
}

conda-list 1

# EQ-R depends on Swift/T and R, so that is all we need to specify
#      to Anaconda.  2025-05-08
# But eq-r is not pulling in swift-t-r on GH Ubuntu 2025-05-08
TEXT="Installing EMEWS Queues for R"
start_step "$TEXT"
conda install -y $QUIET -c conda-forge -c swift-t eq-r swift-t-r >> "$EMEWS_INSTALL_LOG" 2>&1 || on_error "$TEXT" "$EMEWS_INSTALL_LOG"
end_step "$TEXT"

conda-list 2

if (( RUN_TESTS ))
then
    (
        set -x
        which R
        R --version
    )
fi

if (( RUN_TESTS ))
then
    (
        set -x
        swift-t -v
        swift-t -E 'trace(42);'
    )
fi

if [[ $AUTO_TEST == "Jenkins" ]]
then
    GCC_VERSION=12.3.0
    TEXT="Installing gcc==$GCC_VERSION"
    # Upgrades from 11.2.0 to 12.3.0 on GCE Jenkins (Ubuntu 20) (2024-06-11)
    start_step "$TEXT"
    conda install -y $QUIET -c conda-forge gcc==$GCC_VERSION >> "$EMEWS_INSTALL_LOG" 2>&1 || on_error "$TEXT" "$EMEWS_INSTALL_LOG"
    end_step "$TEXT"
fi

conda-list 4

TEXT="Installing PostgreSQL"
start_step "$TEXT"
conda install -y $QUIET -c conda-forge postgresql==14.12 >> "$EMEWS_INSTALL_LOG" 2>&1 || on_error "$TEXT" "$EMEWS_INSTALL_LOG"
end_step "$TEXT"

conda-list 5

TEXT="Installing EMEWS Creator"
start_step "$TEXT"
pip install emewscreator >> "$EMEWS_INSTALL_LOG" 2>&1 || on_error "$TEXT" "$EMEWS_INSTALL_LOG"
end_step "$TEXT"

if [[ $AUTO_TEST == "Jenkins" ]]
then
    # See README.  Sync this with test-swift-t.sh
    COLON=${LD_LIBRARY_PATH:+:} # Conditional colon
    export LD_LIBRARY_PATH=$CONDA_PREFIX/x86_64-conda-linux-gnu/lib$COLON${LD_LIBRARY_PATH:-}
    echo "Setting LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
fi

TEXT="Initializing EMEWS Database"
start_step "$TEXT"
emewscreator init_db -d $2 >> "$EMEWS_INSTALL_LOG" 2>&1 || on_error "$TEXT" "$EMEWS_INSTALL_LOG"
end_step "$TEXT"

echo
echo "Using Rscript: $(which Rscript)" 2>&1 | tee -a "$EMEWS_INSTALL_LOG"

TEXT="Installing R package dependencies"
start_step "$TEXT"
# R-pkgs.txt is the list of R package names:
cat <<EOF > $THIS/R-pkgs.txt
coro
jsonlite
purrr
logger
remotes
Rcpp
EOF
Rscript $THIS/install_list.R $THIS/R-pkgs.txt >> "$EMEWS_INSTALL_LOG" 2>&1 || on_error "$TEXT" "$EMEWS_INSTALL_LOG"
end_step "$TEXT"

echo
echo "#"
echo "# EMEWS installation successful!"
echo "#"
echo "# Installed environment information:"
echo "# python   is $(which python)"
echo "#             $(python -V)"
echo "# R        is $(which R)"
echo "#             $(R --version | head -1)"
echo "# swift-t  is $(which swift-t)"
echo "#             $(swift-t -v)"
echo "#"
echo "# To activate this EMEWS environment, use"
echo "#"
echo "#     $ conda activate $ENV_NAME"
echo "#"
echo "# To deactivate an active environment, use"
echo "#"
echo "#     $ conda deactivate"

if (( RUN_TESTS ))
then
    (
        # Quick probe of new installation
        # Merge stderr to stdout:
        exec 2>&1
        echo TEST-ACTIVATE $ENV_NAME
        conda activate $ENV_NAME
        echo CONDA_PREFIX=$CONDA_PREFIX
        conda list
        set -x
        # ls $CONDA_PREFIX/lib
        if [[ $OS != "Darwin" ]]
        then
            ldd $CONDA_PREFIX/lib/libeqr.so
        else
            ls -l $CONDA_PREFIX/lib/libeqr.so
        fi
    ) >> "$EMEWS_INSTALL_LOG"
fi

if [[ $AUTO_TEST == "GitHub" ]]
then
    echo "creating $PWD / gh-run"
    # On GitHub, create a runner script 'gh-run' for testing
    {
        cat <<EOF
#!/bin/bash
# This script loads up the Conda environment,
# then runs the user command
exec 2>&1
echo
echo GH-RUN:
echo
source $CONDA_BIN_DIR/activate $ENV_NAME
set -eux
which python conda
which swift-t
set -x
ls $CONDA_PREFIX/lib/EQR.swift
ls $CONDA_PREFIX/lib/libeqr.so
"\${@}"
EOF
    } >> gh-run
    cat gh-run
    chmod -v u+x gh-run
fi

{
    echo
    echo "INSTALL SUCCESS."
} >> "$EMEWS_INSTALL_LOG"


# Local Variables:
# sh-basic-offset: 4
# End:
