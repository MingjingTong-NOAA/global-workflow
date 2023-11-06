#!/usr/bin/env python3

import numpy as np
from typing import List
from applications_ensregrid import AppConfig
import rocoto.rocoto as rocoto

__all__ = ['Tasks', 'create_wf_task', 'get_wf_tasks']


class Tasks:
    SERVICE_TASKS = ['eget', 'archerg']
    VALID_TASKS = ['eget','enspost', 'ergpos', 'archerg']

    def __init__(self, app_config: AppConfig, cdump: str) -> None:

        self.app_config = app_config
        self.cdump = cdump

        # Save dict_configs and base in the internal state (never know where it may be needed)
        self._configs = self.app_config.configs
        self._base = self._configs['base']

        self.n_tiles = 6  # TODO - this needs to be elsewhere

        envar_dict = {'RUN_ENVIR': self._base.get('RUN_ENVIR', 'emc'),
                      'HOMEgfs': self._base.get('HOMEgfs'),
                      'EXPDIR': self._base.get('EXPDIR'),
                      'CDUMP': self.cdump,
                      'CDATE': '<cyclestr>@Y@m@d@H</cyclestr>',
                      'PDY': '<cyclestr>@Y@m@d</cyclestr>',
                      'cyc': '<cyclestr>@H</cyclestr>',
                      'GDATE': '<cyclestr offset="-6:00:00">@Y@m@d@H</cyclestr>',
                      'GDUMP': 'gdas',
                      'gPDY': '<cyclestr offset="-6:00:00">@Y@m@d</cyclestr>',
                      'gcyc': '<cyclestr offset="-6:00:00">@H</cyclestr>'}
        self.envars = self._set_envars(envar_dict)

    @staticmethod
    def _set_envars(envar_dict) -> list:

        envars = []
        for key, value in envar_dict.items():
            envars.append(rocoto.create_envar(name=key, value=str(value)))

        return envars

    @staticmethod
    def _get_hybgroups(nens: int, nmem_per_group: int, start_index: int = 1):
        ngrps = nens / nmem_per_group
        groups = ' '.join([f'{x:02d}' for x in range(start_index, int(ngrps) + 1)])

        return groups

    @staticmethod
    def _is_this_a_gdas_task(cdump, task_name):
        if cdump != 'gdas':
            raise TypeError(f'{task_name} must be part of the "gdas" cycle and not {cdump}')

    def get_resource(self, task_name):
        """
        Given a task name (task_name) and its configuration (task_names),
        return a dictionary of resources (task_resource) used by the task.
        Task resource dictionary includes:
        account, walltime, cores, nodes, ppn, threads, memory, queue, partition, native
        """

        scheduler = self.app_config.scheduler

        task_config = self._configs[task_name]

        account = task_config['ACCOUNT']

        walltime = task_config[f'wtime_{task_name}']
        if self.cdump in ['gfs'] and f'wtime_{task_name}_gfs' in task_config.keys():
            walltime = task_config[f'wtime_{task_name}_gfs']

        cores = task_config[f'npe_{task_name}']
        if self.cdump in ['gfs'] and f'npe_{task_name}_gfs' in task_config.keys():
            cores = task_config[f'npe_{task_name}_gfs']

        ppn = task_config[f'npe_node_{task_name}']
        if self.cdump in ['gfs'] and f'npe_node_{task_name}_gfs' in task_config.keys():
            ppn = task_config[f'npe_node_{task_name}_gfs']

        nodes = np.int(np.ceil(np.float(cores) / np.float(ppn)))

        threads = task_config[f'nth_{task_name}']
        if self.cdump in ['gfs'] and f'nth_{task_name}_gfs' in task_config.keys():
            threads = task_config[f'nth_{task_name}_gfs']

        memory = task_config.get(f'memory_{task_name}', None)

        native = '--export=NONE' if scheduler in ['slurm'] else None

        queue = task_config['QUEUE']
        if task_name in Tasks.SERVICE_TASKS and scheduler not in ['slurm']:
            queue = task_config['QUEUE_SERVICE']

        partition = None
        if scheduler in ['slurm']:
            partition = task_config['QUEUE_SERVICE'] if task_name in Tasks.SERVICE_TASKS else task_config[
                'PARTITION_BATCH']

        task_resource = {'account': account,
                         'walltime': walltime,
                         'nodes': nodes,
                         'cores': cores,
                         'ppn': ppn,
                         'threads': threads,
                         'memory': memory,
                         'native': native,
                         'queue': queue,
                         'partition': partition}

        return task_resource

    def get_task(self, task_name, *args, **kwargs):
        """
        Given a task_name, call the method for that task
        """
        try:
            return getattr(self, task_name, *args, **kwargs)()
        except AttributeError:
            raise AttributeError(f'"{task_name}" is not a valid task.\n' +
                                 'Valid tasks are:\n' +
                                 f'{", ".join(Tasks.VALID_TASKS)}')

    def eget(self):

        print ('eget', self.cdump)
        self._is_this_a_gdas_task(self.cdump, 'eget')

        deps = []
        data = f'&ROTDIR;/enkfgdas.@Y@m@d/@H/atmos/mem001/gdas.t@Hz.atmf006.nc'
        dep_dict = {'type':'data', 'data':data}
        deps.append(rocoto.add_dependency(dep_dict))
        data = f'&ROTDIR;/enkfgdas.@Y@m@d/@H/atmos/mem001/gdas.t@Hz.sfcf006.nc'
        dep_dict = {'type':'data', 'data':data}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep_condition='nor', dep=deps)

        egetenvars = self.envars.copy()
        egetenvars.append(rocoto.create_envar(name='ENSGRP', value='#grp#'))

        groups = self._get_hybgroups(self._base['NMEM_ENKF'], self._configs['base']['NMEM_EARCGRP'], start_index=1)

        resources = self.get_resource('eget')
        task = create_wf_task('eget', resources, cdump=self.cdump, envar=egetenvars, dependency=dependencies,
                              metatask='egmn', varname='grp', varval=groups)

        return task

    def enspost(self):


        deps = []
        dep_dict = {'type': 'metatask', 'name': f'{"gdas"}egmn'}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep=deps)

        postenvars = self.envars.copy()
        postenvars.append(rocoto.create_envar(name='ENSGRP', value='#grp#'))

        groups = self._get_hybgroups(self._base['NMEM_ENKF'], self._configs['base']['NMEM_EARCGRP'], start_index=1)

        resources = self.get_resource('enspost')
        task = create_wf_task('enspost', resources, cdump=self.cdump, envar=postenvars, dependency=dependencies,
                              metatask='ermn', varname='grp', varval=groups)


        return task

    def ergpos(self):

        self._is_this_a_gdas_task(self.cdump, 'ergpos')

        deps = []
        dep_dict = {'type': 'metatask', 'name': f'{self.cdump}ermn'}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep=deps)

        resources = self.get_resource('ergpos')
        task = create_wf_task('ergpos', resources, cdump=self.cdump, envar=self.envars, dependency=dependencies)

        return task

    def archerg(self):

        self._is_this_a_gdas_task(self.cdump, 'earc')

        deps = []
        dep_dict = {'type': 'task', 'name': f'{self.cdump}ergpos'}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep=deps)

        resources = self.get_resource('archerg')
        task = create_wf_task('archerg', resources, cdump=self.cdump, envar=self.envars, dependency=dependencies)

        return task


