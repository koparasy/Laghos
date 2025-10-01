#!/usr/bin/env bash

# flux batch -N10 -t 6h -x --out mneme-wf-{{id}}.out ./run-mneme.flux run-mneme-tuolumne1006-rs5-1753928793/

usage () {
  echo "Usage: $0 DIR"
  echo -e "\tDIR           = Directory containing JSON file"
}

if [[ $# -ne 1 ]]; then
  echo "Error: incorrect number of arguments ($#)"
  usage
  exit 1
fi

ml load rocm/6.3

LAGHOS_PATH="/usr/workspace/LExperts/laghos/laghos-loic/laghos-hip"
source ${LAGHOS_PATH}/deps/mneme-env/bin/activate

export BATCH_NNODES=$(flux resource list -n -o {nnodes})

python3 ${LAGHOS_PATH}/run-flux.py -i $1 -spec
