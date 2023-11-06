#! /usr/bin/env bash

source "$HOMEgfs/ush/preamble.sh"

###############################################################
# Source FV3GFS workflow modules
. $HOMEgfs/ush/load_fv3gfs_modules.sh
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
# Loop over groups to Execute the JJOB
    
export job=ergpos
    
$HOMEgfs/jobs/JGDAS_ENREGRID_POST
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
# Exit out cleanly

exit 0
