#! /usr/bin/env bash

################################################################################
####  UNIX Script Documentation Block
#                      .                                             .
# Script name:         exgdas_atmos_replay_increment.sh
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
################################################################################

#  Set environment.

source "$HOMEgfs/ush/preamble.sh"

#  Directories.
pwd=$(pwd)
export FIXgsm=${FIXgsm:-$HOMEgfs/fix/fix_am}

# Base variables
CDATE=${CDATE:-"2001010100"}
CDUMP=${CDUMP:-"gdas"}
GDUMP=${GDUMP:-"gdas"}

# Derived base variables
GDATE=$($NDATE -$assim_freq $CDATE)
BDATE=$($NDATE -3 $CDATE)
PDY=$(echo $CDATE | cut -c1-8)
cyc=$(echo $CDATE | cut -c9-10)
bPDY=$(echo $BDATE | cut -c1-8)
bcyc=$(echo $BDATE | cut -c9-10)

# Utilities
export NCP=${NCP:-"/bin/cp"}
export NMV=${NMV:-"/bin/mv"}
export NLN=${NLN:-"/bin/ln -sf"}
export CHGRP_CMD=${CHGRP_CMD:-"chgrp ${group_name:-rstprod}"}
export NCLEN=${NCLEN:-$HOMEgfs/ush/getncdimlen}

# IAU
DOIAU=${DOIAU:-"NO"}
export IAUFHRS=${IAUFHRS:-"6"}

# Dependent Scripts and Executables
export APRUN_CHGRES=${APRUN_CHGRES:-${APRUN:-""}}
export CHGRESNCEXEC=${CHGRESNCEXEC:-$HOMEgfs/exec/enkf_chgres_recenter_nc.x}
export NTHREADS_CHGRES=${NTHREADS_CHGRES:-1}
export APRUN_CALCINC=${APRUN_CALCINC:-${APRUN:-""}}
export CALCINCEXEC=${CALCINCEXEC:-$HOMEgfs/exec/calc_increment_ens.x}
export CALCINCNCEXEC=${CALCINCNCEXEC:-$HOMEgfs/exec/calc_increment_ens_ncio.x}
CALCINCPY=${CALCINCPY:-$HOMEgfs/ush/calcinc_gfs.py}
APRUNCFP=${APRUNCFP:-""}

# OPS flags
RUN=${RUN:-""}
SENDECF=${SENDECF:-"NO"}
SENDDBN=${SENDDBN:-"NO"}

# level info file (not need, ak, bk read from reference file)
SIGLEVEL=${SIGLEVEL:-${FIXshield}/global_hyblev.l${LEVS}.txt}

# forecast files
APREFIX=${APREFIX:-""}
ASUFFIX=${ASUFFIX:-$SUFFIX}
ATMF03=${ATMF03:-$COMIN_GES/${GPREFIX}atmf003${GSUFFIX}}
ATMF06=${ATMGES:-$COMIN_GES/${GPREFIX}atmf006${GSUFFIX}}
ATMF09=${ATMF09:-$COMIN_GES/${GPREFIX}atmf009${GSUFFIX}}
ATMFCST_RES=${ATMFCST_RES:-$COMIN_GES/${GPREFIX}atmf006${GSUFFIX}}

# external analysis
ATMA03=${ATMA03:-${COMOUT}/${ICDUMP}.t${cyc}z.atma003${ASUFFIX}}
ATMANL=${ATMANL:-${COMOUT}/${ICDUMP}.t${cyc}z.atmanl${ASUFFIX}}
ATMA09=${ATMA09:-${COMOUT}/${ICDUMP}.t${cyc}z.atma009${ASUFFIX}}
ATMANLENS03=${ATMANLENS03:-${ICSDIR}/${ICDUMP}.${PDY}/$cyc/atmos/${ICDUMP}.t${cyc}z.atma003.ensres${ASUFFIX}}
ATMANLENS06=${ATMANLENS06:-${ICSDIR}/${ICDUMP}.${PDY}/$cyc/atmos/${ICDUMP}.t${cyc}z.atmanl.ensres${ASUFFIX}}
ATMANLENS09=${ATMANLENS09:-${ICSDIR}/${ICDUMP}.${PDY}/$cyc/atmos/${ICDUMP}.t${cyc}z.atma009.ensres${ASUFFIX}}

