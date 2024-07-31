#!/bin/bash

copy_data()
{

mkdir -p $SAVEDIR

for tile in 'tile1' 'tile2' 'tile3' 'tile4' 'tile5' 'tile6'
do
  cp out.sfc.${tile}.nc  ${SAVEDIR}/${yy_d}${mm_d}${dd_d}.${hh_d}0000.sfcanl_data.${tile}.nc 
done
}

#---------------------------------------------------------------------------
# Run chgres using v16 netcdf history data as input.  These history
# files are part of the OPS v16 gfs/gdas/enkf tarballs, and the
# v16 retro parallel gfs tarballs.  To run using the v16 retro
# gdas tarballs (which contain warm restart files), the 
# run_v16retro.chgres.sh is used.
#---------------------------------------------------------------------------

set -x

MEMBER=$1
date10=$2
CTAR=$3

FIX_FV3=$UFS_DIR/fix
FIX_ORO=${FIX_FV3}/orog
FIX_AM=${FIX_FV3}/am

WORKDIR=${WORKDIR:-$OUTDIR/work.${MEMBER}}
MODE=${MODE:-"cycled"}
CINP=${OPS_RES}

if [ ${CTAR} == 'C48' ] ; then
  OCNRES='500'
elif [ ${CTAR} == 'C96' ]; then
  OCNRES='500'
elif [ ${CTAR} == 'C192' ]; then
  OCNRES='050'
elif [ ${CTAR} == 'C384' ]; then
  OCNRES='025'
elif [ ${CTAR} == 'C768' ]; then
  OCNRES='025'
elif [ ${CTAR} == 'C1152' ]; then
  OCNRES='025'
else
  OCNRES='025'
fi

ORO_DIR="${CTAR}"
ORO_NAME="${CTAR}.mx${OCNRES}_oro_data"
OROI_NAME="${CINP}.mx${OCNRES}_oro_data"
#---------------------------------------------------------------------------
# Some gfs tarballs from the v16 retro parallels dont have 'atmos'
# in their path.  Account for this.
#---------------------------------------------------------------------------
  INPUT_DATA_DIR="${EXTRACT_DIR}/${MEMBER}.${yy}${mm}${dd}/${hh}/atmos/RESTART_GFS"
  if [ ! -d ${INPUT_DATA_DIR} ]; then
    INPUT_DATA_DIR="${EXTRACT_DIR}/${MEMBER}.${yy}${mm}${dd}/${hh}/RESTART_GFS"
  fi
  #date10=`$NDATE -3 $yy$mm$dd$hh`
  #date10=$IAUSDATE
  yy_d=$(echo $date10 | cut -c1-4)
  mm_d=$(echo $date10 | cut -c5-6)
  dd_d=$(echo $date10 | cut -c7-8)
  hh_d=$(echo $date10 | cut -c9-10)

  SFCTILE1="${yy_d}${mm_d}${dd_d}.${hh_d}0000.sfcanl_data.tile1.nc"
  SFCTILE2="${yy_d}${mm_d}${dd_d}.${hh_d}0000.sfcanl_data.tile2.nc"
  SFCTILE3="${yy_d}${mm_d}${dd_d}.${hh_d}0000.sfcanl_data.tile3.nc"
  SFCTILE4="${yy_d}${mm_d}${dd_d}.${hh_d}0000.sfcanl_data.tile4.nc"
  SFCTILE5="${yy_d}${mm_d}${dd_d}.${hh_d}0000.sfcanl_data.tile5.nc"
  SFCTILE6="${yy_d}${mm_d}${dd_d}.${hh_d}0000.sfcanl_data.tile6.nc"

rm -fr $WORKDIR
mkdir -p $WORKDIR
cd $WORKDIR

cat << EOF > fort.41

&config
 fix_dir_target_grid="${FIX_ORO}/${CTAR}/sfc"
 mosaic_file_input_grid="${FIX_ORO}/${CINP}/${CINP}_mosaic.nc"
 mosaic_file_target_grid="${FIX_ORO}/${CTAR}/${CTAR}_mosaic.nc"
 orog_dir_input_grid="${FIX_ORO}/${CINP}"
 orog_files_input_grid="${OROI_NAME}.tile1.nc","${OROI_NAME}.tile2.nc","${OROI_NAME}.tile3.nc","${OROI_NAME}.tile4.nc","${OROI_NAME}.tile5.nc","${OROI_NAME}.tile6.nc"
 orog_dir_target_grid="${FIX_ORO}/${CTAR}"
 orog_files_target_grid="${ORO_NAME}.tile1.nc","${ORO_NAME}.tile2.nc","${ORO_NAME}.tile3.nc","${ORO_NAME}.tile4.nc","${ORO_NAME}.tile5.nc","${ORO_NAME}.tile6.nc"
 data_dir_input_grid="${INPUT_DATA_DIR}"
 sfc_files_input_grid="${SFCTILE1}","${SFCTILE2}","${SFCTILE3}","${SFCTILE4}","${SFCTILE5}","${SFCTILE6}"
 vcoord_file_target_grid="${vcoord_file_target_grid:-${FIX_AM}/global_hyblev.l${LEVS}.txt}"
 cycle_mon=$mm
 cycle_day=$dd
 cycle_hour=$hh
 convert_atm=.false.
 convert_sfc=.true.
 convert_nst=.true.
 input_type="restart"
/
EOF

$APRUN $UFS_DIR/exec/chgres_cube
rc=$?

if [ $rc != 0 ]; then
  exit $rc
fi

outtype=${outtype:-$MEMBER}
SAVEDIR=$OUTDIR/${outtype}.${yy}${mm}${dd}/${hh}/atmos/RESTART_${CTAR}
copy_data
touch $SAVEDIR/../${MEMBER}.t${hh}z.loginc.txt

rm -fr $WORKDIR

set +x
echo CHGRES COMPLETED FOR MEMBER $MEMBER

exit 0
