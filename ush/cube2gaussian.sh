#!/bin/ksh

VERBOSE=${VERBOSE:-"NO"}
if [[ "$VERBOSE" = "YES" ]] ; then
   echo $(date) EXECUTING $0 $* >&2
   set -x
fi

export RHR=_RHR
export RDATE=_RDATE
export REND=_REND
export fhour=_fhour
cdate=_CDATE
export rmhydro=_rmhydro
export pseudo_ps=_pseudo_ps
export phy_data=_phy_data

GAUSSIANATMSSH=${GAUSSIANATMSSH:-$HOMEgfs/ush/gaussian_atmsfcst.sh}

$GAUSSIANATMSSH

GAUSSIANSFCSH=${GAUSSIANSFCSH:-$HOMEgfs/ush/gaussian_sfcfcst.sh}

$GAUSSIANSFCSH

COMOUT=${COMOUT:-"."}
$NLN $COMOUT/${APREFIX}logf$( printf "%03d" $RHR) $DATA/logf$( printf "%03d" $RHR)

if [[ $err == 0 ]]; then
  printf " completed fv3gfs fhour=%.*f %s" 3 $fhour $cdate > $DATA/logf$( printf "%03d" $RHR)
fi

set +x
if [[ "$VERBOSE" = "YES" ]]
then
   echo $(date) EXITING $0 with return code $err >&2
fi
exit $err

