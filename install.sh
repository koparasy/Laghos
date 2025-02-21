ml load  cmake/3.29.2
ml load rocm/6.3
ml load rocmcc/6.3.1-cce-18.0.1h-magic

set -e

build_spdlog(){
  BASE_DIR=$1
  LOCAL_DIR=$2
  spdlog_version=$3

  if [[ ! -d "spdlog" ]]; then
    git clone --branch ${spdlog_version} --depth 1 https://github.com/gabime/spdlog.git
  fi

  src_dir=$(pwd)/spdlog
  build_dir=build-spdlog

  cmake -B $build_dir \
  -DCMAKE_C_COMPILER=${LLVM_INSTALL_DIR}/bin/clang \
  -DCMAKE_CXX_COMPILER=${LLVM_INSTALL_DIR}/bin/clang++ \
  -DCMAKE_INSTALL_PREFIX=${LOCAL_DIR} \
  ${src_dir}
  cmake --build $build_dir -j && cmake --install $build_dir 
}

build_proteus() {
  BASE_DIR=$1
  LOCAL_DIR=$2
  proteus_version=$3

  if [[ ! -d "proteus" ]]; then
    git clone --depth 1 --branch $proteus_version git@github.com:Olympus-HPC/proteus.git
  fi
  
  src_dir=$(pwd)/proteus/
  build_dir=build-proteus

  cmake -B $build_dir \
  -DBUILD_SHARED=Off \
  -DLLVM_INSTALL_DIR=${LLVM_INSTALL_DIR} \
  -DCMAKE_C_COMPILER=${LLVM_INSTALL_DIR}/bin/clang \
  -DCMAKE_CXX_COMPILER=${LLVM_INSTALL_DIR}/bin/clang++ \
  -DPROTEUS_ENABLE_HIP=On \
  -DPROTEUS_ENABLE_CUDA=Off \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=On \
  -DENABLE_TESTS=Off \
  -DCMAKE_INSTALL_PREFIX=${LOCAL_DIR} \
  $src_dir
  cmake --build $build_dir -j && cmake --install $build_dir 
}

build_mneme() {
  BASE_DIR=$1
  LOCAL_DIR=$2
  mneme_version=$3
  echo "Current dir is $(pwd)"

  if [[ ! -d "Mneme" ]]; then
    git clone --depth 1 --branch $mneme_version git@github.com:Olympus-HPC/Mneme.git
  fi
  
  src_dir=$(pwd)/Mneme/
  build_dir=build-mneme

  cmake -B $build_dir \
    -DCMAKE_BUILD_TYPE=Relwithdebinfo \
    -Dproteus_DIR=${LOCAL_DIR}\
    -DCMAKE_C_COMPILER=${LLVM_INSTALL_DIR}/bin/clang \
    -DCMAKE_CXX_COMPILER=${LLVM_INSTALL_DIR}/bin/clang++ \
    -DLLVM_INSTALL_DIR=${LLVM_INSTALL_DIR} \
    -DMNEME_ENABLE_HIP=On \
    -DMNEME_ENABLE_DEBUG=On \
    -DMNEME_ENABLE_TESTS=On \
    -DCMAKE_INSTALL_PREFIX=${LOCAL_DIR} \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=on \
    $src_dir
  cmake --build $build_dir -j && cmake --install $build_dir 
}


build_hypre(){
  BASE_DIR=$1
  LOCAL_DIR=$2
  hypre_version=$3
  if [ ! -d hypre ]; then
    git clone --depth 1 --branch $hypre_version https://github.com/hypre-space/hypre.git
  fi

  pushd hypre
  pushd src
  rocm_path=$(realpath $(dirname $(which hipcc))/../)
  rocm_mpi_path=$(realpath $(dirname $(which mpicc))/../)
  #make distclean
  #-fpass-plugin=/usr/workspace/koparasy/Laghos-all/usr/toss_4_x86_64_ib_cray/lib64/libregdeviceir.so 
  CUFLAGS="-O3 -std=c++14 -x hip --offload-arch=gfx90a" CC=mpicc CXX=mpicxx CXXFLAGS="std=c++17 -fPIC" CFLAGS="-fPIC" ./configure \
    --prefix=$LOCAL_DIR \
    --with-MPI-libs="mpi mpich" \
    --with-MPI-lib-dirs=${rocm_mpi_path}/lib \
    --with-MPI-include=${rocm_mpi_path}/include \
    --enable-fortran \
    --with-hip \
    --enable-mneme
    
  make -j
  make check
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

  CC=amdclang CXX=amdclang++ CPP=amdclang++ make -C Lib OPTFLAGS=-Wno-error=implicit-function-declaration
  cp libmetis.a $LOCAL_DIR/lib/  
  popd

}

