#!/usr/bin/env python3

from typing import Dict, Any
from datetime import timedelta
from configuration import Configuration
from hosts import Host

__all__ = ['AppConfig']

def interval_map(erg_cyc: int) -> str:
    """
    return interval in hours based on erg_cyc
    """

    erg_internal_map = {'0': None, '1': '24:00:00', '2': '12:00:00', '4': '06:00:00'}

    try:
        return erg_internal_map[str(erg_cyc)]
    except KeyError:
        raise KeyError(f'Invalid erg_cyc = {erg_cyc}')

def get_cyc_interval(base: Dict[str, Any]) -> Dict[str, Any]:
    """
    Generate GFS dates from experiment dates and gfs_cyc choice
    """

    base_out = base.copy()

    erg_cyc = base['CYCLE_FREQ']

    interval = interval_map(erg_cyc)
    base_out['INTERVAL'] = interval

    return base_out

class AppConfig:

    def __init__(self, configuration: Configuration) -> None:

        self.scheduler = Host().scheduler

        _base = configuration.parse_config('config.base')

        # Get a list of all possible config_files that would be part of the application
        self.configs_names = ['eget','enspost','ergpos','archerg']

        # Source the config_files for the jobs in the application
        self.configs = self._source_configs(configuration)

        self.configs['base'] = self._upd_base(self.configs['base'])

        # Save base in the internal state since it is often needed
        self._base = self.configs['base']

        # Finally get task names for the application
        self.task_names = self.get_task_names()

    @staticmethod
    def _upd_base(base_in):

        return get_cyc_interval(base_in)

    def _source_configs(self, configuration: Configuration) -> Dict[str, Any]:
        """
        Given the configuration object and jobs,
        source the configurations for each config and return a dictionary
        Every config depends on "config.base"
        """

        configs = dict()

        # Return config.base as well
        configs['base'] = configuration.parse_config('config.base')

        # Source the list of all config_files involved in the application
        for config in self.configs_names:

            # All must source config.base first
            files = ['config.base']

            files += [f'config.{config}']

            print(f'sourcing config.{config}')
            configs[config] = configuration.parse_config(files)

        return configs

    def get_task_names(self):

        tasks = []

        tasks += ['eget','enspost','ergpos','archerg']

        return {'gdas': tasks}

