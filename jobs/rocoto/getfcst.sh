#!/bin/ksh -x

###############################################################
## Abstract:
## Get GFS intitial conditions
## RUN_ENVIR : runtime environment (emc | nco)
## HOMEgfs   : /full/path/to/workflow
## EXPDIR : /full/path/to/config/files
## CDATE  : current date (YYYYMMDDHH)
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
configs="base getfcst"
for config in $configs; do
    . $EXPDIR/config.${config}
    status=$?
    [[ $status -ne 0 ]] && exit $status
done

###############################################################
# Source machine runtime environment
. $BASE_ENV/${machine}.env getfcst
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
# Set script and dependency variables

export GDATE=$($NDATE -${assim_freq:-"06"} $CDATE)
export gyy=$(echo $GDATE | cut -c1-4)
export gmm=$(echo $GDATE | cut -c5-6)
export gdd=$(echo $GDATE | cut -c7-8)
export ghh=$(echo $GDATE | cut -c9-10)

export DATA=${DATA:-${DATAROOT}/getfcst}

# Create ROTDIR/EXTRACT_DIR
if [ ! -d $ROTDIR ]; then mkdir -p $ROTDIR ; fi
cd $ROTDIR

if [ ! -s ${ROTDIR}/${CDUMP}.${gyy}${gmm}${gdd}/${ghh}/atmos/${CDUMP}.t${ghh}z.atmf006.nc ]; then
  htar -xvf ${FTARDIR}/${FCSTEXP}/${GDATE}/${CDUMP}_netcdfb.tar
  status=$?
  if [ $status -ne 0 ]; then
    echo "pull data failed"
    exit $status
  fi
fi

if [[ $MODE == "free" ]]; then
  COMOUT=${ICSDIR}/${ICDUMP}.${gyy}${gmm}${gdd}/${ghh}/atmos
  $NLN ${COMOUT}/*abias* ${ROTDIR}/${CDUMP}.${gyy}${gmm}${gdd}/${ghh}/atmos/
  $NLN ${COMOUT}/*radstat ${ROTDIR}/${CDUMP}.${gyy}${gmm}${gdd}/${ghh}/atmos/
else
  htar -tvf  ${FTARDIR}/${FCSTEXP}/${GDATE}/${CDUMP}.tar > ./list1
  >./list2
  grep abias ./list1 | awk '{ print $7 }' >> ./list2
  grep ratstat ./list1 | awk '{ print $7 }' >> ./list2
  htar -xvf $directory/${CDUMP}.tar -L ./list2
fi

exit 0



