#!/usr/bin/env python3

'''
    PROGRAM:
        Create the ROCOTO workflow for a replay experiment

    AUTHOR:
        Mingjing.Tong
        mingjing.tong@noaa.gov

    FILE DEPENDENCIES:
        1. config files for the parallel; e.g. config.base, config.fcst[.gfs], etc.
        Without this dependency, the script will fail

    OUTPUT:
        1. PSLOT.xml: XML workflow
        2. PSLOT.crontab: crontab for ROCOTO run command

'''

import os
import sys
import re
import numpy as np
from datetime import datetime, timedelta
from argparse import ArgumentParser, ArgumentDefaultsHelpFormatter
from collections import OrderedDict
import rocoto
import workflow_utils as wfu

def main():
    parser = ArgumentParser(description='Setup XML workflow and CRONTAB for a forecast only experiment.', formatter_class=ArgumentDefaultsHelpFormatter)
    parser.add_argument('--expdir',help='full path to experiment directory containing config files', type=str, required=False, default=os.environ['PWD'])
    parser.add_argument('--cdump',help='cycle to run forecasts', type=str, choices=['gdas', 'gfs'], default='gdas', required=False)

    args = parser.parse_args()

    configs = wfu.get_configs(args.expdir)

    _base = wfu.config_parser([wfu.find_config('config.base', configs)])

    replay = _base['replay']
   

    if not os.path.samefile(args.expdir,_base['EXPDIR']):
        print('MISMATCH in experiment directories!')
        print(f'config.base: EXPDIR = {repr(_base["EXPDIR"])}')
        print(f'input arg:     --expdir = {repr(args.expdir)}')
        sys.exit(1)

    taskplan = ['getic', 'init', 'analinc', 'fcst', 'prep', 'gomg', 'gcycle', 'gldas', 'analdiag', 'post', 'vrfy', 'metp', 'arch']

    dict_configs = wfu.source_configs(configs, taskplan)

    dict_configs['base']['CDUMP'] = args.cdump

    # Check and set gfs_cyc specific variables
    if dict_configs['base']['gfs_cyc'] != 0:
        dict_configs['base'] = get_gfs_cyc_dates(dict_configs['base'])

    # First create workflow XML
    create_xml(dict_configs)

    # Next create the crontab
    wfu.create_crontab(dict_configs['base'])

    return

def get_gfs_cyc_dates(base):
    '''
        Generate GFS dates from experiment dates and gfs_cyc choice
    '''

    base_out = base.copy()

    gfs_cyc = base['gfs_cyc']
    sdate = base['SDATE']
    edate = base['EDATE']
    gfs_delay = base['gfs_delay']

    interval_gfs = wfu.get_gfs_interval(gfs_cyc)

    # Set GFS cycling dates
    hrdet = 0
    if gfs_cyc == 1:
        hrinc = 24 - sdate.hour
        hrdet = edate.hour
    elif gfs_cyc == 2:
        if sdate.hour in [0, 12]:
            hrinc = 12
        elif sdate.hour in [6, 18]:
            hrinc = 6
        if edate.hour in [6, 18]:
            hrdet = 6
    elif gfs_cyc == 4:
        hrinc = 6
    sdate_gfs = sdate + timedelta(days=gfs_delay) + timedelta(hours=hrinc)
    edate_gfs = edate - timedelta(hours=hrdet)
    if sdate_gfs > edate:
        print('W A R N I N G!')
        print('Starting date for GFS cycles is after Ending date of experiment')
        print(f'SDATE = {sdate.strftime("%Y%m%d%H")},     EDATE = {edate.strftime("%Y%m%d%H")}')
        print(f'SDATE_GFS = {sdate_gfs.strftime("%Y%m%d%H")}, EDATE_GFS = {edate_gfs.strftime("%Y%m%d%H")}')
        gfs_cyc = 0

    base_out['gfs_cyc'] = gfs_cyc
    base_out['SDATE_GFS'] = sdate_gfs
    base_out['EDATE_GFS'] = edate_gfs
    base_out['INTERVAL_GFS'] = interval_gfs

    fhmax_gfs = {}
    for hh in ['00', '06', '12', '18']:
        fhmax_gfs[hh] = base.get(f'FHMAX_GFS_{hh}', 'FHMAX_GFS_00')
    base_out['FHMAX_GFS'] = fhmax_gfs

    return base_out

