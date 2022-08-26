#!/bin/bash

VERBOSE=${VERBOSE:-"NO"}
if [[ "$VERBOSE" = "YES" ]] ; then
   echo $(date) EXECUTING $0 $* >&2
   set -x
   exec >> $DATA/log_c2g_RHR 2>&1
fi

export DONST=${DONST:-"NO"}

export RHR=_RHR
export REND=$FHMAX
export rmhydro=${rmhydro:-".true."}
export pseudo_ps=${pseudo_ps:-".true."}
export phy_data=${phy_data:-""}
export atminc="_atminc"

if [[ $atminc = ".true." ]]; then
  export rmhydro=".false."
  export pseudo_ps=".false."
  export phy_data=""
fi

if [[ $RHR == 0 ]]; then
  #export fhour=$(( $DELTIM/3600. ))
  export fhour=$( echo "$DELTIM / 3600" | bc)
else
  export fhour=$(( $RHR-$iau_halfdelthrs ))
fi

#export diag_fhr=$(( $fhour+2*$iau_halfdelthrs ))
export diag_fhr=$( echo "2*$iau_halfdelthrs+$fhour" | bc)
export RDATE=$($NDATE +$RHR $sCDATE)

COMOUT=${COMOUTatmos:-"."}
if [[ $atminc = ".true." ]]; then
  AFHR=inc
else
  AFHR=f$( printf "%03d" $fhour)
fi

$NLN $memdir/${APREFIX}log${AFHR}_c2g $DATA/log${AFHR}

GAUSSIANATMSSH=${GAUSSIANATMSSH:-$HOMEgfs/ush/gaussian_c2g_atms.sh}

$GAUSSIANATMSSH

ls $memdir/${APREFIX}atm${AFHR}${ASUFFIX} > /dev/null 2>&1
export err=$?
$ERRSCRIPT||exit 2

auxfhr=_auxfhr

if [[ $atminc = ".false." ]]; then
  if [[ $auxfhr = "YES" ]]; then
     GAUSSIANSFCSH=$HOMEgfs/ush/gaussian_sfcfcst_nodiagvar.sh
  else 
     GAUSSIANSFCSH=$HOMEgfs/ush/gaussian_sfcfcst.sh
  fi
     
  $GAUSSIANSFCSH
  
  ls $memdir/${APREFIX}sfcf$( printf "%03d" $fhour)${ASUFFIX} > /dev/null 2>&1
  export err=$?
  $ERRSCRIPT||exit 2
fi

if [[ $err == 0 && -s $memdir/ && $atminc = ".false." ]]; then
   printf " completed fv3gfs fhour=%.*f %s" 3 $fhour $CDATE > $memdir/${APREFIX}logf$( printf "%03d" $fhour).txt
fi

set +x
if [[ "$VERBOSE" = "YES" ]]
then
   echo $(date) EXITING $0 with return code $err >&2
fi
exit $err

