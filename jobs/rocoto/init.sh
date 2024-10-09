#! /usr/bin/env bash

source "$HOMEgfs/ush/preamble.sh"

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
. $BASE_ENV/${machine}.env init
status=$?
[[ $status -ne 0 ]] && exit $status

set -x

###############################################################
# Set script and dependency variables

export yy=$(echo $CDATE | cut -c1-4)
export mm=$(echo $CDATE | cut -c5-6)
export dd=$(echo $CDATE | cut -c7-8)
export hh=${cyc:-$(echo $CDATE | cut -c9-10)}

export IAUSDATE=$($NDATE -3 $CDATE)
export iyy=$(echo $IAUSDATE | cut -c1-4)
export imm=$(echo $IAUSDATE | cut -c5-6)
export idd=$(echo $IAUSDATE | cut -c7-8)
export ihh=$(echo $IAUSDATE | cut -c9-10)

export DATA=${DATA:-${DATAROOT}/init}
export EXTRACT_DIR=${EXTRACT_DIR:-$ICSDIR}
export WORKDIR=${WORKDIR:-$DATA}
export OUTDIR=${OUTDIR:-$ICSDIR}
export COMPONENT="atmos"
export gfs_ver=${gfs_ver:-"v16"}
export OPS_RES=${OPS_RES:-"C768"}
export LEVS=$LEVS_INIT
export RUNICSH=${RUNICSH:-${GDAS_INIT_DIR}/run_v16.chgres.sh}
export RUNSFCANLSH=${RUNSFCANLSH:-$HOMEgfs/ush/run_sfcanl_chgres.sh}
export DOGCYCLE=${DOGCYCLE:-"YES"}
COMOUT=${ICSDIR}/${ICDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}
export SAVEDIR=$COMOUT/${CASE}/INPUT

# Check if init is needed and run if so
if [[ $gfs_ver = "v16" && $EXP_WARM_START = ".true." && $CASE = $OPS_RES ]]; then
  echo "Detected v16 $OPS_RES warm starts, will not run init. Exiting..."
elif [[ $MODE = "forecast-only" && $EXP_WARM_START = ".true." ]]; then
  echo "warm-start forecast only, will not run init. Exiting..."  
else
  # Run chgres_cube for atmanl and sfcanl on gaussian grid
  if [[ $MODE = "forecast-only" || $replay == 1 || ( $MODE = "replay" && "$CDATE" = "$SDATE" && "$EXP_WARM_START" != ".true." ) ]]; then
    if [[ ! -d $SAVEDIR ]]; then
      if [[ ! -d $OUTDIR ]]; then mkdir -p $OUTDIR ; fi
      sh ${RUNICSH} ${ICDUMP}
      status=$?
      [[ $status -ne 0 ]] && exit $status
    fi 
    if [[ $replay == 1 && $CDUMP = "gfs" || $MODE = "forecast-only" ]]; then
      COMOUTatmos=${ROTDIR}/gdas.${yy}${mm}${dd}/${hh}/atmos
    else
      COMOUTatmos=${COMOUTatmos}
    fi
    if [[ ! -d ${COMOUTatmos} ]]; then
      mkdir -p ${COMOUTatmos}
    fi
    if [[ ! -d ${COMOUTatmos}/INPUT ]]; then
      if [[ $LEVS_INIT -eq $((ncep_levs + 1)) ]]; then
         mkdir -p ${COMOUTatmos}/INPUT
         cd ${SAVEDIR}
         for file in $(ls gfs_data.tile*.nc); do
            ncks -d lev,1,$ncep_levs -d levp,1,$LEVS_INIT $file -O ${COMOUTatmos}/INPUT/$file
         done
         ncks -d levsp,1,$LEVS_INIT gfs_ctrl.nc -O ${COMOUTatmos}/INPUT/gfs_ctrl.nc
         $NLN ${SAVEDIR}/sfc_data.tile*.nc ${COMOUTatmos}/INPUT/
      else
         $NLN ${SAVEDIR} ${COMOUTatmos}/INPUT
      fi
      if [[ "$ICSDIR" != "$ROTDIR" ]]; then
         $NLN ${COMOUT}/*abias* ${COMOUTatmos}/
         $NLN ${COMOUT}/*radstat ${COMOUTatmos}/
      fi
    fi
  fi
    
  # Interpolate GFS surface analysis file to be used by gcycle to replace tsfc with tref for replay or DA cycling
  if [[ $MODE != "forecast-only" && ($DO_TSFC_TILE == "YES" || $DOGCYCLE != "YES" ) && ("$CDATE" != "$SDATE" || $EXP_WARM_START = ".true.") ]]; then
    if [[ $CASE != $OPS_RES && ! -s $COMOUT/RESTART_${CASE}/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile6.nc ]]; then
      sh ${RUNSFCANLSH} ${ICDUMP} $IAUSDATE $CASE
      status=$?
      [[ $status -ne 0 ]] && exit $status 
    fi
    if [[ $MODE = "cycled" ]]; then
      if [[ ! -s $COMOUT/RESTART_${CASE_ENKF}/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile6.nc && $DOHYBVAR = "YES" ]]; then
        sh ${RUNSFCANLSH} ${ICDUMP} $IAUSDATE $CASE_ENKF
        status=$?
        [[ $status -ne 0 ]] && exit $status
      fi
    fi
    if [[ $CASE != $OPS_RES && ($MODE = "cycled" || $DOGCYCLE == "YES") ]]; then
      if [[ ! -s $COMOUT/RESTART_${CASE}/${yy}${mm}${dd}.${hh}0000.sfcanl_data.tile6.nc ]]; then
        sh ${RUNSFCANLSH} ${ICDUMP} $CDATE $CASE
        status=$?
        [[ $status -ne 0 ]] && exit $status
      fi
    fi
  fi
  if [[ $MODE = "replay" && $DOGCYCLE != "YES" ]]; then
    RESTARTDIR=${ROTDIR}/gdas.${yy}${mm}${dd}/${hh}/atmos/RESTART
    if [[ ! -d ${RESTARTDIR} ]]; then
      mkdir -p $RESTARTDIR
    fi
    if [ $CASE = $OPS_RES ]; then
      $NLN $COMOUT/RESTART_GFS/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile*.nc ${RESTARTDIR}/
    else
      $NLN $COMOUT/RESTART_${CASE}/${iyy}${imm}${idd}.${ihh}0000.sfcanl_data.tile*.nc ${RESTARTDIR}/
    fi
  fi
fi

##########################################
# Remove the Temporary working directory
##########################################
[[ $KEEPDATA = "NO" ]] && rm -rf $DATA

###############################################################
# Exit out cleanly


exit 0
