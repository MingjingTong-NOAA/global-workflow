#! /usr/bin/env bash
set -eux

source ./machine-setup.sh > /dev/null 2>&1
cwd=`pwd`

USE_PREINST_LIBS=${USE_PREINST_LIBS:-"true"}
if [ $USE_PREINST_LIBS = true ]; then
  export MOD_PATH=/scratch3/NCEPDEV/nwprod/lib/modulefiles
  source ../modulefiles/fv3gfs/gaussian_sfcfcst.$target             > /dev/null 2>&1
else
  export MOD_PATH=${cwd}/lib/modulefiles
  if [ $target = wcoss_cray ]; then
    source ../modulefiles/fv3gfs/gaussian_sfcfcst.${target}_userlib > /dev/null 2>&1
  else
    source ../modulefiles/fv3gfs/gaussian_sfcfcst.$target           > /dev/null 2>&1
  fi
fi
module list

cd ${cwd}/gaussian_sfcfcst.fd
./makefile.sh
