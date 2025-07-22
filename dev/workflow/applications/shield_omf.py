from applications.applications import AppConfig
from wxflow import Configuration
from typing import Dict, Any


class SHiELDOmfAppConfig(AppConfig):
    '''
    Class to define SHiELD OmF configurations
    '''

    def __init__(self, conf: Configuration):
        super().__init__(conf)

        base = conf.parse_config('config.base')
        self.run = "gdas"
        self.runs = [self.run]

    def _get_run_options(self, conf: Configuration) -> Dict[str, Any]:

        run_options = super()._get_run_options(conf)

        base = conf.parse_config('config.base', RUN=self.run)

        return run_options

    def _get_app_configs(self, run):
        """
        Returns the config_files that are involved in the OmF app
        """

        options = self.run_options[run]
        configs = ['dfetch', 'prep', 'gomg', 'analdiag', 'arch_vrfy', 'arch_tars', 'cleanup']

        return configs

    @staticmethod
    def _update_base(base_in):

        base_out = base_in.copy()
        base_out['RUN'] = 'gdas'

        return base_out

    def get_task_names(self):
        """
        Get the task names for all the tasks in the OmF application.
        Note that the order of the task names matters in the XML.
        This is the place where that order is set.
        """

        tasks = ['dfetch', 'prep', 'gomg', 'analdiag', 'arch_vrfy', 'arch_tars', 'cleanup']

        return {f"{self.run}": tasks}
