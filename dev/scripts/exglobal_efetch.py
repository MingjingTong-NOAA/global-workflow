#!/usr/bin/env python3

import os

from pygfs.task.fetch import Fetch
from wxflow import AttrDict, Logger, cast_strdict_as_dtypedict, chdir, logit

# initialize root logger
logger = Logger(level=os.environ.get("LOGGING_LEVEL", "DEBUG"), colored_log=True)


@logit(logger)
def main():

    config = cast_strdict_as_dtypedict(os.environ)

    # Instantiate the Fetch object
    fetch = Fetch(config)

    # Pull out all the configuration keys needed to run the rest of archive steps
    keys = ['FETCHDIR', 'current_cycle', 'previous_cycle', 'RUN', 'PDY', 'gPDY',
            'PSLOT', 'ROTDIR', 'SAVEDIR', 'PARMglobal', 'MODE',
            'ENSGRP', 'NMEM_EARCGRP', 'NMEM_ENS', 'DO_JEDIATMENS',
            'DO_CALC_INCREMENT', 'DOIAU_ENKF', 'DOENKFONLY_ATM', 'IAUFHRS',
            'lobsdiag_forenkf', 'assim_freq',
            'ENSREPLAY', 'EXP_WARM_START', 'ANAL_START', 'ANAL_ONLY',
            'FHMIN_ENKF', 'FHMAX_ENKF', 'FHOUT_ENKF',
            'EFHMIN', 'EFHMAX']

    fetch_dict = AttrDict()
    for key in keys:
        fetch_dict[key] = fetch.task_config.get(key)
        if fetch_dict[key] is None:
            print(f"Warning: key ({key}) not found in task_config!")

    if 'IAUFHRS' in fetch_dict:
        fetch_dict['iaufhrs_str'] = [f"{h:03d}" for h in fetch_dict['IAUFHRS']]

    # Also import all COMIN* directory and template variables
    for key in fetch.task_config.keys():
        if key.startswith(("COM_", "COMIN_")):
            fetch_dict[key] = fetch.task_config.get(key)

    with chdir(config.SAVEDIR):

        # Determine which fetchs to create
        fetchdir_sets = fetch.configure_fetch(fetch_dict)

        # Create the backup tarballs and store in ATARDIR
        for fetchdir_set in fetchdir_sets:
            fetch.execute_pull_data(fetchdir_set)


if __name__ == '__main__':
    main()
