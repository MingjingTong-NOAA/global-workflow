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
configs="base getic init"
for config in $configs; do
    . $EXPDIR/config.${config}
    status=$?
    [[ $status -ne 0 ]] && exit $status
done

###############################################################
# Source machine runtime environment
. $BASE_ENV/${machine}.env getic
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
# Set script and dependency variables

export yy=$(echo $CDATE | cut -c1-4)
export mm=$(echo $CDATE | cut -c5-6)
export dd=$(echo $CDATE | cut -c7-8)
export hh=${cyc:-$(echo $CDATE | cut -c9-10)}
export GDATE=$($NDATE -${assim_freq:-"06"} $CDATE)
export gyy=$(echo $GDATE | cut -c1-4)
export gmm=$(echo $GDATE | cut -c5-6)
export gdd=$(echo $GDATE | cut -c7-8)
export ghh=$(echo $GDATE | cut -c9-10)
export IAUSDATE=$($NDATE -3 $CDATE)
export iyy=$(echo $IAUSDATE | cut -c1-4)
export imm=$(echo $IAUSDATE | cut -c5-6)
export idd=$(echo $IAUSDATE | cut -c7-8)
export ihh=$(echo $IAUSDATE | cut -c9-10)

export DATA=${DATA:-${DATAROOT}/getic}
export EXTRACT_DIR=${DATA:-$EXTRACT_DIR}
export PRODHPSSDIR=${PRODHPSSDIR:-/NCEPPROD/hpssprod/runhistory}
export COMPONENT="atmos"
export gfs_ver=${gfs_ver:-"v16"}
export OPS_RES=${OPS_RES:-"C768"}
export GETICSH=${GETICSH:-${GDASINIT_DIR}/get_v16.data.sh}
export rungcycle=${rungcycle:-"YES"}
export replay_4DIAU=${replay_4DIAU:-"NO"}

# Run UFS_UTILS GETICSH
if [ ! -s ${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/gdas.t${hh}z.atmanl.nc ]; then
  if [ ! -d $EXTRACT_DIR ]; then mkdir -p $EXTRACT_DIR ; fi
  cd $EXTRACT_DIR

  sh ${GETICSH} ${ICDUMP}
  status=$?
  [[ $status -ne 0 ]] && exit $status

else
  echo "IC atmanl exists, skip pulling data"
fi

##########################################
# Remove the Temporary working directory
##########################################

if [ -d $DATAROOT ]; then 
cd $DATAROOT
[[ $KEEPDATA = "NO" ]] && rm -rf $DATA
fi

###############################################################
# Exit out cleanly
exit 0