def get_preamble():
    '''
        Generate preamble for XML
    '''

    strings = []

    strings.append('<?xml version="1.0"?>\n')
    strings.append('<!DOCTYPE workflow\n')
    strings.append('[\n')
    strings.append('\t<!--\n')
    strings.append('\tPROGRAM\n')
    strings.append('\t\tMain workflow manager for replay cycling Global Forecast System\n')
    strings.append('\n')
    strings.append('\tAUTHOR:\n')
    strings.append('\t\tMingjing Tong\n')
    strings.append('\t\tmingjing.tong@noaa.gov\n')
    strings.append('\n')
    strings.append('\tNOTES:\n')
    strings.append(f'\t\tThis workflow was automatically generated at {datetime.now()}\n')
    strings.append('\t-->\n')

    return ''.join(strings)


def get_definitions(base):
    '''
        Create entities related to the experiment
    '''

    machine = base.get('machine', wfu.detectMachine())
    scheduler = wfu.get_scheduler(machine)

    strings = []

    strings.append('\n')
    strings.append('\t<!-- Experiment parameters such as name, cycle, resolution -->\n')
    strings.append(f'''\t<!ENTITY PSLOT    "{base['PSLOT']}">\n''')
    strings.append(f'''\t<!ENTITY CDUMP    "{base['CDUMP']}">\n''')
    strings.append(f'''\t<!ENTITY CASE     "{base['CASE']}">\n''')
    strings.append('\n')
    strings.append('\t<!-- Experiment parameters such as starting, ending dates -->\n')
    strings.append(f'''\t<!ENTITY SDATE    "{base['SDATE'].strftime('%Y%m%d%H%M')}">\n''')
    strings.append(f'''\t<!ENTITY EDATE    "{base['EDATE'].strftime('%Y%m%d%H%M')}">\n''')

    if base['gfs_cyc'] != 0:
        strings.append(get_gfs_dates(base))
        strings.append('\n')

    strings.append('\n')
    strings.append('\t<!-- Run Envrionment -->\n')
    strings.append(f'''\t<!ENTITY RUN_ENVIR "{base['RUN_ENVIR']}">\n''')
    strings.append('\n')
    strings.append('\t<!-- Experiment and Rotation directory -->\n')
    strings.append(f'''\t<!ENTITY EXPDIR "{base['EXPDIR']}">\n''')
    strings.append(f'''\t<!ENTITY ROTDIR "{base['ROTDIR']}">\n''')
    strings.append(f'''\t<!ENTITY ICSDIR "{base['ICSDIR']}">\n''')
    strings.append(f'''\t<!ENTITY ECICSDIR "{base['ECICSDIR']}">\n''')
    strings.append('\n')
    strings.append('\t<!-- Directories for driving the workflow -->\n')
    strings.append(f'''\t<!ENTITY HOMEgfs  "{base['HOMEgfs']}">\n''')
    strings.append(f'''\t<!ENTITY JOBS_DIR "{base['BASE_JOB']}">\n''')
    strings.append(f'''\t<!ENTITY DMPDIR   "{base['DMPDIR']}">\n''')
    strings.append('\n')
    strings.append('\t<!-- Machine related entities -->\n')
    strings.append(f'''\t<!ENTITY ACCOUNT    "{base['ACCOUNT']}">\n''')
    strings.append(f'''\t<!ENTITY QUEUE      "{base['QUEUE']}">\n''')
    strings.append(f'''\t<!ENTITY QUEUE_SERVICE "{base['QUEUE_SERVICE']}">\n''')
    if scheduler in ['slurm']:
        strings.append(f'''\t<!ENTITY PARTITION_BATCH "{base['PARTITION_BATCH']}">\n''')
        strings.append(f'''\t<!ENTITY PARTITION_SERVICE "{base['QUEUE_SERVICE']}">\n''')
    strings.append(f'\t<!ENTITY SCHEDULER  "{scheduler}">\n')
    strings.append('\n')
    strings.append('\t<!-- Toggle HPSS archiving -->\n')
    strings.append(f'''\t<!ENTITY ARCHIVE_TO_HPSS "{base['HPSSARCH']}">\n''')
    strings.append('\n')
    strings.append('\t<!-- ROCOTO parameters that control workflow -->\n')
    strings.append('\t<!ENTITY CYCLETHROTTLE "6">\n')
    strings.append('\t<!ENTITY TASKTHROTTLE  "25">\n')
    strings.append('\t<!ENTITY MAXTRIES      "2">\n')
    strings.append('\n')

    return ''.join(strings)

