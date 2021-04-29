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
export phy_data=${phy_data:-""}

if [[ $RHR == 0 ]]; then
  export fhour=$((DELTIM/3600.))
else
  export fhour=$((1.0*(RHR-iau_halfdelthrs)))
fi

export diag_fhr=$((fhour+2*iau_halfdelthrs))
export RDATE=$($NDATE +$RHR $sCDATE)

COMOUT=${COMOUTatmos:-"."}
$NLN $memdir/${APREFIX}logf$( printf "%03d" $fhour)_c2g $DATA/logf$( printf "%03d" $fhour)

GAUSSIANATMSSH=${GAUSSIANATMSSH:-$HOMEgfs/ush/gaussian_c2g_atms.sh}

$GAUSSIANATMSSH

ls $memdir/${APREFIX}atmf$( printf "%03d" $fhour)${ASUFFIX} > /dev/null 2>&1
export err=$?
$ERRSCRIPT||exit 2

auxfhr=_auxfhr
if [[ $auxfhr = "YES" ]]; then
   GAUSSIANSFCSH=$HOMEgfs/ush/gaussian_sfcfcst_nodiagvar.sh
else 
   GAUSSIANSFCSH=$HOMEgfs/ush/gaussian_sfcfcst.sh
fi
   
$GAUSSIANSFCSH

ls $memdir/${APREFIX}sfcf$( printf "%03d" $fhour)${ASUFFIX} > /dev/null 2>&1
export err=$?
$ERRSCRIPT||exit 2

if [[ $err == 0 && -s $memdir/ ]]; then
   printf " completed fv3gfs fhour=%.*f %s" 3 $fhour $CDATE > $memdir/${APREFIX}logf$( printf "%03d" $fhour).txt
fi

set +x
if [[ "$VERBOSE" = "YES" ]]
then
   echo $(date) EXITING $0 with return code $err >&2
fi
exit $err

