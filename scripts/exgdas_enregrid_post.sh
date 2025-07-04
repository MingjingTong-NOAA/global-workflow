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

# Directories.
pwd=$(pwd)

APRUN_EPOS=${APRUN_EPOS:-${APRUN:-""}}
NTHREADS_EPOS=${NTHREADS_EPOS:-1}

# Ops stuff
SENDDBN=${SENDDBN:-"NO"}

# Executables.
GETENSMEANEXEC=${GETENSMEANEXEC:-$HOMEgfs/exec/getgribncensmeanp.x}

# Other variables.
PREFIX=${PREFIX:-""}
FHMIN=${FHMIN:-6}
FHMAX=${FHMAX:-6}
FHOUT=${FHOUT:-1}
NMEM_ENS=${NMEM_ENS:-80}

################################################################################
#  Preprocessing
SUFFIX=${SUFFIX:-".grib2.nc"}

################################################################################
# Copy executables to working directory
$NCP $GETENSMEANEXEC $DATA

export OMP_NUM_THREADS=$NTHREADS_EPOS

################################################################################
for grid in ${grids}; do
# Forecast ensemble member files
for imem in $(seq 1 $NMEM_ENS); do
   memchar="mem"$(printf %03i "${imem}")
   GRID="${grid}_nc" MEMDIR=${memchar} YMD=${PDY} HH=${cyc} declare_from_tmpl -x \
        COMIN_ATMOS_GRIB_nc:COM_ATMOS_GRIB_GRID_TMPL

   for fhr in $(seq $FHMIN $FHOUT $FHMAX); do
      fhrchar=$(printf %03i $fhr)
      ${NLN} "${COMIN_ATMOS_GRIB_nc}/${PREFIX}sfcf${fhrchar}${SUFFIX}" "sfcf${fhrchar}_${memchar}"
      ${NLN} "${COMIN_ATMOS_GRIB_nc}/${PREFIX}atmf${fhrchar}${SUFFIX}" "atmf${fhrchar}_${memchar}"
   done
done

# Forecast ensemble mean and smoothed files
MEMDIR="ensstat" YMD=${PDY} HH=${cyc} GRID=${grid} declare_from_tmpl -x \
       COMOUT_ATMOS_GRIB_STAT:COM_ATMOS_GRIB_GRID_TMPL
if [[ ! -d "${COMOUT_ATMOS_GRIB_STAT}" ]]; then mkdir -p "${COMOUT_ATMOS_GRIB_STAT}"; fi

for fhr in $(seq $FHMIN $FHOUT $FHMAX); do
   fhrchar=$(printf %03i $fhr)
   ${NLN} "${COMOUT_ATMOS_GRIB_STAT}/${PREFIX}atmf${fhrchar}.ensmean${SUFFIX}" "atmf${fhrchar}.ensmean"
   ${NLN} "${COMOUT_ATMOS_GRIB_STAT}/${PREFIX}atmf${fhrchar}.ensspread${SUFFIX}" "atmf${fhrchar}.ensspread"
   ${NLN} "${COMOUT_ATMOS_GRIB_STAT}/${PREFIX}sfcf${fhrchar}.ensmean${SUFFIX}" "sfcf${fhrchar}.ensmean"
   ${NLN} "${COMOUT_ATMOS_GRIB_STAT}/${PREFIX}sfcf${fhrchar}.ensspread${SUFFIX}" "sfcf${fhrchar}.ensspread"
done

################################################################################
# Generate ensemble mean and spread atmospheric files

rc=0
for fhr in $(seq $FHMIN $FHOUT $FHMAX); do
   fhrchar=$(printf %03i $fhr)

   export pgm=${GETENSMEANEXEC}
   . prep_step

   ${APRUN_EPOS} "${DATA}/$(basename ${GETENSMEANEXEC})" ./ "atmf${fhrchar}.ensmean" "atmf${fhrchar}" "${NMEM_ENS}" "atmf${fhrchar}.ensspread" && true
   ra=$?
   rc=$((rc+ra))
done
export err=$rc; err_chk

# Generate ensemble mean and spread surface files

rc=0
for fhr in $(seq $FHMIN $FHOUT $FHMAX); do
   fhrchar=$(printf %03i $fhr)

   export pgm=${GETENSMEANEXEC}
   . prep_step

   ${APRUN_EPOS} "${DATA}/$(basename ${GETENSMEANEXEC})" ./ "sfcf${fhrchar}.ensmean" "sfcf${fhrchar}" "${NMEM_ENS}" "sfcf${fhrchar}.ensspread" && true
   ra=$?
   rc=$((rc+ra))
done
export err=$rc; err_chk
done

################################################################################
#  Postprocessing
cd $pwd

exit "${err}"
