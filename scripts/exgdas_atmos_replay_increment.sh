#!/bin/ksh
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
#   Machine: WCOSS-Dell / Hera
#
################################################################################

#  Set environment.
export VERBOSE=${VERBOSE:-"YES"}
if [ $VERBOSE = "YES" ]; then
   echo $(date) EXECUTING $0 $* >&2
   set -x
fi

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
export CALCINCNCEXEC=${CALCINCNCEXEC:-$HOMEgfs/exec/calc_increment_ncio.x}
APRUNCFP=${APRUNCFP:-""}

# OPS flags
RUN=${RUN:-""}
SENDECF=${SENDECF:-"NO"}
SENDDBN=${SENDDBN:-"NO"}

# level info file (not need, ak, bk read from reference file)
SIGLEVEL=${SIGLEVEL:-${FIXgsm}/global_hyblev.l${LEVS}.txt}

# forecast analysis files
APREFIX=${APREFIX:-""}
ASUFFIX=${ASUFFIX:-$SUFFIX}
ATMF06=${ATMGES:-$COMIN_GES/${GPREFIX}atmf006${GSUFFIX}}
# external analysis
#ATMANL=${ATMANL:-${COMOUT}/${APREFIX}atmanl${ASUFFIX}}
ATMANL=${ATMANL:-${ROTDIR}/${ICDUMP}.${PDY}/$cyc/atmos/${ICDUMP}.t${cyc}z.atmanl${ASUFFIX}}
# chgres analysis
ATMANL_CHGRES=${ATMANL_CHGRES:-${COMOUT}/${APREFIX}atmanl_fcstres${ASUFFIX}}
# analysis increment
ATMINC=${ATMINC:-${COMOUT}/${APREFIX}atminc${ASUFFIX}}

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
res=$(echo $CASE |cut -c2-5)
resp=$((res+1))
npx=$resp
npy=$resp
npz=$LEVS

# spectral truncation and regular grid resolution based on FV3 resolution
JCAP_CASE=$((2*res-2))
LONB_CASE=$((4*res))
LATB_CASE=$((2*res))
LEVS_CASE=${LEVS:-91}

##############################################################
# Regrid external analysis  to forecast resolution
$NLN $ATMF06 fcst.06
$NLN $ATMANL anal
$NLN $ATMANL_CHGRES anal.fcstres

echo "Regridding analysis"
rm -f chgres_nc_gausanal.nml
cat > chgres_nc_gausanal.nml << EOF
&chgres_setup
i_output=$LONB_CASE
j_output=$LATB_CASE
input_file="anal"
output_file="anal.fcstres"
terrain_file="fcst.06"
ref_file="fcst.06"
/
EOF

export pgm=$CHGRESNCEXEC
. prep_step

$APRUN_CHGRES $CHGRESNCEXEC chgres_nc_gausanal.nml
export err=$?; err_chk

##############################################################
# calculate increment
export OMP_NUM_THREADS=$NTHREADS_CALCINC
if [ ${SUFFIX} = ".nc" ]; then
   CALCINCEXEC=$CALCINCNCEXEC
else
   CALCINCEXEC=$CALCINCNEMSEXEC
fi

$NLN $ATMINC atminc

export pgm=$CALCINCEXEC
. prep_step

$NCP $CALCINCEXEC $DATA

rm calc_increment.nml
cat > calc_increment.nml << EOF
&setup
  datapath = './'
  analysis_filename = 'anal.fcstres'
  firstguess_filename = 'fcst.06'
  increment_filename = 'atminc'
  debug = .false.
  imp_physics = $imp_physics
/
&zeroinc
  incvars_to_zero = $REPLAY_INCREMENTS_TO_ZERO
/
EOF
cat calc_increment.nml

$APRUN_CALCINC ${DATA}/$(basename $CALCINCEXEC)
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
