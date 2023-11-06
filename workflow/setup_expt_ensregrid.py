#!/usr/bin/env python3

"""
Entry point for setting up an experiment in the global-workflow
"""

import os
import glob
import shutil
from datetime import datetime, timedelta
from argparse import ArgumentParser, ArgumentDefaultsHelpFormatter
from hosts import Host


_here = os.path.dirname(__file__)
_top = os.path.abspath(os.path.join(os.path.abspath(_here), '..'))

def makedirs_if_missing(dirname):
    """
    Creates a directory if not already present
    """
    if not os.path.exists(dirname):
        os.makedirs(dirname)

def fill_EXPDIR(inputs):
    """
    Method to copy config files from workflow to experiment directory
    INPUTS:
        inputs: user inputs to `setup_expt.py`
    """
    configdir = inputs.configdir
    expdir = os.path.join(inputs.expdir, inputs.pslot)

    configs = glob.glob(f'{configdir}/config.*')
    exclude_configs = ['base', 'base.emc.dyn', 'base.nco.static', 'fv3.nco.static']
    for exclude in exclude_configs:
        try:
            configs.remove(f'{configdir}/config.{exclude}')
        except ValueError:
            pass
    if len(configs) == 0:
        raise IOError(f'no config files found in {configdir}')
    for config in configs:
        shutil.copy(config, expdir)

    return


def edit_baseconfig(host, inputs):
    """
    Parses and populates the templated `config.base.ensregrid` to `config.base`
    """

    tmpl_dict = {
        "@MACHINE@": host.machine.upper(),
        "@PSLOT@": inputs.pslot,
        "@SDATE@": inputs.idate.strftime('%Y%m%d%H'),
        "@EDATE@": inputs.edate.strftime('%Y%m%d%H'),
        "@CYCLE_FREQ@": inputs.cycle_freq,
        "@CASECTL@": f'C{inputs.resdet}',
        "@HOMEgfs@": _top,
        "@BASE_GIT@": host.info["base_git"],
        "@NWPROD@": host.info["nwprod"],
        "@COMROOT@": host.info["comroot"],
        "@HOMEDIR@": host.info["homedir"],
        "@EXPDIR@": inputs.expdir,
        "@ROTDIR@": inputs.comrot,
        "@STMP@": inputs.stmp,
        "@PTMP@": inputs.ptmp,
        "@NOSCRUB@": host.info["noscrub"],
        "@ACCOUNT@": host.info["account"],
        "@QUEUE@": host.info["queue"],
        "@QUEUE_SERVICE@": host.info["queue_service"],
        "@PARTITION_BATCH@": host.info["partition_batch"],
        "@HPSSARCH@": host.info["hpssarch"],
        "@LOCALARCH@": host.info["localarch"],
        "@ATARDIR@": host.info["atardir"],
    }

    extend_dict = dict()
    extend_dict = {
        "@CASEENS@": f'C{inputs.resens}',
        "@NMEM_ENKF@": inputs.nens,
    }
    tmpl_dict = dict(tmpl_dict, **extend_dict)

    # Open and read the templated config.base
    base_tmpl = f'{inputs.configdir}/config.base'
    with open(base_tmpl, 'rt') as fi:
        basestr = fi.read()

    for key, val in tmpl_dict.items():
        basestr = basestr.replace(key, str(val))

    # Write and clobber the experiment config.base
    base_config = f'{inputs.expdir}/{inputs.pslot}/config.base'
    if os.path.exists(base_config):
        os.unlink(base_config)

    with open(base_config, 'wt') as fo:
        fo.write(basestr)

    print('')
    print(f'EDITED:  {base_config} as per user input.')
    print(f'DEFAULT: {base_tmpl} is for reference only.')
    print('')

    return


def input_args(host):
    """
    Method to collect user arguments for `setup_expt.py`
    """

    description = """
        Setup files and directories to start a GFS parallel.\n
        Create EXPDIR, copy config files.\n
        Create COMROT experiment directory structure,
        link initial condition files from $ICSDIR to $COMROT
        """

    parser = ArgumentParser(description=description,
                            formatter_class=ArgumentDefaultsHelpFormatter)

    parser.add_argument('--pslot', help='parallel experiment name',
                        type=str, required=False, default='test')
    parser.add_argument('--resdet', help='resolution of the deterministic model forecast',
                        type=int, required=False, default=384)
    parser.add_argument('--levs', help='model vertical levels',
                        type=int, required=False, default=91)
    parser.add_argument('--comrot', help='full path to COMROT',
                        type=str, required=False, default=os.getenv('HOME'))
    parser.add_argument('--expdir', help='full path to EXPDIR',
                        type=str, required=False, default=os.getenv('HOME'))
    parser.add_argument('--idate', help='starting date of experiment, initial conditions must exist!', required=True, type=lambda dd: datetime.strptime(dd, '%Y%m%d%H'))
    parser.add_argument('--edate', help='end date experiment', required=True, type=lambda dd: datetime.strptime(dd, '%Y%m%d%H'))
    parser.add_argument('--cycle_freq', help='cycle interval', required=False, type=int, default=1)
    parser.add_argument('--configdir', help='full path to directory containing the config files',
                        type=str, required=False, default=os.path.join(_top, 'parm/config'))
    parser.add_argument('--cdump', help='CDUMP to start the experiment',
                        type=str, required=False, default='gdas')
    parser.add_argument('--resens', help='resolution of the ensemble model forecast',
                        type=int, required=False, default=192)
    parser.add_argument('--nens', help='number of ensemble members',
                        type=int, required=False, default=20)
    parser.add_argument('--atardir', help='HPSS directory to save data', 
                        type=str, required=False, default=host.info["atardir"])
    parser.add_argument('--stmp', help='temporary run directory', 
                        type=str, required=False, default=host.info["stmp"])
    parser.add_argument('--ptmp', help='temporary archive directory', 
                        type=str, required=False, default=host.info["ptmp"])

    args = parser.parse_args()

    return args


def query_and_clean(dirname):
    """
    Method to query if a directory exists and gather user input for further action
    """

    create_dir = True
    if os.path.exists(dirname):
        print()
        print(f'directory already exists in {dirname}')
        print()
        overwrite = input('Do you wish to over-write [y/N]: ')
        create_dir = True if overwrite in [
            'y', 'yes', 'Y', 'YES'] else False
        if create_dir:
            shutil.rmtree(dirname)

    return create_dir


if __name__ == '__main__':

    host = Host()
    user_inputs = input_args(host)

    comrot = os.path.join(user_inputs.comrot, user_inputs.pslot)
    expdir = os.path.join(user_inputs.expdir, user_inputs.pslot)

    create_comrot = query_and_clean(comrot)
    create_expdir = query_and_clean(expdir)

    if create_comrot:
        makedirs_if_missing(comrot)

    if create_expdir:
        makedirs_if_missing(expdir)
        fill_EXPDIR(user_inputs)
        edit_baseconfig(host, user_inputs)
