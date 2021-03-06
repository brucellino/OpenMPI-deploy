#!/bin/bash -e
. /etc/profile.d/modules.sh
#SOURCE_FILE=$NAME-$VERSION.tar.gz
# We will build the code from the github repo, but if we want specific versions,
# a new Jenkins job will be created for the version number and we'll provide
# the URL to the tarball in the configuration.

IFS='.' read -r -a array <<< "$VERSION"
VERSION_MAJOR=${array[0]}
VERSION_MINOR=${array[1]}

SOURCE_REPO="http://www.open-mpi.org/software/ompi/v${VERSION_MAJOR}.${VERSION_MINOR}/downloads/"
# We pretend that the $SOURCE_FILE is there, even though it's actually a dir.
NAME="openmpi"
SOURCE_FILE="${NAME}-${VERSION}.tar.gz"

module load ci
#  Add prerequistes
module add gmp
module add mpfr
module add mpc
module add ncurses
module load gcc/${GCC_VERSION}
module add torque/2.5.13-gcc-${GCC_VERSION}

#list modules
# we should be seeing ci, all gcc-versions and torque
echo "List all loaded modules"
module list

echo "REPO_DIR is "
echo ${REPO_DIR}
echo "SRC_DIR is "
echo ${SRC_DIR}
echo "WORKSPACE is "
echo ${WORKSPACE}
echo "SOFT_DIR is"
echo ${SOFT_DIR}

mkdir -p ${WORKSPACE}
mkdir -p ${SRC_DIR}
mkdir -p ${SOFT_DIR}

#  Download the source file

if [ ! -e ${SRC_DIR}/${SOURCE_FILE}.lock ] && [ ! -s ${SRC_DIR}/${SOURCE_FILE} ] ; then
  touch  ${SRC_DIR}/${SOURCE_FILE}.lock
  echo "seems like this is the first build - Let's get the $SOURCE_FILE from $SOURCE_REPO and unarchive to $WORKSPACE"
  mkdir -p ${SRC_DIR}
  wget ${SOURCE_REPO}/${SOURCE_FILE} -O ${SRC_DIR}/${SOURCE_FILE}
  echo "releasing lock"
  rm -v ${SRC_DIR}/${SOURCE_FILE}.lock
elif [ -e ${SRC_DIR}/${SOURCE_FILE}.lock ] ; then
  # Someone else has the file, wait till it's released
  while [ -e ${SRC_DIR}/${SOURCE_FILE}.lock ] ; do
    echo " There seems to be a download currently under way, will check again in 5 sec"
    sleep 5
  done
else
  echo "continuing from previous builds, using source at " ${SRC_DIR}/${SOURCE_FILE}
fi

tar -xzf ${SRC_DIR}/${SOURCE_FILE} -C ${WORKSPACE} --skip-old-files
cd ${WORKSPACE}/${NAME}-${VERSION}

echo "Configuring the build"
FC=`which gfortran` \ 
CC=`which gcc` \
CXX=`which g++` \
LDFLAGS="-static-libstdc++" \
./configure --prefix=${SOFT_DIR}-gcc-${GCC_VERSION} \
 --enable-heterogeneous \
 --enable-mpi-thread-multiple \
 --with-tm=${TORQUE_DIR}
echo "Running the build"
make all
