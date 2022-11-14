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
configs="base prep archomg"
for config in $configs; do
    . $EXPDIR/config.${config}
    status=$?
    [[ $status -ne 0 ]] && exit $status
done

# ICS are restarts and always lag INC by $assim_freq hours
ARCHINC_CYC=$ARCH_CYC
ARCHICS_CYC=$((ARCH_CYC-assim_freq))
if [ $ARCHICS_CYC -lt 0 ]; then
    ARCHICS_CYC=$((ARCHICS_CYC+24))
fi

# CURRENT CYCLE
APREFIX="${CDUMP}.t${cyc}z."
ASUFFIX=${ASUFFIX:-$SUFFIX}

# Realtime parallels run GFS MOS on 1 day delay
# If realtime parallel, back up CDATE_MOS one day
CDATE_MOS=$CDATE
if [ $REALTIME = "YES" ]; then
    CDATE_MOS=$($NDATE -24 $CDATE)
fi
PDY_MOS=$(echo $CDATE_MOS | cut -c1-8)

###############################################################
# Archive online for verification and diagnostics
###############################################################

COMIN=${COMINatmos:-"$ROTDIR/$CDUMP.$PDY/$cyc/atmos"}
cd $COMIN

[[ ! -d $ARCDIR ]] && mkdir -p $ARCDIR
$NCP ${APREFIX}gsistat $ARCDIR/gsistat.${CDUMP}.${CDATE}
if [[ $MODE != "omf" ]]; then
  $NCP tendency.dat $ARCDIR/tendency.${CDATE}
fi

###############################################################
# Archive data to HPSS
if [ $HPSSARCH = "YES" ]; then
###############################################################

ARCH_LIST="$COMIN/archlist"
[[ -d $ARCH_LIST ]] && rm -rf $ARCH_LIST
mkdir -p $ARCH_LIST
cd $ARCH_LIST

$HOMEgfs/ush/hpssarch_omg.sh $CDUMP
status=$?
if [ $status -ne 0  ]; then
    echo "$HOMEgfs/ush/hpssarch_omg.sh $CDUMP failed, ABORT!"
    exit $status
fi

cd $ROTDIR

htar -P -cvf $ATARDIR/$CDATE/${CDUMP}omg.tar `cat $ARCH_LIST/${CDUMP}omg.txt`
status=$?
if [ $status -ne 0  ]; then
    echo "htar -P -cvf failed, ABORT!"
    exit $status
fi

###############################################################
# Remove IC data directory
###############################################################
RMCDUMP=${RMCDUMP:-"NO"}
GDATEEND=$($NDATE -${RMOLDEND:-72} $CDATE)
GDATE=$($NDATE -${RMOLDSTD:-120} $CDATE)
while [ $GDATE -le $GDATEEND ]; do
    gPDY=$(echo $GDATE | cut -c1-8)
    gcyc=$(echo $GDATE | cut -c9-10)
    COMIN="$ROTDIR/${ICDUMP}.$gPDY/$gcyc"
    rm -rf $COMIN
    if [ $RMCDUMP = "YES" ]; then
       COMIN="$ROTDIR/${CDUMP}.$gPDY/$gcyc"
       rm -rf $COMIN
    fi
    GDATE=$($NDATE +6 $GDATE)
done

###############################################################
fi  ##end of HPSS archive
###############################################################

exit 0
