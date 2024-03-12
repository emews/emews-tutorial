#!/bin/bash

VALID_VERSIONS=("3.8" "3.9" "3.10" "3.11")
V_PREFIX=(${VALID_VERSIONS[@]::${#VALID_VERSIONS[@]}-1})
V_SUFFIX="${VALID_VERSIONS[@]: -1}"
printf -v joined '%s, ' "${V_PREFIX[@]}"
V_STRING="${joined% } or $V_SUFFIX"

help() {
   echo "Usage: install_emews.sh <python-version> <database-directory>"
   echo "       install_emews.sh -h"
   echo
   echo "Arguments:"
   echo "  python-version         python version to use ($V_STRING)"
   echo "  database-directory     EQ/SQL Database installation directory" 
   echo "  h                      display this help and exit"
   echo
   echo "Example:"
   echo "  install_emews.sh 3.11 ~/Documents/db/eqsql_db"
}

while getopts ":h" option; do
   case $option in
      h) # display Help
         help
         exit;;
      \?) # incorrect option
         help
         exit;;
   esac
done

if [ "$#" -ne 2 ]; then
    help
    exit
fi

PY_VERSION=''
for V in "${VALID_VERSIONS[@]}"; do
    if [ $V = $1 ]; then
        PY_VERSION=$V
    fi
done

if [ -z "$PY_VERSION" ]; then
    
    echo "Error: python version must be one of $V_STRING."
    exit
fi

if [ -d $2 ]; then
    echo "Error: database directory must not already exist."
    exit
fi


if [ ! $(command -v conda) ]; then
    echo "Error: conda executable not found. Conda must be activated."
    echo "Try \"source ~/anaconda3/bin/activate\""
    exit
fi

CONDA_BIN=$(which conda)
CONDA_BIN_DIR=$(dirname $CONDA_BIN)

ENV_NAME=emews-py${PY_VERSION}
conda create -y -n $ENV_NAME python=${PY_VERSION}
# !! conda activate $ENV_NAME doesn't work within the script
source $CONDA_BIN_DIR/activate $ENV_NAME
conda install -y -c conda-forge -c swift-t swift-t-r
conda deactivate
source $CONDA_BIN_DIR/activate $ENV_NAME

conda install -y postgresql
pip install emewscreator
emewscreator init_db -d $2

Rscript -e "install.packages(c('reticulate', 'coro', 'jsonlite', 'purrr', 'logger', 'remotes'), repos='https://cloud.r-project.org/')"
Rscript -e "remotes::install_github('emews/EQ-SQL/R/EQ.SQL')"

echo
echo "# To activate this EMEWS environment, use"
echo "#"
echo "#     $ conda activate $ENV_NAME"
echo "#"
echo "# To deactivate an active environment, use"
echo "#"
echo "#     $ conda deactivate"