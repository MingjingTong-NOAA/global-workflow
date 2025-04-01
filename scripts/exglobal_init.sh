#! /usr/bin/env bash

###############################################################
####  UNIX Script Documentation Block
# 
# Script name:    exglobal_getic.sh 
# Script description:  Get GFS/SHiELD intitial conditions
#
# Author: Mingjing Tong  Org: GFDL    Date: 2025-02-04
#
# $Id$
#
# Attributes:
#   Language: POSIX shell
#
###############################################################

source "${USHgfs}/preamble.sh"

# Directories.
pwd=$(pwd)

set -x

###############################################################
# Set script and dependency variables

export yy=$(echo $CDATE | cut -c1-4)
export mm=$(echo $CDATE | cut -c5-6)
export dd=$(echo $CDATE | cut -c7-8)
export hh=${cyc:-$(echo $CDATE | cut -c9-10)}

export IAUSDATE=$($NDATE -3 $CDATE)
export iPDY=$(echo $IAUSDATE | cut -c1-8)
export icyc=$(echo $IAUSDATE | cut -c9-10)

export DATA=${DATA:-${DATAROOT}/init}
export EXTRACT_DIR=${EXTRACT_DIR:-$ICSDIR}
export WORKDIR=${WORKDIR:-$DATA}
export OUTDIR=${OUTDIR:-${ICSDIR}/output}
export COMPONENT="atmos"
export gfs_ver=${gfs_ver:-"v16"}
export OPS_RES=${OPS_RES:-"C768"}
export LEVS=$LEVS_INIT
export RUNICSH=${RUNICSH:-${GDAS_INIT_DIR}/run_v16.chgres.sh}
export RUNSFCANLSH=${RUNSFCANLSH:-$HOMEgfs/ush/run_sfcanl_chgres.sh}
export DOGCYCLE=${DOGCYCLE:-"YES"}

# Check if init is needed and run if so
if [[ $gfs_ver = "v16" && $EXP_WARM_START = ".true." && $CASE = $OPS_RES ]]; then
  echo "Detected v16 $OPS_RES warm starts, will not run init. Exiting..."
elif [[ "${MODE}" == "forecast-only" && "${EXP_WARM_START}" == ".true." ]]; then
  echo "warm-start forecast only, will not run init. Exiting..."  
else
  # Run chgres_cube for atmanl and sfcanl on gaussian grid
  if [[ "${MODE}" == "forecast-only" || "${compute_iau_inc:-".false."}" == ".true." || ( "${MODE}" == "replay" && "${CDATE}" == "$SDATE" && "${EXP_WARM_START}" != ".true." ) ]]; then
    if [[ ! -d $OUTDIR ]]; then
      mkdir -p $OUTDIR
    fi
    if [[ ! -s ${COMOUT_ATMOS_INPUT}/gfs_ctrl.nc ]]; then
      sh ${RUNICSH} ${ICDUMP}
      status=$?
      [[ $status -ne 0 ]] && exit $status
      if [[ $LEVS_INIT -eq $((ncep_levs + 1)) ]]; then
        for file in $(ls gfs_data.tile*.nc); do
           ncks -d lev,1,$ncep_levs -d levp,1,$LEVS_INIT ${COMOUT_ATMOS_INPUT}/$file -O ${COMOUT_ATMOS_INPUT}/out.nc
           $NMV ${COMOUT_ATMOS_INPUT}/out.nc ${COMOUT_ATMOS_INPUT}/$file
        done
        ncks -d levsp,1,$LEVS_INIT ${COMOUT_ATMOS_INPUT}/gfs_ctrl.nc -O ${COMOUT_ATMOS_INPUT}/out.nc
        $NMV ${COMOUT_ATMOS_INPUT}/out.nc ${COMOUT_ATMOS_INPUT}/gfs_ctrl.nc
      fi
    else
      echo "data exist, skip chgres"
    fi
  fi
    
  # Interpolate GFS surface analysis file to be used by gcycle to replace tsfc with tref for replay or DA cycling
  if [[ "${MODE}" != "forecast-only" && ("${DO_TSFC_TILE}" == "YES" || "${DO_SFCANL}" != "YES" ) && ("${CDATE}" != "$SDATE" || "${EXP_WARM_START}" == ".true.") ]]; then
    if [[ $CASE != $OPS_RES && ! -s ${COMOUT_ATMOS_ANALYSIS_RESTART}/${iPDY}.${icyc}0000.sfcanl_data.tile6.nc ]]; then
      sh ${RUNSFCANLSH} ${ICDUMP} ${IAUSDATE} ${CASE} ${COMOUT_ATMOS_ANALYSIS_RESTART} 
      status=$?
      [[ $status -ne 0 ]] && exit $status 
    fi
    if [[ "${MODE}" == "cycled" ]]; then
      if [[ ! -s ${COMOUT_ATMOS_ANALYSIS_RESTART_ENS}/${iPDY}.${icyc}0000.sfcanl_data.tile6.nc && $DOHYBVAR = "YES" ]]; then
        sh ${RUNSFCANLSH} ${ICDUMP} ${IAUSDATE} ${CASE_ENS} ${COMOUT_ATMOS_ANALYSIS_RESTART_ENS}
        status=$?
        [[ $status -ne 0 ]] && exit $status
      fi
    fi
    if [[ "${CASE}" != "${OPS_RES}" && ("${MODE}" == "cycled" || "${DO_SFCANL}" == "YES") ]]; then
      if [[ ! -s ${COMOUT_ATMOS_ANALYSIS_RESTART}/${PDY}.${cyc}0000.sfcanl_data.tile6.nc ]]; then
        sh ${RUNSFCANLSH} ${ICDUMP} ${CDATE} ${CASE} ${COMOUT_ATMOS_ANALYSIS_RESTART}
        status=$?
        [[ $status -ne 0 ]] && exit $status
      fi
    fi
  fi
  if [[ "${MODE}" == "replay" && "${DO_SFCANL}" != "YES" ]]; then
    [[ ! -d ${COM_ATMOS_RESTART_TMPL} ]] && mkdir -p ${COM_ATMOS_RESTART_TMPL}
    #cd ${COMOUT_ATMOS_ANALYSIS_RESTART}
    if [[ "${CASE}" == "${OPS_RES}" ]]; then
      #for file in $(ls ${iPDY}.${icyc}0000.sfcanl_data.tile*.nc); do
      #   $NLN $file ${COM_ATMOS_RESTART_TMPL}/
      #done
      $NLN ${COMIN_ATMOS_ANALYSIS_RESTART}/${iPDY}.${icyc}0000.sfcanl_data.tile*.nc ${COM_ATMOS_RESTART_TMPL}/
    else
      $NLN ${COMOUT_ATMOS_ANALYSIS_RESTART}/${iPDY}.${icyc}0000.sfcanl_data.tile*.nc ${COM_ATMOS_RESTART_TMPL}/
    fi
  fi
fi

exit 0
