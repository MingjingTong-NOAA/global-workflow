#! /usr/bin/env bash
################################################################################
####  UNIX Script Documentation Block
#                      .                                             .
# Script name:         exgdas_atmos_analysis_increment.sh
# Script description:  Compute replay increments
#
# Author: Mingjing.Tong      Org: NOAA/GFDL     Date: 2021-06-25
#
# Abstract: This script runs chgres and calc_increment to get replay increment
#
# $Id$
#
# Attributes:
#   Language: POSIX shell
#
#################################################################################

#  Set environment.

source "${USHgfs}/preamble.sh"

#  Directories.
pwd=$(pwd)

# Base variables
CDATE=${CDATE:-"2001010100"}

# Derived base variables
PDY=$(echo $CDATE | cut -c1-8)
cyc=$(echo $CDATE | cut -c9-10)

# Utilities
export CHGRP_CMD=${CHGRP_CMD:-"chgrp ${group_name:-rstprod}"}
export NCLEN=${NCLEN:-${USHgfs}/getncdimlen}

# IAU
export IAUFHRS=${IAUFHRS:-"6"}

# Dependent Scripts and Executables
export APRUN_CHGRES=${APRUN_CHGRES:-${APRUN:-""}}
export CHGRESNCEXEC=${CHGRESNCEXEC:-${EXECgfs}/enkf_chgres_recenter_nc.x}
export NTHREADS_CHGRES=${NTHREADS_CHGRES:-1}
CALCINCPY=${CALCINCPY:-${USHgfs}/calcinc_gfs.py}
export CALCINCNCEXEC=${CALCINCNCEXEC:-${EXECgfs}/calc_increment_ens_ncio.x}
APRUNCFP=${APRUNCFP:-""}

# OPS flags
RUN=${RUN:-""}
SENDECF=${SENDECF:-"NO"}
SENDDBN=${SENDDBN:-"NO"}

# forecast files
APREFIX=${APREFIX:-""}
ATMF03=${ATMF03:-${COM_ATMOS_HISTORY_PREV}/${GPREFIX}atmf003.nc}
ATMF06=${ATMGES:-${COM_ATMOS_HISTORY_PREV}/${GPREFIX}atmf006.nc}
ATMF09=${ATMF09:-${COM_ATMOS_HISTORY_PREV}/${GPREFIX}atmf009.nc}

# external analysis
ATMANLENS03=${ATMANLENS03:-${COMIN_ATMOS_ANALYSIS}/${ICDUMP}.t${cyc}z.atma003.ensres.nc}
ATMANLENS06=${ATMANLENS06:-${COMIN_ATMOS_ANALYSIS}/${ICDUMP}.t${cyc}z.atmanl.ensres.nc}
ATMANLENS09=${ATMANLENS09:-${COMIN_ATMOS_ANALYSIS}/${ICDUMP}.t${cyc}z.atma009.ensres.nc}

# chgres analysis
ATMANLFRES03=${ATMANL03_CHGRES:-${COMOUT_ATMOS_ANALYSIS}/${APREFIX}atma03_fcstres.nc}
ATMANLFRES06=${ATMANL06_CHGRES:-${COMOUT_ATMOS_ANALYSIS}/${APREFIX}atma06_fcstres.nc}
ATMANLFRES09=${ATMANL09_CHGRES:-${COMOUT_ATMOS_ANALYSIS}/${APREFIX}atma09_fcstres.nc}

# chgres forecast
ATMF03ENS=${ATMF03ENS:-${COM_ATMOS_HISTORY_PREV}/${APREFIX}atmf003.ensres.nc}
ATMF06ENS=${ATMF06ENS:-${COM_ATMOS_HISTORY_PREV}/${APREFIX}atmf006.ensres.nc}
ATMF09ENS=${ATMF09ENS:-${COM_ATMOS_HISTORY_PREV}/${APREFIX}atmf009.ensres.nc}
ENSRES=$(( ${OPS_RES:1}/2 ))
ATMFCST_ENSRES=${ATMFCST_ENSRES:-${FIXgfs}/ref_fcst/shield.C${ENSRES}.atmf006.nc}

# analysis increment
ATMINC=${ATMINC:-${COMOUT_ATMOS_ANALYSIS}/${APREFIX}atminc.nc}
ATMI03=${ATMI03:-${COMOUT_ATMOS_ANALYSIS}/${APREFIX}atmi003.nc}
ATMI09=${ATMI09:-${COMOUT_ATMOS_ANALYSIS}/${APREFIX}atmi009.nc}

