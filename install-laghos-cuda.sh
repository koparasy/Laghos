#!/bin/bash

set -e

usage () {
  echo "Usage: $0 use_mneme=on|off"
}


if [[ $# -ne 1 ]]; then
  echo "Error: incorrect number of arguments"
  usage
  exit 1
fi

build_hypre(){
  BASE_DIR=$1
  LOCAL_DIR=$2
  hypre_version=$3
  use_mneme=$4
  if [ ! -d hypre ]; then
    git clone --depth 1 --branch $hypre_version https://github.com/hypre-space/hypre.git
  fi

  pushd hypre
  pushd src
  mpi_path=$(realpath $(dirname $(which mpicc))/../)
  make distclean 2>/dev/null || true
  echo "Hypre: mpicc = $(which mpicc) | mpi_path = ${mpi_path}"
  cuda_gencode=$(echo $CUDA_ARCH | sed 's/[^0-9]*//g')

  if [[ "$use_mneme" == "on" ]]; then
    echo "Build hypre with Mneme"
    CUFLAGS="-fpass-plugin=${LOCAL_DIR}/lib64/libregdeviceir.so -O3 -std=c++14 -x cu -arch=$CUDA_ARCH --extended-lambda" CC=mpicc CXX=mpicxx CXXFLAGS="std=c++17 -fPIC" CFLAGS="-fPIC" ./configure \
      --prefix=$LOCAL_DIR \
      --with-extra-ldpath="${LOCAL_DIR}/lib64/" \
      --with-MPI-libs="mpi mneme_shallow" \
      --with-gpu-arch="${cuda_gencode}" \
      --with-MPI-lib-dirs=${mpi_path}/lib \
      --with-MPI-include=${mpi_path}/include \
      --enable-fortran \
      --with-cuda \
      --enable-cublas \
      --enable-curand 
  else
    # CUFLAGS="-O3 -std=c++14 -x cu -arch=$CUDA_ARCH --extended-lambda" CC=mpicc CXX=mpicxx CXXFLAGS="std=c++17 -fPIC" CFLAGS="-fPIC" ./configure \
    #   --prefix=$LOCAL_DIR \
    #   --with-gpu-arch="${cuda_gencode}" \
    #   --with-MPI-lib-dirs=${mpi_path}/lib \
    #   --with-MPI-include=${mpi_path}/include \
    #   --enable-fortran \
    #   --with-cuda \
    #   --enable-cublas \
    #   --enable-curand

    CUFLAGS="-O3 -std=c++14 -x cu --extended-lambda" CC=mpicc CXX=mpicxx CXXFLAGS="std=c++17 -fPIC" CFLAGS="-fPIC" ./configure \
      --prefix=$LOCAL_DIR \
      --with-gpu-arch="${cuda_gencode}" \
      --with-MPI-lib-dirs=${mpi_path}/lib \
      --with-MPI-include=${mpi_path}/include \
      --disable-fortran \
      --with-cuda \
      --enable-cublas \
      --enable-curand

  fi

  # --without-fei \

  make -j
  make check || true
  make install
  popd
  popd
}

build_metis(){
  BASE_DIR=$1
  LOCAL_DIR=$2
  currDir=$(pwd)
  if [ ! -d metis ]; then 
    git clone --depth 1 https://github.com/mfem/tpls.git
    tar xzf tpls/metis-4.0.3.tar.gz
    mv metis-4.0.3 metis
    rm -rf tpls
  fi

  pushd metis
  # The Makefile in metis is broken
  sed -i 's/^CC = cc$/CC ?= cc/' Makefile.in
  CC=${LLVM_INSTALL_DIR}/bin/clang CXX=${LLVM_INSTALL_DIR}/bin/clang++ CPP=${LLVM_INSTALL_DIR}/bin/clang++ make -C Lib OPTFLAGS=-Wno-error=implicit-function-declaration
  cp libmetis.a $LOCAL_DIR/lib/
  popd
}

build_mfem(){
  BASE_DIR=$1
  LOCAL_DIR=$2
  mfem_version=$3
  use_mneme=$4
  if [ ! -d mfem ]; then
    git clone --branch ${mfem_version} --depth 1 https://github.com/mfem/mfem.git
  fi
  pushd mfem
  # git fetch --tags
  # git checkout ${mfem_version} 
  make distclean
  echo "mpicxx = $(which mpicxx)"
  if [[ "$use_mneme" == "on" ]]; then
    CXX=mpicxx make pcuda CUDA_ARCH=$CUDA_ARCH CLANG_CUDA_FLAGS="-fpass-plugin=${LOCAL_DIR}/lib64/libregdeviceir.so" METIS_DIR=$LOCAL_DIR/lib -j MPICXX=mpicxx HYPRE_OPT=-I${LOCAL_DIR}/include HYPRE_LIB=-L${LOCAL_DIR}/lib
  else
    set -x
    CXX=mpicxx PREFIX=${LOCAL_DIR} CUDA_CXX=${LLVM_INSTALL_DIR}/bin/clang++ make pcuda CUDA_ARCH="sm_70" METIS_DIR=$LOCAL_DIR/lib -j MPICXX=mpicxx HYPRE_OPT=-I${LOCAL_DIR}/include HYPRE_LIB=-L${LOCAL_DIR}/lib -lHYPRE
    set +x
  fi
  make -j
  make install
  # LD_LIBRARY_PATH=${LOCAL_DIR}/lib:$LD_LIBRARY_PATH make check
  popd
  popd
}


build_proteus() {
  echo "Building PROTEUS"
  
  if [[ ! -d "proteus" ]]; then
    git clone --depth 1 --branch "$5" https://github.com/Olympus-HPC/proteus.git
  fi
  pushd proteus

  PROTEUS_ENABLE_HIP=$1
  PROTEUS_ENABLE_CUDA=$2
  PROTEUS_INSTALL_DIR=$3
  LINK_SHARED_LLVM=$4

  mkdir -p build-proteus-${host}
  pushd build-proteus-${host}
  cmake .. \
    -DBUILD_SHARED=Off \
    -DLLVM_INSTALL_DIR=${LLVM_INSTALL_DIR} \
    -DCMAKE_C_COMPILER=${LLVM_INSTALL_DIR}/bin/clang \
    -DCMAKE_CXX_COMPILER=${LLVM_INSTALL_DIR}/bin/clang++ \
    -DPROTEUS_ENABLE_HIP=${PROTEUS_ENABLE_HIP} \
    -DPROTEUS_LINK_SHARED_LLVM=${LINK_SHARED_LLVM} \
    -DPROTEUS_ENABLE_CUDA=${PROTEUS_ENABLE_CUDA} \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=on \
    -DENABLE_TESTS=Off \
    -DCMAKE_INSTALL_PREFIX=${PROTEUS_INSTALL_DIR}
  make -j 10
  make install -j 10
  popd
  popd
}

build_spdlog() {
  echo "Building SPDLOG"
  if [[ ! -d "spdlog" ]]; then
    git clone --depth 1 --branch v1.15.0  --single-branch https://github.com/gabime/spdlog.git
  fi
  
  pushd spdlog
  SPDLOG_INSTALL_DIR=$1
  mkdir -p build-spdlog-${host}
  pushd build-spdlog-${host}
  cmake \
  -DCMAKE_C_COMPILER=${LLVM_INSTALL_DIR}/bin/clang \
  -DCMAKE_CXX_COMPILER=${LLVM_INSTALL_DIR}/bin/clang++ \
  -DCMAKE_INSTALL_PREFIX=${SPDLOG_INSTALL_DIR} \
  .. 

  make -j 10
  make install -j 10
  popd
  popd
}

build_mneme() {
    installDir=$1
    mneme_version=$2

    if [[ ! -d "Mneme" ]]; then
        git clone --depth 1 --branch $mneme_version https://github.com/Olympus-HPC/Mneme.git
    fi

    mneme_src="$(pwd)/Mneme"
    build_dir="build-mneme"
    mkdir -p $build_dir
    pushd $build_dir 
    cuda_gencode=$(echo $CUDA_ARCH | sed 's/[^0-9]*//g')
    echo "Current dir is $(pwd) with GPU code ${cuda_gencode}"
    cmake \
    -DCMAKE_BUILD_TYPE=Debug \
    -Dproteus_DIR=$installDir \
    -DCMAKE_INSTALL_PREFIX=$installDir \
    -DCMAKE_CXX_COMPILER=${LLVM_INSTALL_DIR}/bin/clang++ \
    -DCMAKE_C_COMPILER=${LLVM_INSTALL_DIR}/bin/clang \
    -DMNEME_LINK_SHARED_LLVM=ON \
    -DCMAKE_CUDA_COMPILER=${LLVM_INSTALL_DIR}/bin/clang++ \
    -DCMAKE_CUDA_ARCHITECTURES=${cuda_gencode} \
    -DLLVM_INSTALL_DIR=${LLVM_INSTALL_DIR} \
    -DMNEME_ENABLE_HIP=Off \
    -DMNEME_ENABLE_CUDA=On \
    -DMNEME_ENABLE_DEBUG=On \
    -DMNEME_ENABLE_TESTS=On \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=on ${mneme_src}
    make -j 10
    make -j 10 install
    popd
}

build_llvm () {
    # Install Clang/LLVM through conda.
    MINICONDA_DIR=miniconda3
    if [[ ! -d ${MINICONDA_DIR} ]]; then
        mkdir -p ${MINICONDA_DIR}
        wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-$(uname -m).sh -O ./${MINICONDA_DIR}/miniconda.sh
        bash ./${MINICONDA_DIR}/miniconda.sh -b -u -p ./${MINICONDA_DIR}
        rm ./${MINICONDA_DIR}/miniconda.sh
        source ./${MINICONDA_DIR}/bin/activate
        conda create -y -n mneme -c conda-forge \
            python=3.10 clang=18.1.8 clangxx=18.1.8 llvmdev=18.1.8 lit=18.1.8 openblas==0.3.21 libopenblas==0.3.21
    else
        source ./${MINICONDA_DIR}/bin/activate
    fi
    conda activate mneme

    LLVM_INSTALL_DIR=$(llvm-config --prefix)
    export LLVM_INSTALL_DIR=$(llvm-config --prefix)
    echo "Setting root dir to be ${LLVM_INSTALL_DIR}"

    if [[ "$with_mneme" == "on" ]]; then
      if [[ ! -d "Mneme" ]]; then
        echo "Cloning Mneme"
        git clone --depth 1 --branch develop https://github.com/Olympus-HPC/Mneme.git
      fi
      # We use the conda env defined earlier
      pip install ./Mneme
    fi

}

mkdir -p deps/
pushd deps/
BASE_DIR=$(pwd)
LOCAL_DIR=$(pwd)/usr/${SYS_TYPE}/
mkdir -p ${LOCAL_DIR}
mneme_config=$(realpath user.mk)
export with_mneme="$1"


echo "Loading env"

# Lassen only
if [[ "$SYS_TYPE" == "blueos_3_ppc64le_ib_p9" ]]; then
    source /etc/profile.d/z00_lmod.sh
    ml load gcc/11.2.1
    ml load cmake/3.23
    ml load cuda/12.2
    export CUDA_ARCH="sm_70"
elif [[ "$SYS_TYPE" == "toss_4_x86_64_ib_cray" ]]; then
    # module load cmake/3.29.2
    # module load rocm/6.3
    # module load rocmcc/6.3.1-cce-18.0.1h-magic
    echo "ROCM is not supported by this script"
    exit 1
fi

build_llvm
# build_proteus "OFF" "ON" $LOCAL_DIR ON "features/mneme-integrations"
# # echo "After proteus Current directory is $(pwd)"
# build_spdlog $LOCAL_DIR
# build_mneme $LOCAL_DIR develop

echo "Building HYPRE"
build_hypre ${BASE_DIR} ${LOCAL_DIR} v2.32.0 $with_mneme
echo "Building METIS"
build_metis ${BASE_DIR} ${LOCAL_DIR}
echo "Building MFEM"
build_mfem ${BASE_DIR} ${LOCAL_DIR} v4.7 $with_mneme

echo "We are in $(pwd)"

sed -i 's|^MFEM_DIR ?= \.\./mfem$|MFEM_DIR ?= deps/mfem/|' makefile
sed -i 's/^LAGHOS_LIBS = \$(MFEM_LIBS) \$(MFEM_EXT_LIBS)$/LAGHOS_LIBS = \$(MFEM_LIBS) \$(MFEM_EXT_LIBS) -lHYPRE -lcurand -lcublas/' makefile

if [[ "$with_mneme" == "on" ]]; then
  echo "Building Laghos with Mneme"
  LDFLAGS=${LOCAL_DIR}/lib64/libmneme_shallow.so make -j4
else
  echo "Building Laghos without Mneme"
  make -j4
fi
