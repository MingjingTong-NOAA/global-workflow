from applications.applications import AppConfig
from wxflow import Configuration
from typing import Dict, Any


class SHiELDReplayAppConfig(AppConfig):
    '''
    Class to define SHiELD replay configurations
    '''

    def __init__(self, conf: Configuration):
        super().__init__(conf)

        base = conf.parse_config('config.base')
        self.run = base.get('RUN', 'gfs')
        self.run = "gdas"
        self.runs = [self.run]

    def _get_run_options(self, conf: Configuration) -> Dict[str, Any]:

        run_options = super()._get_run_options(conf)

        base = conf.parse_config('config.base', RUN=self.run)

        run_options[self.run]['replay'] = base.get('replay', 1)
        run_options[self.run]['icfrom'] = base.get('ICFROM', 'gfs')
        run_options[self.run]['icres'] = base.get('ICRES', 'C768')
        run_options[self.run]['shield_res'] = base.get('CASE', 'C768')
        run_options[self.run]['do_sfcanl'] = base.get('DO_SFCANL', False)
        run_options[self.run]['do_tsfc_tile'] = base.get('DO_TSFC_TILE', False)
        run_options[self.run]['do_omf'] = base.get('DO_OMF', False)
        run_options[self.run]['do_post'] = base.get('DO_POST', False)

        return run_options

    def _get_app_configs(self, run):
        """
        Returns the config_files that are involved in the replay app
        """

        options = self.run_options[run]
        configs = ['stage_ic', 'fcst', 'arch_vrfy', 'cleanup']

        if options['icfrom'] == 'gfs' or options['icfrom'] == 'shield':
            configs += ['getic', 'init']

        if options['do_atm']:

            if options['replay'] == 2:
                configs += ['analinc']

            if options['do_sfcanl']:
                configs += ['sfcanl']

            if options['do_omf']:
                configs += ['prep', 'gomg', 'analdiag']

            if options['do_post']:
                if options['do_upp']:
                    configs += ['upp']
                configs += ['atmos_products']

        return configs

    @staticmethod
    def _update_base(base_in):

        base_out = base_in.copy()
        base_out['RUN'] = 'gdas'

        return base_out

    def get_task_names(self):
        """
        Get the task names for all the tasks in the replay application.
        Note that the order of the task names matters in the XML.
        This is the place where that order is set.
        """

        tasks = ['stage_ic']
        options = self.run_options[self.run]

        if options['icfrom'] == 'gfs' or options['icfrom'] == 'shield':
            tasks += ['getic', 'init']

        tasks += ['fcst']

        if options['do_atm']:

            if options['replay'] == 2:
                tasks += ['analinc']

            if options['do_sfcanl']:
                tasks += ['sfcanl']

            if options['do_omf']:
                tasks += ['prep', 'gomg', 'analdiag']

            if options['do_post']:
                if options['do_upp']:
                    tasks += ['atmupp']
                tasks += ['atmos_prod']

        if options['do_archtar']:
            tasks += ['arch_tars']

        tasks += ['arch_vrfy', 'cleanup']  # arch_tar, arch_vrfy, and cleanup **must** be the last tasks

        return {f"{self.run}": tasks}