def get_gfs_dates(base):
    '''
        Generate GFS dates entities
    '''

    strings = []

    strings.append('\n')
    strings.append('\t<!-- Starting and ending dates for GFS cycle -->\n')
    strings.append(f'''\t<!ENTITY SDATE_GFS    "{base['SDATE_GFS'].strftime('%Y%m%d%H%M')}">\n''')
    strings.append(f'''\t<!ENTITY EDATE_GFS    "{base['EDATE_GFS'].strftime('%Y%m%d%H%M')}">\n''')
    strings.append(f'''\t<!ENTITY INTERVAL_GFS "{base['INTERVAL_GFS']}">\n''')

    return ''.join(strings)


def get_gdasgfs_resources(dict_configs, cdump='gdas'):
    '''
        Create resource entities
    '''

    strings = []

    strings.append('\t<!-- BEGIN: Resource requirements for the workflow -->\n')
    strings.append('\n')

    base = dict_configs['base']
    machine = base.get('machine', wfu.detectMachine())
    reservation = base.get('RESERVATION', 'NONE').upper()
    scheduler = wfu.get_scheduler(machine)

    do_gempak = base.get('DO_GEMPAK', 'NO').upper()
    do_awips = base.get('DO_AWIPS', 'NO').upper()
    do_metp = base.get('DO_METP', 'NO').upper()
    replay = base.get('replay', 1)

    if cdump in ['gdas']:
        if replay == 1:
            tasks = ['getic', 'init', 'fcst', 'prep', 'gomg', 'gcycle', 'gldas', 'analdiag', 'post', 'vrfy', 'arch']
        else:
            tasks = ['getic', 'init', 'analinc', 'fcst', 'prep', 'gomg', 'gcycle', 'gldas', 'analdiag', 'post', 'vrfy', 'arch']
    else:
        tasks = [ 'fcst', 'post', 'vrfy', 'metp', 'arch']

    dict_resources = OrderedDict()

    for task in tasks:

        cfg = dict_configs[task]

        wtimestr, resstr, queuestr, memstr, natstr = wfu.get_resources(machine, cfg, task, reservation, cdump=cdump)
        taskstr = f'{task.upper()}_{cdump.upper()}'

        strings = []
        strings.append(f'\t<!ENTITY QUEUE_{taskstr}     "{queuestr}">\n')
        if scheduler in ['slurm']:
            if task in ['getic','arch']:
                strings.append(f'\t<!ENTITY PARTITION_{taskstr} "&PARTITION_SERVICE;">\n')
            else:
                strings.append(f'\t<!ENTITY PARTITION_{taskstr} "&PARTITION_BATCH;">\n')

        strings.append(f'\t<!ENTITY WALLTIME_{taskstr}  "{wtimestr}">\n')
        strings.append(f'\t<!ENTITY RESOURCES_{taskstr} "{resstr}">\n')
        if len(memstr) != 0:
            strings.append(f'\t<!ENTITY MEMORY_{taskstr}    "{memstr}">\n')
        strings.append(f'\t<!ENTITY NATIVE_{taskstr}    "{natstr}">\n')

        dict_resources[f'{cdump}{task}'] = ''.join(strings)

    return dict_resources

