#! /usr/bin/env bash

################################################################################
####  UNIX Script Documentation Block
#                      .                                             .
# Script name:         exgdas_enregrid_post.sh
# Script description:  Global ensemble forecast post processing
#
# Author:        Rahul Mahajan      Org: NCEP/EMC     Date: 2017-03-02
#
# Abstract: This script post-processes global ensemble forecast output
#
# $Id$
#
# Attributes:
#   Language: POSIX shell
#
################################################################################

source "$HOMEgfs/ush/preamble.sh"

# Directories.
pwd=$(pwd)

# Utilities
NCP=${NCP:-"/bin/cp"}
NLN=${NLN:-"/bin/ln -sf"}

APRUN_EPOS=${APRUN_EPOS:-${APRUN:-""}}
NTHREADS_EPOS=${NTHREADS_EPOS:-1}

# Ops stuff
SENDDBN=${SENDDBN:-"NO"}

# Executables.
GETATMENSMEANEXEC=${GETATMENSMEANEXEC:-$HOMEgfs/exec/getgribncensmeanp.x}

# Other variables.
PREFIX=${PREFIX:-""}
SUFFIX=${SUFFIX:-".grib.nc"}
FHMIN=${FHMIN:-6}
FHMAX=${FHMAX:-6}
FHOUT=${FHOUT:-1}
NMEM_ENKF=${NMEM_ENKF:-80}

################################################################################
#  Preprocessing
mkdata=NO
if [ ! -d $DATA ]; then
   mkdata=YES
   mkdir -p $DATA
fi
cd $DATA || exit 99

################################################################################
# Copy executables to working directory
$NCP $GETATMENSMEANEXEC $DATA

export OMP_NUM_THREADS=$NTHREADS_EPOS

################################################################################
# Forecast ensemble member files
for imem in $(seq 1 $NMEM_ENKF); do
   memchar="mem"$(printf %03i $imem)
   for fhr in $(seq $FHMIN $FHOUT $FHMAX); do
      fhrchar=$(printf %03i $fhr)
      $NLN $COMIN/$memchar/${PREFIX}atmf$fhrchar${SUFFIX} atmf${fhrchar}_$memchar
      $NLN $COMIN/$memchar/${PREFIX}sfcf$fhrchar${SUFFIX} sfcf${fhrchar}_$memchar
   done
done

# Forecast ensemble mean and spread files
for fhr in $(seq $FHMIN $FHOUT $FHMAX); do
   fhrchar=$(printf %03i $fhr)
   $NLN $COMOUT/${PREFIX}atmf${fhrchar}.ensmean${SUFFIX} atmf${fhrchar}.ensmean
   $NLN $COMOUT/${PREFIX}atmf${fhrchar}.ensspread${SUFFIX} atmf${fhrchar}.ensspread
   $NLN $COMOUT/${PREFIX}sfcf${fhrchar}.ensmean${SUFFIX} sfcf${fhrchar}.ensmean
   $NLN $COMOUT/${PREFIX}sfcf${fhrchar}.ensspread${SUFFIX} sfcf${fhrchar}.ensspread
done

################################################################################
# Generate ensemble mean and spread atmospheric files

rc=0
for fhr in $(seq $FHMIN $FHOUT $FHMAX); do
   fhrchar=$(printf %03i $fhr)

   export pgm=$GETATMENSMEANEXEC
   . prep_step

   $APRUN_EPOS ${DATA}/$(basename $GETATMENSMEANEXEC) ./ atmf${fhrchar}.ensmean atmf${fhrchar} $NMEM_ENKF atmf${fhrchar}.ensspread
   ra=$?
   rc=$((rc+ra))
done
export err=$rc; err_chk

# Generate ensemble mean and spread surface files

rc=0
for fhr in $(seq $FHMIN $FHOUT $FHMAX); do
   fhrchar=$(printf %03i $fhr)

   export pgm=$GETATMENSMEANEXEC
   . prep_step

   $APRUN_EPOS ${DATA}/$(basename $GETATMENSMEANEXEC) ./ sfcf${fhrchar}.ensmean sfcf${fhrchar} $NMEM_ENKF sfcf${fhrchar}.ensspread
   ra=$?
   rc=$((rc+ra))
done
export err=$rc; err_chk

################################################################################
#  Postprocessing
cd $pwd
[[ $mkdata = "YES" ]] && rm -rf $DATA

exit $err
