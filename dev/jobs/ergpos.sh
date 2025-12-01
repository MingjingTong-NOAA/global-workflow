#! /usr/bin/env bash

set -x

source "${HOMEgfs}/dev/ush/load_modules.sh" run
status=$?
if [[ "${status}" -ne 0 ]]; then
    exit "${status}"
fi

export job="ergpos"
export jobid="${job}.$$"

# Execute the JJOB
"${HOMEgfs}/jobs/JGDAS_ENREGRID_POST"
status=$?

exit "${status}"