def get_postgroups(post, cdump='gdas'):

    fhmin = post['FHMIN']
    fhmax = post['FHMAX']
    fhout = post['FHOUT']

    # Get a list of all forecast hours
    if cdump in ['gdas']:
        fhrs = range(fhmin, fhmax+fhout, fhout)
    elif cdump in ['gfs']:
        fhmax = np.max([post['FHMAX_GFS_00'],post['FHMAX_GFS_06'],post['FHMAX_GFS_12'],post['FHMAX_GFS_18']])
        fhout = post['FHOUT_GFS']
        fhmax_hf = post['FHMAX_HF_GFS']
        fhout_hf = post['FHOUT_HF_GFS']
        fhrs_hf = range(fhmin, fhmax_hf+fhout_hf, fhout_hf)
        fhrs = list(fhrs_hf) + list(range(fhrs_hf[-1]+fhout, fhmax+fhout, fhout))

    npostgrp = post['NPOSTGRP']
    ngrps = npostgrp if len(fhrs) > npostgrp else len(fhrs)

    fhrs = [f'f{f:03d}' for f in fhrs]
    fhrs = np.array_split(fhrs, ngrps)
    fhrs = [f.tolist() for f in fhrs]

    fhrgrp = ' '.join([f'{x:03d}' for x in range(0, ngrps+1)])
    fhrdep = ' '.join(['anl'] + [f[-1] for f in fhrs])
    fhrlst = ' '.join(['anl'] + ['_'.join(f) for f in fhrs])

    return fhrgrp, fhrdep, fhrlst

