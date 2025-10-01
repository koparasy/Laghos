#!/usr/bin/env bash

usage () {
  echo "Usage: $0 JSON INSTANCE DB_DIR SUFFIX TRIALS ITERATIONS EXTRA_OPTS"
  echo -e "\tJSON            = JSON file"
  echo -e "\tINSTANCE        = Hash of the instance"
  echo -e "\tDB_DIR          = Output dir"
  echo -e "\tSUFFIX          = Suffix for the csv"
  echo -e "\tTRIALS          = Number of trials"
  echo -e "\tITERATION       = Number of iterations per trial"
  echo -e "\tEXTRA_OPTS      = Extra options for mneme tune (like --specialize)"
}

if [[ $# -ne 7 ]]; then
  echo "Error: incorrect number of arguments"
  usage
  exit 1
fi

ml load rocm/6.3

LAGHOS_PATH="/usr/workspace/LExperts/laghos/laghos-loic/laghos-hip"
source ${LAGHOS_PATH}/deps/mneme-env/bin/activate

export MNEME_LOG_LEVEL=critical

echo "ROCR_VISIBLE_DEVICES = $ROCR_VISIBLE_DEVICES"

SECONDS=0
mneme tune -db "$1" -rid "$2" --db-dir="$3" --suffix="$4" --tuner-type optuna --search-sampler QMCSampler --prune --internalize --num-trials "$5" -it "$6" $7
duration=$SECONDS
echo "$((duration / 60)) minutes and $((duration % 60)) seconds elapsed."
