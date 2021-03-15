#!/bin/ksh

VERBOSE=${VERBOSE:-"NO"}
if [[ "$VERBOSE" = "YES" ]] ; then
   echo $(date) EXECUTING $0 $* >&2
   set -x
fi

export RHR=_RHR
export REND=$FHMAX
export rmhydro=${rmhydro:-".true."}
export pseudo_ps=${pseudo_ps:-".true."}
export phy_data=${phy_data=:-""}

if [[ $RHR == 0 ]]; then
  export fhour=$((DELTIM/3600.))
else
  export fhour=$((1.0*(RHR-iau_halfdelthrs)))
fi

export diag_fhr=$((fhour+2*iau_halfdelthrs))
export RDATE=$($NDATE +$RHR $sCDATE)

COMOUT=${COMOUTatmos:-"."}
$NLN $COMOUT/${APREFIX}logf$( printf "%03d" $RHR) $DATA/logf$( printf "%03d" $RHR)

GAUSSIANATMSSH=${GAUSSIANATMSSH:-$HOMEgfs/ush/gaussian_atmsfcst.sh}

$GAUSSIANATMSSH

GAUSSIANSFCSH=${GAUSSIANSFCSH:-$HOMEgfs/ush/gaussian_sfcfcst.sh}

$GAUSSIANSFCSH

if [[ $err == 0 ]]; then
   printf " completed fv3gfs fhour=%.*f %s" 3 $fhour $CDATE >> $DATA/logf$( printf "%03d" $RHR)
fi

set +x
if [[ "$VERBOSE" = "YES" ]]
then
   echo $(date) EXITING $0 with return code $err >&2
fi
exit $err