def get_gdasgfs_tasks(dict_configs, cdump='gdas'):
    '''
        Create GDAS or GFS tasks
    '''

    envars = []
    if wfu.get_scheduler(wfu.detectMachine()) in ['slurm']:
        envars.append(rocoto.create_envar(name='SLURM_SET', value='YES'))
    envars.append(rocoto.create_envar(name='RUN_ENVIR', value='&RUN_ENVIR;'))
    envars.append(rocoto.create_envar(name='HOMEgfs', value='&HOMEgfs;'))
    envars.append(rocoto.create_envar(name='EXPDIR', value='&EXPDIR;'))
    envars.append(rocoto.create_envar(name='CDATE', value='<cyclestr>@Y@m@d@H</cyclestr>'))
    envars.append(rocoto.create_envar(name='CDUMP', value=f'{cdump}'))
    envars.append(rocoto.create_envar(name='PDY', value='<cyclestr>@Y@m@d</cyclestr>'))
    envars.append(rocoto.create_envar(name='cyc', value='<cyclestr>@H</cyclestr>'))

    base = dict_configs['base']
    do_gempak = base.get('DO_GEMPAK', 'NO').upper()
    do_awips = base.get('DO_AWIPS', 'NO').upper()
    do_wafs = base.get('WAFSF', 'NO').upper()
    do_metp = base.get('DO_METP', 'NO').upper()
    warm_start = base.get('EXP_WARM_START', ".false.")
    do_gomg = base.get('DO_OmF', 'NO').upper()
    do_gldas = base.get('DO_GLDAS', 'NO').upper()
    do_post = base.get('DO_POST', 'YES').upper()
    hpssarch = base.get('HPSSARCH', 'YES').upper()
    dumpsuffix = base.get('DUMP_SUFFIX', '')
    gridsuffix = base.get('SUFFIX', '')
    icdump = base.get('ICDUMP', 'gdas')
    icstyp = base.get('ICSTYP', 'gfs')
    gfs_cyc = base.get('gfs_cyc', 0)
    replay = base.get('replay', 1)
    do_gcycle = base.get('DOGCYCLE','YES')
    gdaspost = base.get('gdaspost', 'NO').upper()

    dict_tasks = OrderedDict()

    # getics
    if cdump in ['gdas']:
        deps = []
        dep_dict = {'type': 'task', 'name': f'{cdump}fcst', 'offset': '-06:00:00'}
        deps.append(rocoto.add_dependency(dep_dict))
        data = f'&ROTDIR;/{cdump}.@Y@m@d/@H/atmos/RESTART/'
        data2 = '@Y@m@d.@H0000.coupler.res'
        dep_dict = {'type': 'data', 'data': data, 'age': 30, 'offset': '-06:00:00',
                    'data2': data2}
        deps.append(rocoto.add_dependency(dep_dict))
        dep_dict = {'type': 'cycleexist', 'condition': 'not', 'offset': '-06:00:00'}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep_condition='or', dep=deps)
        
        task = wfu.create_wf_task('getic', cdump=cdump, envar=envars, dependency=dependencies)

        dict_tasks[f'{cdump}getic'] = task
    
    # chgres init
    if cdump in ['gdas']:
        deps = []
        data = f'&ICSDIR;/{icdump}.@Y@m@d/@H/{icdump}.t@Hz.sanl'
        dep_dict = {'type':'data', 'data':data}
        deps.append(rocoto.add_dependency(dep_dict))
        data = f'&ICSDIR;/{icdump}.@Y@m@d/@H/{icdump}.t@Hz.atmanl.nemsio'
        dep_dict = {'type':'data', 'data':data}
        deps.append(rocoto.add_dependency(dep_dict))
        data = f'&ICSDIR;/{icdump}.@Y@m@d/@H/{icdump}.t@Hz.atmanl.nc'
        dep_dict = {'type':'data', 'data':data}
        deps.append(rocoto.add_dependency(dep_dict))
        data = f'&ICSDIR;/{icdump}.@Y@m@d/@H/atmos/{icdump}.t@Hz.atmanl.nc'
        dep_dict = {'type':'data', 'data':data}
        deps.append(rocoto.add_dependency(dep_dict))
        data = f'&ICSDIR;/{icdump}.@Y@m@d/@H/atmos/RESTART/@Y@m@d.@H0000.sfcanl_data.tile6.nc'
        dep_dict = {'type':'data', 'data':data}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep_condition='or', dep=deps)

        if hpssarch in ['YES']:
          deps = []
          dep_dict = {'type': 'task', 'name': f'{cdump}getic'}
          deps.append(rocoto.add_dependency(dep_dict))
          dependencies2 = rocoto.create_dependency(dep=deps)

        deps = []
        deps.append(dependencies)
        if hpssarch in ['YES']:
          deps.append(dependencies2)
          dependencies = rocoto.create_dependency(dep_condition='and', dep=deps)

        if replay == 1 or not do_gcycle in ['Y', 'YES']:
            task = wfu.create_wf_task('init', cdump=cdump, envar=envars, dependency=dependencies)
        else:
            task = wfu.create_wf_task('init', cdump=cdump, envar=envars, dependency=dependencies,
                                      cycledef='first')

        dict_tasks[f'{cdump}init'] = task

    # analinc
    if cdump in ['gdas'] and replay == 2:
        deps = []
        dep_dict = {'type': 'task', 'name': f'{cdump}getic'}
        deps.append(rocoto.add_dependency(dep_dict))
        data = f'&ROTDIR;/{cdump}.@Y@m@d/@H/atmos/{cdump}.t@Hz.logf009.txt'
        dep_dict = {'type': 'data', 'data': data, 'age': 30, 'offset': '-06:00:00'}
        deps.append(rocoto.add_dependency(dep_dict))

        dep_dict = {'type': 'task', 'name': f'{cdump}fcst', 'offset': '-06:00:00'}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep_condition='and', dep=deps)

        task = wfu.create_wf_task('analinc', cdump=cdump, envar=envars, dependency=dependencies)

        dict_tasks[f'{cdump}analinc'] = task

    if cdump in ['gdas']:
    # prep
        deps = []
        data = f'&ROTDIR;/{cdump}.@Y@m@d/@H/atmos/RESTART/'
        data2 = '@Y@m@d.@H0000.coupler.res'
        dep_dict = {'type': 'data', 'data': data, 'age': 30, 'offset': '-06:00:00',
                    'data2': data2}
        deps.append(rocoto.add_dependency(dep_dict))
        data = f'&DMPDIR;/{cdump}{dumpsuffix}.@Y@m@d/@H/{cdump}.t@Hz.updated.status.tm00.bufr_d'
        dep_dict = {'type': 'data', 'data': data}
        deps.append(rocoto.add_dependency(dep_dict))
        dep_dict = {'type': 'task', 'name': f'{cdump}getic'}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep_condition='and', dep=deps)
    
        task = wfu.create_wf_task('prep', cdump=cdump, envar=envars, dependency=dependencies)

        dict_tasks[f'{cdump}prep'] = task
    
    # gcycle
        if do_gcycle in ['Y', 'YES']:
            deps = []
            dep_dict = {'type': 'task', 'name': f'{cdump}prep'}
            deps.append(rocoto.add_dependency(dep_dict))
            dep_dict = {'type': 'task', 'name': f'{cdump}init'}
            deps.append(rocoto.add_dependency(dep_dict))
            data = f'&ROTDIR;/{cdump}.@Y@m@d/@H/atmos/RESTART/'
            data2 = '@Y@m@d.@H0000.coupler.res'
            dep_dict = {'type': 'data', 'data': data, 'age': 120, 'offset': '-06:00:00',
                        'data2': data2}
            deps.append(rocoto.add_dependency(dep_dict))
            dependencies = rocoto.create_dependency(dep_condition='and', dep=deps)
    
            task = wfu.create_wf_task('gcycle', cdump=cdump, envar=envars, dependency=dependencies)
    
            dict_tasks[f'{cdump}gcycle'] = task

   # gldas
    if cdump in ['gdas'] and do_gldas in ['Y', 'YES'] and do_gcycle in ['Y', 'YES']:
        deps1 = []
        data = f'&ROTDIR;/{cdump}.@Y@m@d/@H/atmos/{cdump}.t@Hz.loginc.txt'
        dep_dict = {'type': 'data', 'data': data}
        deps1.append(rocoto.add_dependency(dep_dict))
        dep_dict = {'type': 'task', 'name': f'{cdump}gcycle'}
        deps1.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep_condition='or', dep=deps1)

        if warm_start == ".false.":
            deps2 = []
            deps2 = dependencies
            dep_dict = {'type': 'cycleexist', 'offset': '-06:00:00'}
            deps2.append(rocoto.add_dependency(dep_dict))
            dependencies = rocoto.create_dependency(dep_condition='and', dep=deps2)

        task = wfu.create_wf_task('gldas', cdump=cdump, envar=envars, dependency=dependencies)
        dict_tasks[f'{cdump}gldas'] = task

    # fcst
    if warm_start == ".true.":
        deps1 = []
        if do_gcycle in ['Y', 'YES']:
            dep_dict = {'type': 'task', 'name': 'gdasgcycle'}
            deps1.append(rocoto.add_dependency(dep_dict))
            if do_gldas in ['Y', 'YES']:
                dep_dict = {'type': 'task', 'name': 'gdasgldas'}
                deps1.append(rocoto.add_dependency(dep_dict))
        else:
            data = f'&ROTDIR;/{icdump}.@Y@m@d/@H/atmos/RESTART/'
            data2 = '@Y@m@d.@H0000.sfcanl_data.tile6.nc'
            dep_dict = {'type': 'data', 'data': data, 'data2': data2, 'offset2': '-03:00:00',}
            deps1.append(rocoto.add_dependency(dep_dict))
        if replay == 1:
            if icstyp == 'gfs':
                data = '&ROTDIR;/&CDUMP;.@Y@m@d/@H/atmos/INPUT/sfc_data.tile6.nc'
                dep_dict = {'type':'data', 'data':data}
                deps1.append(rocoto.add_dependency(dep_dict))
            else:
                data = '&ECICSDIR;/IFS_AN0_@Y@m@d.@HZ.nc'
                dep_dict = {'type':'data', 'data':data}
                deps1.append(rocoto.add_dependency(dep_dict))
        elif replay == 2:
            data = '&ROTDIR;/&CDUMP;.@Y@m@d/@H/atmos/gdas.t@Hz.atminc.nc'
            dep_dict = {'type':'data', 'data':data}
            deps1.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep_condition='and', dep=deps1)
    else:
        deps2 = []
        dep_dict = {'type': 'cycleexist', 'condition': 'not', 'offset': '-06:00:00'}
        deps2.append(rocoto.add_dependency(dep_dict))
        data = '&ROTDIR;/&CDUMP;.@Y@m@d/@H/atmos/INPUT/sfc_data.tile6.nc'
        dep_dict = {'type':'data', 'data':data}
        deps2.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep_condition='and', dep=deps2)

    task = wfu.create_wf_task('fcst', cdump=cdump, envar=envars, dependency=dependencies)

    dict_tasks[f'{cdump}fcst'] = task

    # gomg
    if do_gomg in ['Y', 'YES'] and cdump in ['gdas']:
        deps = []
        dep_dict = {'type': 'task', 'name': f'{cdump}prep'}
        deps.append(rocoto.add_dependency(dep_dict))
        data = f'&ROTDIR;/{cdump}.@Y@m@d/@H/atmos/{cdump}.t@Hz.sfcf006{gridsuffix}'
        dep_dict = {'type': 'data', 'data': data, 'age': 30, 'offset': '-06:00:00'}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep_condition='and', dep=deps)

        task = wfu.create_wf_task('gomg', cdump=cdump, envar=envars, dependency=dependencies,
                                  cycledef='gdas')
        dict_tasks[f'{cdump}gomg'] = task

        # analdiag
        deps = []
        dep_dict = {'type': 'task', 'name': f'{cdump}gomg'}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep=deps)
        task = wfu.create_wf_task('analdiag', cdump=cdump, envar=envars, dependency=dependencies)
        dict_tasks[f'{cdump}analdiag'] = task

    # post
    if do_post in ['Y', 'YES'] and (cdump in ['gfs'] or gdaspost in ['Y', 'YES']):
        deps = []
        data = f'&ROTDIR;/{cdump}.@Y@m@d/@H/atmos/{cdump}.t@Hz.log#dep#.txt'
        dep_dict = {'type': 'data', 'data': data}
        deps.append(rocoto.add_dependency(dep_dict))
        dep_dict = {'type': 'task', 'name': f'{cdump}fcst'}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep_condition='or', dep=deps)
        fhrgrp = rocoto.create_envar(name='FHRGRP', value='#grp#')
        fhrlst = rocoto.create_envar(name='FHRLST', value='#lst#')
        ROTDIR = rocoto.create_envar(name='ROTDIR', value='&ROTDIR;')
        postenvars = envars + [fhrgrp] + [fhrlst] + [ROTDIR]
        varname1, varname2, varname3 = 'grp', 'dep', 'lst'
        varval1, varval2, varval3 = get_postgroups(dict_configs['post'], cdump=cdump)
        vardict = {varname2: varval2, varname3: varval3}
        task = wfu.create_wf_task('post', cdump=cdump, envar=postenvars, dependency=dependencies,
                                  metatask='post', varname=varname1, varval=varval1, 
                                  vardict=vardict)
        dict_tasks[f'{cdump}post'] = task

    # vrfy
    if do_post in ['Y', 'YES'] and (cdump in ['gfs'] or gdaspost in ['Y', 'YES']):
        deps = []
        dep_dict = {'type':'metatask', 'name':f'{cdump}post'}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep=deps)
        task = wfu.create_wf_task('vrfy', cdump=cdump, envar=envars, dependency=dependencies)
        dict_tasks[f'{cdump}vrfy'] = task
    
    # metp
    if cdump in ['gfs'] and do_metp in ['Y', 'YES'] and do_post in ['Y', 'YES']:
        deps = []
        dep_dict = {'type':'metatask', 'name':f'{cdump}post'}
        deps.append(rocoto.add_dependency(dep_dict))
        dep_dict = {'type':'task', 'name':f'{cdump}arch', 'offset':'-&INTERVAL_GFS;'}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep_condition='and', dep=deps)
        sdate_gfs = rocoto.create_envar(name='SDATE_GFS', value='&SDATE_GFS;')
        metpcase = rocoto.create_envar(name='METPCASE', value='#metpcase#')
        metpenvars = envars + [sdate_gfs] + [metpcase]
        varname1 = 'metpcase'
        varval1 = 'g2g1 g2o1 pcp1'
        task = wfu.create_wf_task('metp', cdump=cdump, envar=metpenvars, dependency=dependencies,
                                   metatask='metp', varname=varname1, varval=varval1)
        dict_tasks[f'{cdump}metp'] = task

    # arch
    if cdump in ['gfs'] or gdaspost in ['Y', 'YES']:
        deps = []
        dep_dict = {'type':'task', 'name':f'{cdump}vrfy'}
        deps.append(rocoto.add_dependency(dep_dict))
        dep_dict = {'type':'streq', 'left':'&ARCHIVE_TO_HPSS;', 'right':'YES'}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep_condition='and', dep=deps)
    else:
        deps = []
        dep_dict = {'type': 'task', 'name': f'{cdump}analdiag'}
        deps.append(rocoto.add_dependency(dep_dict))
        dep_dict = {'type': 'task', 'name': f'{cdump}fcst'}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep_condition='and', dep=deps)
        
    task= wfu.create_wf_task('arch', cdump=cdump, envar=envars, dependency=dependencies) 
    dict_tasks[f'{cdump}arch'] = task

    return dict_tasks


