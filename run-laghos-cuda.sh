#!/usr/bin/env bash

load_env() {
  # Lassen only
  if [[ "$SYS_TYPE" == "blueos_3_ppc64le_ib_p9" ]]; then
    # source /etc/profile.d/z00_lmod.sh
    module load gcc/11.2.1
    module load cmake/3.23
    module load cuda/12.2
    export CUDA_ARCH="sm_70"
  elif [[ "$SYS_TYPE" == "toss_4_x86_64_ib_cray" ]]; then
    # module load cmake/3.29.2
    # module load rocm/6.3
    # module load rocmcc/6.3.1-cce-18.0.1h-magic
    echo "ROCM is not supported by this script"
    exit 1
  fi
}

LAGHOS_PATH="$(pwd)"

if ! [ -x "$(command -v ${LAGHOS_PATH}/laghos)" ]; then
  echo "Error: laghos is not installed. Set LAGHOS_PATH to a correct laghos install"
  exit 1
fi

load_env

LIB_INSTALL="$(pwd)/deps/usr/${SYS_TYPE}/"

RS=3
TF=0.0033
# TF=0.6

DEVICE="cuda"

#CMD="${LAGHOS_PATH}/laghos -p 0 -dim 2 -rs 3 -tf 0.75 -pa -d cuda"
#CMD="${LAGHOS_PATH}/laghos -dim 3 -pa -tf 0.0033 -d cuda -rs 1"
CMD="${LAGHOS_PATH}/laghos -p 1 -dim 3 -pa -tf ${TF} -d ${DEVICE} -rs ${RS}"

echo "LIB_INSTALL = ${LIB_INSTALL}"

export LD_LIBRARY_PATH=${LIB_INSTALL}/lib64/:$LD_LIBRARY_PATH

export MNEME_LOG_LEVEL=info
export MNEME_PAGE_SIZE=16

OUTPUT_DIR=run-mneme-${DEVICE}-$(hostname)-rs${RS}-$(date +%s)
mkdir -p $OUTPUT_DIR

pushd $OUTPUT_DIR 2>&1 >/dev/null

SECONDS=0
LD_PRELOAD=${LIB_INSTALL}/lib64/librecord.so $CMD | tee output-rs-${RS}.log
# time $CMD | tee output-nomneme-rs-${RS}.log
duration=$SECONDS
echo "$((duration / 60)) minutes and $((duration % 60)) seconds elapsed."

popd 2>&1 >/dev/null
echo "Output data in $OUTPUT_DIR"
