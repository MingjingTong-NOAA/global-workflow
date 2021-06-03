#!/bin/ksh
################################################################################
####  UNIX Script Documentation Block
#                      .                                             .
# Script name:         exglobal_atmos_analysis.sh
# Script description:  Makes a global model upper air analysis with GSI
#
# Author: Rahul Mahajan      Org: NCEP/EMC     Date: 2017-03-02
#
# Abstract: This script makes a global model analysis using the GSI
#
# $Id$
#
# Attributes:
#   Language: POSIX shell
#   Machine: WCOSS-Cray / Theia
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
export NEMSIOGET=${NEMSIOGET:-${NWPROD}/exec/nemsio_get}
export NCLEN=${NCLEN:-$HOMEgfs/ush/getncdimlen}
export ERRSCRIPT=${ERRSCRIPT:-'eval [[ $err = 0 ]]'}
COMPRESS=${COMPRESS:-gzip}
UNCOMPRESS=${UNCOMPRESS:-gunzip}
APRUNCFP=${APRUNCFP:-""}
APRUN_GSI=${APRUN_GSI:-${APRUN:-""}}
NTHREADS_GSI=${NTHREADS_GSI:-${NTHREADS:-1}}

# Surface cycle related parameters
DOGCYCLE=${DOGCYCLE:-"NO"}
CYCLESH=${CYCLESH:-$HOMEgfs/ush/global_cycle.sh}
export CYCLEXEC=${CYCLEXEC:-$HOMEgfs/exec/global_cycle}
NTHREADS_CYCLE=${NTHREADS_CYCLE:-24}
APRUN_CYCLE=${APRUN_CYCLE:-${APRUN:-""}}
export SNOW_NUDGE_COEFF=${SNOW_NUDGE_COEFF:-'-2.'}
export CYCLVARS=${CYCLVARS:-""}
export FHOUR=${FHOUR:-0}
export DELTSFC=${DELTSFC:-6}
export FIXgsm=${FIXgsm:-$HOMEgfs/fix/fix_am}
export FIXfv3=${FIXfv3:-$HOMEgfs/fix/fix_fv3_gmted2010}

DOGAUSFCANL=${DOGAUSFCANL-"NO"}
GAUSFCANLSH=${GAUSFCANLSH:-$HOMEgfs/ush/gaussian_sfcanl.sh}
export GAUSFCANLEXE=${GAUSFCANLEXE:-$HOMEgfs/exec/gaussian_sfcanl.exe}
NTHREADS_GAUSFCANL=${NTHREADS_GAUSFCANL:-1}
APRUN_GAUSFCANL=${APRUN_GAUSFCANL:-${APRUN:-""}}

# FV3 specific info (required for global_cycle)
export CASE=${CASE:-"C384"}
ntiles=${ntiles:-6}

# IAU
DOIAU=${DOIAU:-"NO"}
export IAUFHRS=${IAUFHRS:-"6"}

# OPS flags
RUN=${RUN:-""}
SENDECF=${SENDECF:-"NO"}
SENDDBN=${SENDDBN:-"NO"}
RUN_GETGES=${RUN_GETGES:-"NO"}
GETGESSH=${GETGESSH:-"getges.sh"}
export gesenvir=${gesenvir:-$envir}

# Observations
OPREFIX=${OPREFIX:-""}
OSUFFIX=${OSUFFIX:-""}