def get_workflow_header(base):
    '''
        Create the workflow header block
    '''

    strings = []

    strings.append('\n')
    strings.append(']>\n')
    strings.append('\n')
    strings.append('<workflow realtime="F" scheduler="&SCHEDULER;" cyclethrottle="&CYCLETHROTTLE;" taskthrottle="&TASKTHROTTLE;">\n')
    strings.append('\n')
    strings.append('\t<log verbosity="10"><cyclestr>&EXPDIR;/logs/@Y@m@d@H.log</cyclestr></log>\n')
    strings.append('\n')
    strings.append('\t<!-- Define the cycles -->\n')
    strings.append('\t<cycledef group="first">&SDATE;     &SDATE;     06:00:00</cycledef>\n')
    strings.append('\t<cycledef group="gdas" >&SDATE;     &EDATE;     06:00:00</cycledef>\n')
    if base['gfs_cyc'] != 0:
        strings.append('\t<cycledef group="gfs"  >&SDATE_GFS; &EDATE_GFS; &INTERVAL_GFS;</cycledef>\n')

    strings.append('\n')

    return ''.join(strings)

def get_workflow_footer():
    '''
        Generate workflow footer
    '''

    strings = []
    strings.append('\n</workflow>\n')

    return ''.join(strings)

def dict_to_strings(dict_in):

    strings = []
    for key in dict_in.keys():
        strings.append(dict_in[key])
        strings.append('\n')

    return ''.join(strings)

