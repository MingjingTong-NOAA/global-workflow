#!/bin/ksh
################################################################################
####  UNIX Script Documentation Block
#                      .                                             .
# Script name:         exgdas_enkf_ecen_fcst.sh
# Script description:  recenter ensemble around hi-res deterministic forecast
#
# Author:       Mingjing Tong      Org: NOAA/GFDL     Date: 2022-06-30
#
# Abstract: This script recenters ensemble around hi-res deterministic forecast
#
# $Id$
#
# Attributes:
#   Language: POSIX shell
#   Machine: WCOSS-Cray/Hera
#
################################################################################

# Set environment.
VERBOSE=${VERBOSE:-"YES"}
if [ $VERBOSE = "YES" ]; then
   echo $(date) EXECUTING $0 $* >&2
   set -x
fi

# Directories.
pwd=$(pwd)

# Base variables
CDATE=${CDATE:-"2010010100"}
DONST=${DONST:-"NO"}
export CASE=${CASE:-384}
ntiles=${ntiles:-6}

# Utilities
NCP=${NCP:-"/bin/cp -p"}
NLN=${NLN:-"/bin/ln -sf"}

# Scripts

# Executables.
RECENATMEXEC=${RECENATMEXEC:-$HOMEgfs/exec/recentersigp.x}

# Files.
APREFIX=${APREFIX:-""}
APREFIX_ENKF=${APREFIX_ENKF:-$APREFIX}
ASUFFIX=${ASUFFIX:-$SUFFIX}
GPREFIX=${GPREFIX:-""}
GSUFFIX=${GSUFFIX:-$SUFFIX}

# Variables
NMEM_ENKF=${NMEM_ENKF:-80}
FHMIN=${FHMIN_ECEN:-3}
FHMAX=${FHMAX_ECEN:-9}
FHOUT=${FHOUT_ECEN:-3}
FHSFC=${FHSFC_ECEN:-$FHMIN}

RECENTER_ENKF=${RECENTER_ENKF:-"YES"}
SMOOTH_ENKF=${SMOOTH_ENKF:-"YES"}

APRUN_ECEN=${APRUN_ECEN:-${APRUN:-""}}
NTHREADS_ECEN=${NTHREADS_ECEN:-${NTHREADS:-1}}

################################################################################
# Preprocessing
mkdata=NO
if [ ! -d $DATA ]; then
   mkdata=YES
   mkdir -p $DATA
fi
cd $DATA || exit 99

ENKF_SUFFIX="s"
[[ $SMOOTH_ENKF = "NO" ]] && ENKF_SUFFIX=""

################################################################################
# Link ensemble member forecast and mean files
for FHR in $(seq $FHMIN $FHOUT $FHMAX); do

for imem in $(seq 1 $NMEM_ENKF); do
   memchar="mem"$(printf %03i $imem)
   $NLN $COMIN_GES_ENS/$memchar/${APREFIX}atmf00${FHR}${ENKF_SUFFIX}$GSUFFIX ./atmfcst_$memchar
   mkdir -p $COMOUT_ENS/$memchar
   if [[ $RECENTER_ENKF = "YES" ]]; then
      $NLN $COMOUT_ENS/$memchar/${APREFIX}ratmf00${FHR}$ASUFFIX ./ratmfcst_$memchar
   fi
done

# Link ensemble mean forecast
$NLN $COMIN_ENS/${APREFIX_ENKF}atmf00${FHR}.ensmean$ASUFFIX ./atmfcst_ensmean

# Link GSI forecast at ensemble resolution
$NLN $COMIN/${APREFIX}atmf00${FHR}.ensres$ASUFFIX atmfcst_gsi_ensres

################################################################################
# This is to give the user the option to recenter, default is YES
if [ $RECENTER_ENKF = "YES" ]; then

   # Recenter ensemble member atmospheric forecast about hires analysis

   FILENAMEIN="atmfcst"
   FILENAME_MEANIN="atmfcst_ensmean"     # EnKF ensemble mean forecast
   FILENAME_MEANOUT="atmfcst_gsi_ensres" # recenter around GSI analysis at ensemble resolution
   FILENAMEOUT="ratmfcst"

   [[ -f recenter.nml ]] && rm recenter.nml
   cat > recenter.nml << EOF
&recenter
  clip_tracers = $CLIP_TRACERS
/
EOF
cat recenter.nml

   export OMP_NUM_THREADS=$NTHREADS_ECEN
   export pgm=$RECENATMEXEC
   . prep_step

   $NCP $RECENATMEXEC $DATA
   $APRUN_ECEN ${DATA}/$(basename $RECENATMEXEC) $FILENAMEIN $FILENAME_MEANIN $FILENAME_MEANOUT $FILENAMEOUT $NMEM_ENKF
   export err=$?; err_chk
fi

done # loop over analysis times in window

################################################################################

################################################################################
# Postprocessing
cd $pwd
[[ $mkdata = "YES" ]] && rm -rf $DATA
set +x
if [ $VERBOSE = "YES" ]; then
   echo $(date) EXITING $0 with return code $err >&2
fi
exit $err