def create_wf_task(task_name, resources,
                   cdump='gdas', cycledef=None, envar=None, dependency=None,
                   metatask=None, varname=None, varval=None, vardict=None,
                   final=False):
    tasknamestr = f'{cdump}{task_name}'
    metatask_dict = None
    if metatask is not None:
        tasknamestr = f'{tasknamestr}#{varname}#'
        metatask_dict = {'metataskname': f'{cdump}{metatask}',
                         'varname': f'{varname}',
                         'varval': f'{varval}',
                         'vardict': vardict}

    cycledefstr = cdump if cycledef is None else cycledef

    task_dict = {'taskname': f'{tasknamestr}',
                 'cycledef': f'{cycledefstr}',
                 'maxtries': '&MAXTRIES;',
                 'command': f'&JOBS_DIR;/{task_name}.sh',
                 'jobname': f'&PSLOT;_{tasknamestr}_@H',
                 'resources': resources,
                 'log': f'&ROTDIR;/logs/@Y@m@d@H/{tasknamestr}.log',
                 'envars': envar,
                 'dependency': dependency,
                 'final': final}

    task = rocoto.create_task(task_dict) if metatask is None else rocoto.create_metatask(task_dict, metatask_dict)

    return ''.join(task)


def get_wf_tasks(app_config: AppConfig) -> List:
    """
    Take application configuration to return a list of all tasks for that application
    """

    tasks = []
    # Loop over all keys of cycles (CDUMP)
    for cdump, cdump_tasks in app_config.task_names.items():
        task_obj = Tasks(app_config, cdump)  # create Task object based on cdump
        for task_name in cdump_tasks:
            tasks.append(task_obj.get_task(task_name))

    return tasks
