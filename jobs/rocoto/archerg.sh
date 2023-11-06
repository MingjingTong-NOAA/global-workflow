#! /usr/bin/env bash

source "$HOMEgfs/ush/preamble.sh"

###############################################################
## Abstract:
## Archive driver script
## RUN_ENVIR : runtime environment (emc | nco)
## HOMEgfs   : /full/path/to/workflow
## EXPDIR : /full/path/to/config/files
## CDATE  : current analysis date (YYYYMMDDHH)
## CDUMP  : cycle name (gdas / gfs)
## PDY    : current date (YYYYMMDD)
## cyc    : current cycle (HH)
###############################################################

###############################################################
# Source FV3GFS workflow modules
. $HOMEgfs/ush/load_fv3gfs_modules.sh
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
# Source relevant configs
configs="base enspost archerg"
for config in $configs; do
    . $EXPDIR/config.${config}
    status=$?
    [[ $status -ne 0 ]] && exit $status
done

# archive cycle lag by $assim_freq hours
ARCH_CYC=$cyc

# CURRENT CYCLE
export pfhr=$(printf %03i $post_fhr)
APREFIX="${CDUMP}.t${cyc}z.atmf${pfhr}."
ASUFFIX=${ASUFFIX:-$SUFFIX}
SPREFIX="${CDUMP}.t${cyc}z.sfcf${pfhr}."

###############################################################
# Archive online for verification and diagnostics
###############################################################

COMIN=${COMIN:-"$ROTDIR/enkfgdas.$PDY/$cyc/atmos"}
cd $COMIN

[[ ! -d $ARCDIR ]] && mkdir -p $ARCDIR
$NCP ${APREFIX}ensspread.grib.nc $ARCDIR/${CDUMP}.atmf${pfhr}.ensspread.${CDATE}.nc
$NCP ${APREFIX}ensmean.grib.nc $ARCDIR/${CDUMP}.atmf${pfhr}.ensmean.${CDATE}.nc
$NCP ${SPREFIX}ensspread.grib.nc $ARCDIR/${CDUMP}.sfcf${pfhr}.ensspread.${CDATE}.nc
$NCP ${SPREFIX}ensmean.grib.nc $ARCDIR/${CDUMP}.sfcf${pfhr}.ensmean.${CDATE}.nc

###############################################################
# Archive data to HPSS
if [ $HPSSARCH = "YES" ]; then
###############################################################

rm -f enregrid.txt
touch enregrid.txt

echo  "./${APREFIX}ensspread.grib${ASUFFIX}" >>enregrid.txt
echo  "./${APREFIX}ensmean.grib${ASUFFIX}" >>enregrid.txt
echo  "./${SPREFIX}ensspread.grib${ASUFFIX}" >>enregrid.txt
echo  "./${SPREFIX}ensmean.grib${ASUFFIX}" >>enregrid.txt

htar -P -cvf $ATARDIR/$CDATE/enregrid.tar `cat ./enregrid.txt`
status=$?
if [ $status -ne 0  ]; then
    echo "htar -P -cvf failed, ABORT!"
    exit $status
fi

###############################################################
# Remove data directory
###############################################################
rm -rf $COMIN

###############################################################
fi  ##end of HPSS archive
###############################################################

exit 0
