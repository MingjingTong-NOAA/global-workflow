#!/bin/sh

# module load
. /etc/profile
. /etc/profile.d/modules.sh

module load intel
module load impi

export FFLAGS="-O3 -fp-model precise -g -r8 -i4"
# for debugging
#export FFLAGS="-g -r8 -i4 -warn unused -check bounds"

export NETCDF_INCLUDE="-I${NETCDF}/include"
export NETCDF_LDFLAGS_F="-L${NETCDF}/lib -lnetcdf -lnetcdff -L${HDF5}/lib -lhdf5 "

make clean
make build
err=$?
if [ $err -ne 0 ]; then
  echo ERROR BUILDING GAUSSIAN_SFCFCST_SCALAR_INTRP
  exit 2
fi
make install

exit