# chgres analysis
ATMANLFRES03=${ATMANL03_CHGRES:-${COMOUT}/${APREFIX}atma03_fcstres${ASUFFIX}}
ATMANLFRES06=${ATMANL06_CHGRES:-${COMOUT}/${APREFIX}atma06_fcstres${ASUFFIX}}
ATMANLFRES09=${ATMANL09_CHGRES:-${COMOUT}/${APREFIX}atma09_fcstres${ASUFFIX}}

# analysis increment
ATMINC=${ATMINC:-${COMOUT}/${APREFIX}atminc.nc}
ATMI03=${ATMI03:-${COMOUT}/${APREFIX}atmi003.nc}
ATMI09=${ATMI09:-${COMOUT}/${APREFIX}atmi009.nc}

# Set script / GSI control parameters
USE_CFP=${USE_CFP:-"NO"}
CFP_MP=${CFP_MP:-"NO"}
nm=""
if [ $CFP_MP = "YES" ]; then
    nm=0
fi

################################################################################
################################################################################
#  Preprocessing
mkdata=NO
if [ ! -d $DATA ]; then
   mkdata=YES
   mkdir -p $DATA
fi

cd $DATA || exit 99

##############################################################
# get resolution information
LONB_CASE=${LONB_CASE:-$($NCLEN $ATMFCST_RES grid_xt)} # get LONB_ENKF
LATB_CASE=${LATB_CASE:-$($NCLEN $ATMFCST_RES grid_yt)} # get LATB_ENFK
LEVS_CASE=${LEVS_CASE:-$($NCLEN $ATMFCST_RES pfull)} # get LATB_ENFK

##############################################################
# Regrid external analysis  to forecast resolution
$NLN $ATMF06 fcst.06
if [ $replay_4DIAU = "YES" ]; then
  if [ $fullresanl = "YES" ]; then
    $NLN $ATMA03 anal.03
    $NLN $ATMANL anal.06
    $NLN $ATMA09 anal.09
  else
    $NLN $ATMANLENS03 anal.03
    $NLN $ATMANLENS06 anal.06
    $NLN $ATMANLENS09 anal.09
  fi
  $NLN $ATMANLFRES03 anal.fcstres.03
  $NLN $ATMANLFRES06 anal.fcstres.06
  $NLN $ATMANLFRES09 anal.fcstres.09
else
  $NLN $ATMANL anal.06
  $NLN $ATMANLFRES06 anal.fcstres.06
  export IAUFHRS="6"
fi

nfhrs=$(echo $IAUFHRS | sed 's/,/ /g')
for FHR in $nfhrs; do
    echo "Regridding deterministic forecast for forecast hour $FHR"
    rm -f chgres_nc_gauss0$FHR.nml
cat > chgres_nc_gauss0$FHR.nml << EOF
&chgres_setup
i_output=$LONB_CASE
j_output=$LATB_CASE
input_file="anal.0$FHR"
output_file="anal.fcstres.0$FHR"
terrain_file="fcst.06"
ref_file="fcst.06"
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
      ncmd_max=$((ncmd < npe_node_max ? ncmd : npe_node_max))
      APRUNCFP_CHGRES=$(eval echo $APRUNCFP)

      export pgm=$CHGRESNCEXEC
      . prep_step

      $APRUNCFP_CHGRES $DATA/mp_chgres.sh
      export err=$?; err_chk
   fi
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
cd $pwd
[[ $mkdata = "YES" ]] && rm -rf $DATA

set +x
if [ $VERBOSE = "YES" ]; then
   echo $(date) EXITING $0 with return code $err >&2
fi
exit $err