# Set script / GSI control parameters
USE_CFP=${USE_CFP:-"NO"}
CFP_MP=${CFP_MP:-"NO"}
nm=""
if [ $CFP_MP = "YES" ]; then
    nm=0
fi

################################################################################
################################################################################

# get resolution information
LONB_FCST=${LONB_FCST:-$($NCLEN $ATMF06 grid_xt)} # get LONB_FCST
LATB_FCST=${LATB_FCST:-$($NCLEN $ATMF06 grid_yt)} # get LATB_FCST
LEVS_FCST=${LEVS_FCST:-$($NCLEN $ATMF06 pfull)} # get LEVS_FCST

LONB_ANAL=${LONB_ANAL:-$($NCLEN $ATMANLENS06 grid_xt)} # get LONB_ANAL
LATB_ANAL=${LATB_ANAL:-$($NCLEN $ATMANLENS06 grid_yt)} # get LATB_ANAL
LEVS_ANAL=${LEVS_ANAL:-$($NCLEN $ATMANLENS06 pfull)} # get LEVS_ANAL

# reference forecast resolution
LONB_FREF=${LONB_FREF:-$($NCLEN $ATMFCST_ENSRES grid_xt)} # get LONB_FREF
LATB_FREF=${LATB_FREF:-$($NCLEN $ATMFCST_ENSRES grid_yt)} # get LATB_FREF

REGRID_ANALYSIS="NO"
REGRID_FORECAST="NO"
if [[ $LONB_FCST -ne $LONB_ANAL || $LATB_FCST -ne $LATB_ANAL || $LEVS_FCST -eq $LEVS_ANAL ]]; then
  REGRID_ANALYSIS="YES"
  if [[ $LONB_FCST -gt $LONB_ANAL || $LATB_FCST -gt $LATB_ANAL ]]; then
    REGRID_FORECAST="YES"
  fi
fi
##############################################################
# Regrid external analysis or/and forecast 

export OMP_NUM_THREADS=$NTHREADS_CHGRES
if [[ $REGRID_ANALYSIS == "YES" ]]; then
  if [[ $REGRID_FORECAST == "YES" ]]; then
    if [[ $LONB_FREF -ne $LONB_ANAL || $LATB_FREF -ne $LATB_ANAL ]]; then
      echo "FATAL ERROR: resolution of reference forecast is wrong, ABORT!"
      exit 2
    fi
    $NLN $ATMFCST_ENSRES fcst.06
    LONB_OUT=$LONB_ANAL
    LATB_OUT=$LATB_ANAL 
  else
    $NLN $ATMF06 fcst.06
    LONB_OUT=$LONB_FCST
    LATB_OUT=$LATB_FCST
  fi
  $NLN $ATMANLENS06 anal.06
  $NLN $ATMANLFRES06 anal.fcstres.06
  if [ $REPLAY_4DIAU = "YES" ]; then
    $NLN $ATMANLENS03 anal.03
    $NLN $ATMANLENS09 anal.09
    $NLN $ATMANLFRES03 anal.fcstres.03
    $NLN $ATMANLFRES09 anal.fcstres.09
  fi

  if [ $USE_CFP = "YES" ]; then
     [[ -f $DATA/mp_chgres.sh ]] && rm $DATA/mp_chgres.sh
  fi
  
  nfhrs=$(echo $IAUFHRS | sed 's/,/ /g')
  for FHR in $nfhrs; do
     echo "Regridding deterministic forecast for forecast hour $FHR"
     rm -f chgres_nc_gauss0$FHR.nml
     cat > chgres_nc_gauss0$FHR.nml << EOF
&chgres_setup
i_output=$LONB_OUT
j_output=$LATB_OUT
input_file="anal.0$FHR"
output_file="anal.fcstres.0$FHR"
terrain_file="fcst.06"
ref_file="fcst.06"
${chgres_setup:-}
/
EOF
     if [ $USE_CFP = "YES" ]; then
        echo "$nm $APRUN_CHGRES $CHGRESNCEXEC chgres_nc_gauss0$FHR.nml" | tee -a $DATA/mp_chgres.sh
        if [ ${CFP_MP:-"NO"} = "YES" ]; then
          nm=$((nm+1))
        fi
     else
        export pgm=$CHGRESNCEXEC
        . prep_step
        $APRUN_CHGRES $CHGRESNCEXEC chgres_nc_gauss0$FHR.nml
        export err=$?; err_chk
     fi
  done

  if [ $USE_CFP = "YES" ]; then
     chmod 755 $DATA/mp_chgres.sh
     ncmd=$(cat $DATA/mp_chgres.sh | wc -l)
     if [ $ncmd -gt 0 ]; then
        ncmd_max=$((ncmd < max_tasks_per_node ? ncmd : max_tasks_per_node))
        APRUNCFP_CHGRES=$(eval echo $APRUNCFP)

        export pgm=$CHGRESNCEXEC
        . prep_step

        $APRUNCFP_CHGRES $DATA/mp_chgres.sh
        export err=$?; err_chk
     fi
  fi
