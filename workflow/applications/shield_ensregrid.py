from applications.applications import AppConfig
from wxflow import Configuration
from typing import Dict, Any


class SHiELDEnsregridAppConfig(AppConfig):
    '''
    Class to define SHiELD ensemble regrid configurations
    '''

    def __init__(self, conf: Configuration):
        super().__init__(conf)

        base = conf.parse_config('config.base')
        self.run = base.get('RUN', 'enkfgdas')
        self.runs = [self.run]

    def _get_run_options(self, conf: Configuration) -> Dict[str, Any]:

        run_options = super()._get_run_options(conf)

        base = conf.parse_config('config.base', RUN=self.run) 
        
        return run_options

    def _get_app_configs(self, run):
        """
        Returns the config_files that are involved in the ensemble regrid app
        """

        configs = ['eget', 'ensupp', 'ergpos', 'ergarc', 'cleanup']

        return configs

    @staticmethod
    def _update_base(base_in):

        base_out = base_in.copy()
        base_out['RUN'] = 'enkfgdas'

        return base_out

    def get_task_names(self):
        """
        Get the task names for all the tasks in the ensemble regrid application.
        Note that the order of the task names matters in the XML.
        This is the place where that order is set.
        """

        tasks = ['eget', 'ensupp', 'ergpos', 'ergarc', 'cleanup']

        return {f"{self.run}": tasks}
