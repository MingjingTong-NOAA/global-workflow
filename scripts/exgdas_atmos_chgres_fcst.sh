#! /usr/bin/env bash
################################################################################
####  UNIX Script Documentation Block
#                      .                                             .
# Script name:         exgdas_atmos_chgres_fcst.sh
# Script description:  Runs chgres on full-resolution forecast for replay
#
# Author: Mingjing Tong      Org: NOAA/GFDL     Date: 2024-10-04
#
# Abstract: This script runs chgres on full-resolution forecast for later
#           use to compute analysis increment for replay mode
#
# $Id$
#
# Attributes:
#   Language: POSIX shell
#
################################################################################

source "$HOMEgfs/ush/preamble.sh"

#  Directories.
pwd=$(pwd)
export FIXgsm=${FIXgsm:-$HOMEgfs/fix/am}

# Base variables
CDATE=${CDATE:-"2001010100"}
CDUMP=${CDUMP:-"gdas"}
GDUMP=${GDUMP:-"gdas"}

# Derived base variables
GDATE=$($NDATE -$assim_freq $CDATE)
PDY=$(echo $CDATE | cut -c1-8)
cyc=$(echo $CDATE | cut -c9-10)
gPDY=$(echo $GDATE | cut -c1-8)
gcyc=$(echo $GDATE | cut -c9-10)

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
APRUNCFP=${APRUNCFP:-""}

# OPS flags
RUN=${RUN:-""}
SENDECF=${SENDECF:-"NO"}
SENDDBN=${SENDDBN:-"NO"}

# forecast files
APREFIX=${APREFIX:-""}
ASUFFIX=${ASUFFIX:-$SUFFIX}
# at full resolution
ATMF03=${ATMF03:-${ROTDIR}/${GDUMP}.${gPDY}/${gcyc}/atmos/${GPREFIX}atmf003${ASUFFIX}}
ATMF06=${ATMF06:-${ROTDIR}/${GDUMP}.${gPDY}/${gcyc}/atmos/${GPREFIX}atmf006${ASUFFIX}}
ATMF09=${ATMF09:-${ROTDIR}/${GDUMP}.${gPDY}/${gcyc}/atmos/${GPREFIX}atmf009${ASUFFIX}}
# at ensemble resolution
ATMF03ENS=${ATMF03ENS:-${ROTDIR}/${GDUMP}.${gPDY}/${gcyc}/atmos/${GPREFIX}atmf003.ensres${ASUFFIX}}
ATMF06ENS=${ATMF06ENS:-${ROTDIR}/${GDUMP}.${gPDY}/${gcyc}/atmos/${GPREFIX}atmf006.ensres${ASUFFIX}}
ATMF09ENS=${ATMF09ENS:-${ROTDIR}/${GDUMP}.${gPDY}/${gcyc}/atmos/${GPREFIX}atmf009.ensres${ASUFFIX}}
ATMANAL_ENSRES=${ATMANAL_ENSRES:-${ICSDIR}/${ICDUMP}.${PDY}/$cyc/atmos/${ICDUMP}.t${cyc}z.atmanl.ensres${ASUFFIX}}
ATMFCST_ENSRES=${ATMFCST_ENSRES:-${SHiELD_ref}/gdas.t00z.atmf006.nc}

# Set script / GSI control parameters
lrun_subdirs=${lrun_subdirs:-".true."}
USE_CFP=${USE_CFP:-"NO"}
CFP_MP=${CFP_MP:-"NO"}
nm=""
if [ $CFP_MP = "YES" ]; then
    nm=0
fi
if [ $DO_CHGRES_FCST != "YES" ]; then
   echo "DO_CHGRES_FCST != YES, this script will exit without regridding deterministic forecast"
   exit 0
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
LONB_ENKF=${LONB_ENKF:-$($NCLEN $ATMANAL_ENSRES grid_xt)} # get LONB_ENKF
LATB_ENKF=${LATB_ENKF:-$($NCLEN $ATMANAL_ENSRES grid_yt)} # get LATB_ENFK

##############################################################
# regrid forecasts to analysis resolution
if [ $DO_CHGRES_FCST == "YES" ]; then
   $NLN $ATMF06 fcst.06
   $NLN $ATMF06ENS fcst.ensres.06
   $NLN $ATMANAL_ENSRES atmens_anal
   $NLN $ATMFCST_ENSRES atmens_fcst
   if [ $replay_4DIAU = "YES" ]; then
      $NLN $ATMF03     fcst.03
      $NLN $ATMF03ENS  fcst.ensres.03
      $NLN $ATMF09     fcst.09
      $NLN $ATMF09ENS  fcst.ensres.09
   fi
   export OMP_NUM_THREADS=$NTHREADS_CHGRES

   if [ $USE_CFP = "YES" ]; then
      [[ -f $DATA/mp_chgres.sh ]] && rm $DATA/mp_chgres.sh
   fi

   nfhrs=$(echo $IAUFHRS_ENKF | sed 's/,/ /g')
   for FHR in $nfhrs; do
     echo "Regridding deterministic forecast for forecast hour $FHR"
     rm -f chgres_nc_gauss0$FHR.nml
cat > chgres_nc_gauss0$FHR.nml << EOF
&chgres_setup
i_output=$LONB_ENKF
j_output=$LATB_ENKF
input_file="fcst.0$FHR"
output_file="fcst.ensres.0$FHR"
terrain_file="atmens_fcst"
cld_amt=${cld_amt:-".false."}
ref_file="atmens_fcst"
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

else
   echo "DO_CHGRES_FCST != YES, doing nothing"
fi


################################################################################
# Postprocessing
cd $pwd
[[ $mkdata = "YES" ]] && rm -rf $DATA


exit $err
