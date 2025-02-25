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

REGRID_ANALYSIS="NO"
if [[ $LONB_FCST -ne $LONB_ANAL || $LATB_FCST -ne $LATB_ANAL || $LEVS_FCST -eq $LEVS_ANAL ]]; then
  REGRID_ANALYSIS="YES"
fi
##############################################################
# Regrid external analysis to forecast resolution
if [[ $REGRID_ANALYSIS == "YES" ]]; then
  $NLN $ATMF06 fcst.06
  if [ $replay_4DIAU = "YES" ]; then
    # use GFS analysis at ensemble forecast resolution
    $NLN $ATMANLENS03 anal.03
    $NLN $ATMANLENS06 anal.06
    $NLN $ATMANLENS09 anal.09
    $NLN $ATMANLFRES03 anal.fcstres.03
    $NLN $ATMANLFRES06 anal.fcstres.06
    $NLN $ATMANLFRES09 anal.fcstres.09
  else
    $NLN $ATMANLENS06 anal.06
    $NLN $ATMANLFRES06 anal.fcstres.06
    export IAUFHRS="6"
  fi
  export OMP_NUM_THREADS=$NTHREADS_CHGRES

   if [ $USE_CFP = "YES" ]; then
      [[ -f $DATA/mp_chgres.sh ]] && rm $DATA/mp_chgres.sh
   fi

   nfhrs=$(echo $IAUFHRS | sed 's/,/ /g')
   for FHR in $nfhrs; do
     echo "Regridding deterministic forecast for forecast hour $FHR"
     rm -f chgres_nc_gauss0$FHR.nml
cat > chgres_nc_gauss0$FHR.nml << EOF
&chgres_setup
i_output=$LONB_FCST
j_output=$LATB_FCST
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

else
   echo "REGRID_ANALYSIS != YES, doing nothing"
fi

##############################################################
# calculate increment
$NLN $ATMF06 sigf06
$NLN $ATMANLFRES06 siganl
$NLN $ATMINC siginc.nc
if [ $replay_4DIAU = "YES" ]; then
   $NLN $ATMF03 sigf03
   $NLN $ATMANLFRES03   siga03
   $NLN $ATMI03   sigi03.nc
   $NLN $ATMF09 sigf09
   $NLN $ATMANLFRES09   siga09
   $NLN $ATMI09   sigi09.nc
fi

$CALCINCPY
export err=$?; err_chk

################################################################################
# Postprocessing
cd ${pwd}

exit ${err}