build_parmetis(){
  BASE_DIR=$1
  LOCAL_DIR=$2
  currDir=$(pwd)
  if [ ! -d parmetis ]; then 
    curl -OL https://github.com/mfem/tpls/raw/gh-pages/parmetis-4.0.3.tar.gz
    tar xzf parmetis-4.0.3.tar.gz
    mv parmetis-4.0.3 parmetis
  fi

  pushd parmetis
  root_dir=$(pwd)/
  cmake -B build \
    -DCMAKE_CXX_FLAGS="-fPIC" \
    -DCMAKE_C_FLAGS="-fPIC" \
    -DGKLIB_PATH=$root_dir/metis/GKlib \
    -DMETIS_PATH=$root_dir/metis/
    -DCMAKE_INSTALL_PREFIX=$LOCAL_DIR \
    -DSHARED=1 \
    -DCMAKE_C_COMPILER=mpicc \
    -DCMAKE_CXX_COMPILER=mpicxx 
  cmake --build build -j && cmake --install build
}

build_mfem(){
  BASE_DIR=$1
  LOCAL_DIR=$2
  mfem_version=$3
  if [ ! -d mfem ]; then
    git clone --branch ${mfem_version} --depth 1 https://github.com/mfem/mfem.git
  fi
  pushd mfem 
  # git fetch --tags
  # git checkout ${mfem_version} 
  CXX=mpicxx make phip HIP_ARCH=gfx90a METIS_DIR=$LOCAL_DIR/lib -j MPICXX=mpicxx HYPRE_OPT=-I${LOCAL_DIR}/include HYPRE_LIB=-L${LOCAL_DIR}/lib
  #popd
  #mkdir build
  #pushd build
  #CXX=mpicxx cmake \
  #  -DCMAKE_BUILD_TYPE=Relwithdebinfo \
  #  -DMFEM_USE_HIP=ON \
  #  -DMFEM_USE_MPI=ON \
  #  -DMETIS_DIR=${LOCAL_DIR} \
  #  -DMETIS_INCLUDE_DIR=${LOCAL_DIR}/include \
  #  -DParMETIS_DIR=${LOCAL_DIR} \
  #  -DCMAKE_INSTALL_PREFIX=${LOCAL_DIR} \
  #  -DCMAKE_HIP_ARCHITECTURES="gfx90a" \
  #  -DCMAKE_HIP_PLATFORM="amd" \
  #  -DHYPRE_DIR=${LOCAL_DIR} \
  #  ..
  make -j
  make install
  popd
  popd
}

mkdir -p deps/
pushd deps/
BASE_DIR=$(pwd)
LOCAL_DIR=$(pwd)/usr/${SYS_TYPE}/
mkdir -p ${LOCAL_DIR}


if [ -z "${ROCM_PATH}" ]; then
  echo "ROCM_PATHis not set or is empty"
  echo "... cannot build proteus without ROCM_PATH"
  exit
else
  echo "ROCM_PATH is '$ROCM_PATH'"
fi
 
export LLVM_INSTALL_DIR=${ROCM_PATH}/llvm
echo ${LLVM_INSTALL_DIR}


#echo "Building SPDLOG"
#build_spdlog ${BASE_DIR} ${LOCAL_DIR} v1.15.0 
#echo "Building PROTEUS"
#build_proteus ${BASE_DIR} ${LOCAL_DIR} main 
#echo "Building MNEME"
#build_mneme ${BASE_DIR} ${LOCAL_DIR} sc-25 
#echo "Building HYPRE"
#build_hypre ${BASE_DIR} ${LOCAL_DIR} v2.32.0
echo "Building METIS"
#build_metis ${BASE_DIR} ${LOCAL_DIR} 
echo "Building MFEM"
build_mfem ${BASE_DIR} ${LOCAL_DIR} v4.7

