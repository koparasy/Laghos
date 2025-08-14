#!/usr/bin/env bash

ml load cmake/3.29.2
ml load rocm/6.3
ml load rocmcc/6.3.1-cce-18.0.1h-magic

LIB_INSTALL="$(pwd)/deps/usr/${SYS_TYPE}/"

LAGHOS_PATH="$(pwd)"

if ! [ -x "$(command -v ${LAGHOS_PATH}/laghos)" ]; then
  echo "Error: laghos is not installed. Set LAGHOS_PATH to a correct laghos install"
  exit 1
fi

RS=5
#TF=0.0033
TF=0.6

#CMD="${LAGHOS_PATH}/laghos -p 0 -dim 2 -rs 3 -tf 0.75 -pa -d hip"
#CMD="${LAGHOS_PATH}/laghos -dim 3 -pa -tf 0.0033 -d hip -rs 1"
CMD="${LAGHOS_PATH}/laghos -p 1 -dim 3 -pa -tf ${TF} -d hip -rs ${RS}"

export LD_LIBRARY_PATH=/usr/tce/packages/cce/cce-18.0.1-magic/cce/x86_64/lib/:${LIB_INSTALL}/lib64/:$LD_LIBRARY_PATH

export MNEME_LOG_LEVEL=critical
export MNEME_PAGE_SIZE=16
# export AMD_LOG_LEVEL=4

OUTPUT_DIR=run-mneme-$(hostname)-rs${RS}-tf${TF}-$(date +%s)
mkdir -p $OUTPUT_DIR

pushd $OUTPUT_DIR 2>&1 >/dev/null

#export ROCR_VISIBLE_DEVICES=0

SECONDS=0
LD_PRELOAD=${LIB_INSTALL}/lib64/librecord.so $CMD | tee output-rs-${RS}.log
# time $CMD | tee output-nomneme-rs-${RS}.log
duration=$SECONDS
echo "$((duration / 60)) minutes and $((duration % 60)) seconds elapsed."

popd 2>&1 >/dev/null
echo "Output data in $OUTPUT_DIR"