fi

if [[ $REGRID_FORECAST == "YES" ]]; then
   $NLN $ATMF06 fcst.06
   $NLN $ATMF06ENS fcst.ensres.06
   $NLN $ATMFCST_ENSRES ref.06
   if [ $REPLAY_4DIAU = "YES" ]; then
      $NLN $ATMF03     fcst.03
      $NLN $ATMF03ENS  fcst.ensres.03
      $NLN $ATMF09     fcst.09
      $NLN $ATMF09ENS  fcst.ensres.09
   fi

   if [ $USE_CFP = "YES" ]; then
      [[ -f $DATA/mp_chgres.sh ]] && rm $DATA/mp_chgres.sh
   fi

   if [ $CFP_MP = "YES" ]; then
       nm=0
   fi

   nfhrs=$(echo $IAUFHRS | sed 's/,/ /g')
   for FHR in $nfhrs; do
      echo "Regridding deterministic forecast for forecast hour $FHR"
      rm -f chgres_nc_gauss0$FHR.nml
      cat > chgres_nc_gauss0$FHR.nml << EOF
&chgres_setup
i_output=$LONB_ANAL
j_output=$LATB_ANAL
input_file="fcst.0$FHR"
output_file="fcst.ensres.0$FHR"
terrain_file="ref.06"
ref_file="ref.06"
${chgres_setup:-}
/
EOF
      if [ $USE_CFP = "YES" ]; then
        echo "$nm $APRUN_CHGRES $CHGRESNCEXEC chgres_nc_gauss0$FHR.nml" | tee -a $DATA/mp_chgres.sh
        if [ ${CFP_MP:-"NO"} = "YES" ]; then
          nm=$((nm+1))
        fi
      else
        export pgm=$CHGRESNCEXEC
        . prep_step
        $APRUN_CHGRES $CHGRESNCEXEC chgres_nc_gauss0$FHR.nml
        export err=$?; err_chk
      fi
   done

   if [ $USE_CFP = "YES" ]; then
      chmod 755 $DATA/mp_chgres.sh
      ncmd=$(cat $DATA/mp_chgres.sh | wc -l)
      if [ $ncmd -gt 0 ]; then
         ncmd_max=$((ncmd < max_tasks_per_node ? ncmd : max_tasks_per_node))
         APRUNCFP_CHGRES=$(eval echo $APRUNCFP)

         export pgm=$CHGRESNCEXEC
         . prep_step

         $APRUNCFP_CHGRES $DATA/mp_chgres.sh
         export err=$?; err_chk
      fi
   fi
fi

##############################################################
# calculate increment
if [[ $REGRID_ANALYSIS == "YES" ]]; then
  $NLN $ATMANLFRES06 siganl
  if [ $REPLAY_4DIAU = "YES" ]; then
     $NLN $ATMANLFRES03   siga03
     $NLN $ATMANLFRES09   siga09
  fi
else
  $NLN $ATMANLENS06 siganl
    if [ $REPLAY_4DIAU = "YES" ]; then
     $NLN $ATMANLENS03   siga03
     $NLN $ATMANLENS09   siga09
  fi
fi

if [[ $REGRID_FORECAST == "YES" ]]; then
  $NLN $ATMF06ENS sigf06
  if [ $REPLAY_4DIAU = "YES" ]; then
     $NLN $ATMF03ENS sigf03
     $NLN $ATMF09ENS sigf09
  fi
else
  $NLN $ATMF06 sigf06
  if [ $REPLAY_4DIAU = "YES" ]; then
     $NLN $ATMF03 sigf03
     $NLN $ATMF09 sigf09
  fi
fi

$NLN $ATMINC siginc.nc
if [ $REPLAY_4DIAU = "YES" ]; then
   $NLN $ATMI03   sigi03.nc
   $NLN $ATMI09   sigi09.nc
fi

$CALCINCPY
export err=$?; err_chk

################################################################################
# Postprocessing
cd ${pwd}

exit ${err}
