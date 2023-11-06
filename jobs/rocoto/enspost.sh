#! /usr/bin/env bash

source "$HOMEgfs/ush/preamble.sh"

###############################################################
## ensemble post driver script
## ENSGRP : ensemble sub-group to archive (0, 1, 2, ...)
###############################################################

# Source FV3GFS workflow modules
. $HOMEgfs/ush/load_fv3gfs_modules.sh
status=$?
[[ $status -ne 0 ]] && exit $status

export COMPONENT=${COMPONENT:-atmos}

###############################################################
# Source relevant configs
configs="base enspost"
export EXPDIR=${EXPDIR:-$HOMEgfs/parm/config}
for config in $configs; do
    . $EXPDIR/config.${config}
    status=$?
    [[ $status -ne 0 ]] && exit $status
done

#---------------------------------------------------------------
export n=$((10#${ENSGRP}))

m=1
while [ $m -le $NMEM_EARCGRP ]; do
  nm=$(((n-1)*NMEM_EARCGRP+m))
  export memid=$(printf %03i $nm)
  export post_times=$(printf %03i $post_fhr)
  export COMIN=$ROTDIR/enkf${CDUMP}.${PDY}/${cyc}/atmos/mem${memid}
  export COMOUT=$COMIN
  export restart_file=$COMIN/${CDUMP}.t${cyc}z.atmf
  $HOMEgfs/jobs/JGLOBAL_ATMOS_ENSPOST
  status=$?
  [[ $status -ne 0 ]] && exit $status
  m=$((m+1))
done

exit 0
