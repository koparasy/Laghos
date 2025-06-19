#!/usr/bin/env bash

ml load  cmake/3.29.2
ml load rocm/6.3
ml load rocmcc/6.3.1-cce-18.0.1h-magic

LIB_INSTALL="/usr/workspace/LExperts/laghos/Laghos-fork/deps/usr/toss_4_x86_64_ib_cray/"

LAGHOS_PATH="/usr/workspace/LExperts/laghos/Laghos-fork"

if ! [ -x "$(command -v ${LAGHOS_PATH}/laghos)" ]; then
  echo "Error: laghos is not installed. Set LAGHOS_PATH to a correct laghos install"
  exit 1
fi

CMD="gdb --args ${LAGHOS_PATH}/laghos -p 0 -dim 2 -rs 3 -tf 0.75 -pa -d hip"

export LD_LIBRARY_PATH=/usr/tce/packages/cce/cce-18.0.1-magic/cce/x86_64/lib/:$LD_LIBRARY_PATH

MNEME_LOG_LEVEL=debug
export MNEME_PAGE_SIZE=16

LD_PRELOAD=${LIB_INSTALL}/lib64/librecord.so $CMD

