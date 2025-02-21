ml load  cmake/3.29.2
ml load rocm/6.3
ml load rocmcc/6.3.1-cce-18.0.1h-magic

build_hypre(){
  BASE_DIR=$1
  LOCAL_DIR=$2
  hypre_version=$3
  if [ ! -d hypre ]; then
    git clone https://github.com/hypre-space/hypre.git
  fi

  pushd hypre
  #git fetch --tags
  #git checkout $hypre_version 
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
    curl -OL https://github.com/mfem/tpls/raw/gh-pages/metis-4.0.3.tar.gz
    tar xzf metis-4.0.3.tar.gz
    mv metis-4.0.3 metis
  fi

  pushd metis
  make -C Lib OPTFLAGS=-Wno-error=implicit-function-declaration
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
    git clone https://github.com/mfem/mfem.git
  fi
  pushd mfem 
  # git fetch --tags
  # git checkout ${mfem_version} 
  # CXX=mpicxx make phip HIP_ARCH=gfx90a METIS_DIR=$LOCAL_DIR/lib -j MPICXX=mpicxx HYPRE_OPT=-I${LOCAL_DIR}/include HYPRE_LIB=-L${LOCAL_DIR}/lib
  #popd
  mkdir build
  pushd build
  CXX=mpicxx cmake \
    -DCMAKE_BUILD_TYPE=Relwithdebinfo \
    -DMFEM_USE_HIP=ON \
    -DMFEM_USE_MPI=ON \
    -DMETIS_DIR=${LOCAL_DIR} \
    -DMETIS_INCLUDE_DIR=${LOCAL_DIR}/include \
    -DParMETIS_DIR=${LOCAL_DIR} \
    -DCMAKE_INSTALL_PREFIX=${LOCAL_DIR} \
    -DCMAKE_HIP_ARCHITECTURES="gfx90a" \
    -DCMAKE_HIP_PLATFORM="amd" \
    -DHYPRE_DIR=${LOCAL_DIR} \
    ..
  make -j
  make install
  popd
  popd
}

BASE_DIR=$(pwd)
LOCAL_DIR=$(pwd)/usr/${SYS_TYPE}/
mkdir -p ${LOCAL_DIR}

build_hypre ${BASE_DIR} ${LOCAL_DIR} v2.32.0
build_metis ${BASE_DIR} ${LOCAL_DIR} 
build_mfem ${BASE_DIR} ${LOCAL_DIR} v4.7

