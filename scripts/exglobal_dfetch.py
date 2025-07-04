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
            'PSLOT', 'ROTDIR', 'SAVEDIR', 'ICSROOT', 'PARMgfs', 'FCSTMODE',
            'assim_freq', 'FHMIN', 'FHMAX', 'FHOUT', 'EXPABIAS', 'GFSFETCHDIR',
            'gfssubver'] 

    fetch_dict = AttrDict()
    for key in keys:
        fetch_dict[key] = fetch.task_config.get(key)
        if fetch_dict[key] is None:
            print(f"Warning: key ({key}) not found in task_config!")

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