##############################################################
# Update surface fields in the FV3 restart's using global_cycle

    mkdir -p $COMOUT/RESTART

    # Global cycle requires these files
    export FNTSFA=${FNTSFA:-$COMIN_OBS/${OPREFIX}rtgssthr.grb}
    export FNACNA=${FNACNA:-$COMIN_OBS/${OPREFIX}seaice.5min.blend.grb}
    export FNSNOA=${FNSNOA:-$COMIN_OBS/${OPREFIX}snogrb_t${JCAP_CASE}.${LONB_CASE}.${LATB_CASE}}
    [[ ! -f $FNSNOA ]] && export FNSNOA="$COMIN_OBS/${OPREFIX}snogrb_t1534.3072.1536"
    FNSNOG=${FNSNOG:-$COMIN_GES_OBS/${GPREFIX}snogrb_t${JCAP_CASE}.${LONB_CASE}.${LATB_CASE}}
    [[ ! -f $FNSNOG ]] && FNSNOG="$COMIN_GES_OBS/${GPREFIX}snogrb_t1534.3072.1536"

    # Set CYCLVARS by checking grib date of current snogrb vs that of prev cycle
    if [ $RUN_GETGES = "YES" ]; then
        snoprv=$($GETGESSH -q -t snogrb_$JCAP_CASE -e $gesenvir -n $GDUMP -v $GDATE)
    else
        snoprv=${snoprv:-$FNSNOG}
    fi

    if [ $($WGRIB -4yr $FNSNOA 2>/dev/null | grep -i snowc | awk -F: '{print $3}' | awk -F= '{print $2}') -le \
         $($WGRIB -4yr $snoprv 2>/dev/null | grep -i snowc | awk -F: '{print $3}' | awk -F= '{print $2}') ] ; then
        export FNSNOA=" "
        export CYCLVARS="FSNOL=99999.,FSNOS=99999.,"
    else
        export SNOW_NUDGE_COEFF=${SNOW_NUDGE_COEFF:-0.}
        export CYCLVARS="FSNOL=${SNOW_NUDGE_COEFF},$CYCLVARS"
    fi

    if [ $DONST = "YES" ]; then
        export NST_ANL=".true."
        export GSI_FILE=${GSI_FILE:-$COMOUT/${APREFIX}dtfanl.nc}
    else
        export NST_ANL=".false."
        export GSI_FILE="NULL"
    fi

    if [ $DOIAU = "YES" ]; then
        # update surface restarts at the beginning of the window, if IAU
        # For now assume/hold dtfanl.nc valid at beginning of window
        for n in $(seq 1 $ntiles); do
            $NLN $COMIN_GES/RESTART/$bPDY.${bcyc}0000.sfc_data.tile${n}.nc $DATA/fnbgsi.00$n
            $NLN $COMOUT/RESTART/$bPDY.${bcyc}0000.sfcanl_data.tile${n}.nc $DATA/fnbgso.00$n
            $NLN $FIXfv3/$CASE/${CASE}_grid.tile${n}.nc                    $DATA/fngrid.00$n
            $NLN $FIXfv3/$CASE/${CASE}_oro_data.tile${n}.nc                $DATA/fnorog.00$n
        done

        export APRUNCY=$APRUN_CYCLE
        export OMP_NUM_THREADS_CY=$NTHREADS_CYCLE
        export MAX_TASKS_CY=$ntiles

        $CYCLESH
        rc=$?
        export ERR=$rc
        export err=$ERR
        $ERRSCRIPT || exit 11
    fi
    # update surface restarts at middle of window
    for n in $(seq 1 $ntiles); do
        $NLN $COMIN_GES/RESTART/$PDY.${cyc}0000.sfc_data.tile${n}.nc $DATA/fnbgsi.00$n
        $NLN $COMOUT/RESTART/$PDY.${cyc}0000.sfcanl_data.tile${n}.nc $DATA/fnbgso.00$n
        $NLN $FIXfv3/$CASE/${CASE}_grid.tile${n}.nc                  $DATA/fngrid.00$n
        $NLN $FIXfv3/$CASE/${CASE}_oro_data.tile${n}.nc              $DATA/fnorog.00$n
    done

    export APRUNCY=$APRUN_CYCLE
    export OMP_NUM_THREADS_CY=$NTHREADS_CYCLE
    export MAX_TASKS_CY=$ntiles

    $CYCLESH
    rc=$?
    export ERR=$rc
    export err=$ERR
    $ERRSCRIPT || exit 11

################################################################################
set +x
if [ $VERBOSE = "YES" ]; then
   echo $(date) EXITING $0 with return code $err >&2
fi
exit $err

################################################################################