def create_xml(dict_configs):
    '''
        Given an experiment directory containing config files and
        XML directory containing XML templates, create the workflow XML
    '''

    base = dict_configs['base']
    gfs_cyc = base.get('gfs_cyc', 0)

    # Start collecting workflow pieces
    preamble = get_preamble()
    definitions = get_definitions(base)
    workflow_header = get_workflow_header(base)
    workflow_footer = get_workflow_footer()

    # Get GDAS related entities, resources, workflow
    dict_gdas_resources = get_gdasgfs_resources(dict_configs)
    dict_gdas_tasks = get_gdasgfs_tasks(dict_configs)

    # Get GFS cycle related entities, resources, workflow
    dict_gfs_resources = get_gdasgfs_resources(dict_configs, cdump='gfs')
    dict_gfs_tasks = get_gdasgfs_tasks(dict_configs, cdump='gfs')

    # Removes <memory>&MEMORY_JOB_DUMP</memory> post mortem from gdas tasks
    for each_task, each_resource_string in dict_gdas_resources.items():
        if each_task not in dict_gdas_tasks:
            continue
        if 'MEMORY' not in each_resource_string:
            temp_task_string = []
            for each_line in re.split(r'(\s+)', dict_gdas_tasks[each_task]):
                if 'memory' not in each_line:
                     temp_task_string.append(each_line)
            dict_gdas_tasks[each_task] = ''.join(temp_task_string)

    # Removes <memory>&MEMORY_JOB_DUMP</memory> post mortem from gfs tasks
    for each_task, each_resource_string in dict_gfs_resources.items():
        if each_task not in dict_gfs_tasks:
            continue
        if 'MEMORY' not in each_resource_string:
            temp_task_string = []
            for each_line in re.split(r'(\s+)', dict_gfs_tasks[each_task]):
                if 'memory' not in each_line:
                     temp_task_string.append(each_line)
            dict_gfs_tasks[each_task] = ''.join(temp_task_string)

    # Put together the XML file
    xmlfile = []

    xmlfile.append(preamble)

    xmlfile.append(definitions)

    xmlfile.append(dict_to_strings(dict_gdas_resources))

    if gfs_cyc != 0:
        xmlfile.append(dict_to_strings(dict_gfs_resources))

    xmlfile.append(workflow_header)

    xmlfile.append(dict_to_strings(dict_gdas_tasks))

    if gfs_cyc != 0:
        xmlfile.append(dict_to_strings(dict_gfs_tasks))

    xmlfile.append(workflow_footer)

    # Write the XML file
    fh = open(f'{base["EXPDIR"]}/{base["PSLOT"]}.xml', 'w')
    fh.write(''.join(xmlfile))
    fh.close()

    return

if __name__ == '__main__':
    main()
    sys.exit(0)
