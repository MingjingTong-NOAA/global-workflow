#! /usr/bin/env bash

source "${HOMEgfs}/ush/preamble.sh"

###############################################################
# Source FV3GFS workflow modules
. ${HOMEgfs}/ush/load_fv3gfs_modules.sh
status=$?
[[ ${status} -ne 0 ]] && exit ${status}

export job="ergpos"
export jobid="${job}.$$"
    
###############################################################
    
${HOMEgfs}/jobs/JGDAS_ENREGRID_POST
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
# Exit out cleanly

exit 0
