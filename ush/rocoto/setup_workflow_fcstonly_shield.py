#!/usr/bin/env python

'''
    PROGRAM:
        Create the ROCOTO workflow for a forecast only experiment

    AUTHOR:
        Rahul.Mahajan
        rahul.mahajan@noaa.gov
        Modified for SHiELD
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
from datetime import datetime
from argparse import ArgumentParser, ArgumentDefaultsHelpFormatter
from datetime import datetime, timedelta
import rocoto
import workflow_utils as wfu

taskplan = ['getic', 'init', 'fcst', 'getic4omg', 'prep', 'gomg', 'analinc', 'archomg', 'analdiag', 'post', 'vrfy', 'metp', 'arch']

def main():
    parser = ArgumentParser(description='Setup XML workflow and CRONTAB for a forecast only experiment.', formatter_class=ArgumentDefaultsHelpFormatter)
    parser.add_argument('--expdir',help='full path to experiment directory containing config files', type=str, required=False, default=os.environ['PWD'])
    parser.add_argument('--cdump',help='cycle to run forecasts', type=str, choices=['gdas', 'gfs'], default='gfs', required=False)


    args = parser.parse_args()

    configs = wfu.get_configs(args.expdir)

    _base = wfu.config_parser([wfu.find_config('config.base', configs)])

    if not os.path.samefile(args.expdir,_base['EXPDIR']):
        print 'MISMATCH in experiment directories!'
        print 'config.base: EXPDIR = %s' % repr(_base['EXPDIR'])
        print 'input arg:     --expdir = %s' % repr(args.expdir)
        sys.exit(1)

    dict_configs = wfu.source_configs(configs, taskplan)

    dict_configs['base']['CDUMP'] = args.cdump

    if dict_configs['base']['DO_OmF'].upper() in ['Y', 'YES']:
        dict_configs['base'] = get_gomg_cyc_dates(dict_configs['base'])

    # First create workflow XML
    create_xml(dict_configs)

    # Next create the crontab
    wfu.create_crontab(dict_configs['base'])

    return


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
    strings.append('\t\tMain workflow manager for Forecast only Global Forecast System\n')
    strings.append('\n')
    strings.append('\tAUTHOR:\n')
    strings.append('\t\tMingjing Tong\n')
    strings.append('\t\tmingjing.tong@noaa.gov\n')
    strings.append('\n')
    strings.append('\tNOTES:\n')
    strings.append('\t\tThis workflow was automatically generated at %s\n' % datetime.now())
    strings.append('\t-->\n')

    return ''.join(strings)


def get_definitions(base):
    '''
        Create entities related to the experiment
    '''

    machine = base.get('machine', wfu.detectMachine())
    scheduler = wfu.get_scheduler(machine)
    hpssarch = base.get('HPSSARCH', 'NO').upper()

    strings = []

    strings.append('\n')
    strings.append('\t<!-- Experiment parameters such as name, cycle, resolution -->\n')
    strings.append('\t<!ENTITY PSLOT    "%s">\n' % base['PSLOT'])
    strings.append('\t<!ENTITY CDUMP    "%s">\n' % base['CDUMP'])
    strings.append('\t<!ENTITY CASE     "%s">\n' % base['CASE'])
    strings.append('\n')
    strings.append('\t<!-- Experiment parameters such as starting, ending dates -->\n')
    strings.append('\t<!ENTITY SDATE    "%s">\n' % base['SDATE'].strftime('%Y%m%d%H%M'))
    strings.append('\t<!ENTITY EDATE    "%s">\n' % base['EDATE'].strftime('%Y%m%d%H%M'))
    if base['INTERVAL'] is None:
        print 'cycle INTERVAL cannot be None'
        sys.exit(1)
    strings.append('\t<!ENTITY INTERVAL "%s">\n' % base['INTERVAL'])
    strings.append('\n')
    if base.get('DO_OmF', 'NO').upper() in ['Y', 'YES']:
        strings.append(get_gomg_dates(base))
        strings.append('\n')
    strings.append('\n')
    strings.append('\t<!-- Run Envrionment -->\n')
    strings.append('\t<!ENTITY RUN_ENVIR "%s">\n' % base['RUN_ENVIR'])
    strings.append('\n')
    strings.append('\t<!-- Experiment related directories -->\n')
    strings.append('\t<!ENTITY EXPDIR "%s">\n' % base['EXPDIR'])
    strings.append('\t<!ENTITY ROTDIR "%s">\n' % base['ROTDIR'])
    strings.append('\t<!ENTITY ICSDIR "%s">\n' % base['ICSDIR'])
    strings.append('\n')
    strings.append('\t<!-- Directories for driving the workflow -->\n')
    strings.append('\t<!ENTITY HOMEgfs  "%s">\n' % base['HOMEgfs'])
    strings.append('\t<!ENTITY JOBS_DIR "%s">\n' % base['BASE_JOB'])
    strings.append('\n')
    strings.append('\t<!-- Machine related entities -->\n')
    strings.append('\t<!ENTITY ACCOUNT    "%s">\n' % base['ACCOUNT'])
    strings.append('\t<!ENTITY QUEUE      "%s">\n' % base['QUEUE'])
    strings.append('\t<!ENTITY QUEUE_SERVICE "%s">\n' % base['QUEUE_SERVICE'])
    if scheduler in ['slurm'] and machine in ['ORION']:
       strings.append('\t<!ENTITY PARTITION_BATCH "%s">\n' % base['PARTITION_BATCH'])
    if scheduler in ['slurm']:
       strings.append('\t<!ENTITY PARTITION_SERVICE "%s">\n' % base['QUEUE_SERVICE'])
    strings.append('\t<!ENTITY SCHEDULER  "%s">\n' % scheduler)
    strings.append('\n')
    strings.append('\t<!-- Toggle HPSS archiving -->\n')
    strings.append('\t<!ENTITY ARCHIVE_TO_HPSS "%s">\n' % base['HPSSARCH'])
    strings.append('\n')
    strings.append('\t<!-- ROCOTO parameters that control workflow -->\n')
    strings.append('\t<!ENTITY CYCLETHROTTLE "8">\n')
    strings.append('\t<!ENTITY TASKTHROTTLE  "25">\n')
    strings.append('\t<!ENTITY MAXTRIES      "2">\n')
    strings.append('\n')

    return ''.join(strings)


def get_resources(dict_configs, cdump='gdas'):
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

    for task in taskplan:

        cfg = dict_configs[task]
        print 'task ', task
        wtimestr, resstr, queuestr, memstr, natstr = wfu.get_resources(machine, cfg, task, reservation, cdump='gfs')

        taskstr = '%s_%s' % (task.upper(), cdump.upper())

        strings.append('\t<!ENTITY QUEUE_%s     "%s">\n' % (taskstr, queuestr))
        if scheduler in ['slurm'] and machine in ['ORION'] and task not in ['getic', 'getic4omg', 'archomg', 'arch']:
            strings.append('\t<!ENTITY PARTITION_%s "&PARTITION_BATCH;">\n' % taskstr )
        if scheduler in ['slurm'] and task in ['getic', 'getic4omg', 'archomg', 'arch']:
            strings.append('\t<!ENTITY PARTITION_%s "&PARTITION_SERVICE;">\n' % taskstr )
        strings.append('\t<!ENTITY WALLTIME_%s  "%s">\n' % (taskstr, wtimestr))
        strings.append('\t<!ENTITY RESOURCES_%s "%s">\n' % (taskstr, resstr))
        if len(memstr) != 0:
            strings.append('\t<!ENTITY MEMORY_%s    "%s">\n' % (taskstr, memstr))
        strings.append('\t<!ENTITY NATIVE_%s    "%s">\n' % (taskstr, natstr))

        strings.append('\n')

    strings.append('\t<!-- END: Resource requirements for the workflow -->\n')

    return ''.join(strings)

def get_gomg_cyc_dates(base):
    '''
        Generate SHiELD forecast dates from experiment dates
    '''

    base_out = base.copy()

    sdate = base['SDATE']
    edate = base['EDATE']

    sdate_gomg = sdate + timedelta(hours=6)
    edate_gomg = edate + timedelta(hours=6)

    base_out['SDATE_GOMG'] = sdate_gomg
    base_out['EDATE_GOMG'] = edate_gomg

    return base_out

def get_gomg_dates(base):
    '''
        Generate GSI OmF entities
    '''

    strings = []

    strings.append('\n')
    strings.append('\t<!-- Starting and ending dates for GOMG cycle -->\n')
    strings.append('\t<!ENTITY SDATE_GOMG    "%s">\n' % base['SDATE_GOMG'].strftime('%Y%m%d%H%M'))
    strings.append('\t<!ENTITY EDATE_GOMG    "%s">\n' % base['EDATE_GOMG'].strftime('%Y%m%d%H%M'))
    strings.append('\t<!ENTITY INTERVAL_GOMG "%s">\n' % base['INTERVAL'])

    return ''.join(strings)

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
        fhrs = fhrs_hf + range(fhrs_hf[-1]+fhout, fhmax+fhout, fhout)

    npostgrp = post['NPOSTGRP']
    ngrps = npostgrp if len(fhrs) > npostgrp else len(fhrs)

    fhrs = ['f%03d' % f for f in fhrs]
    fhrs = np.array_split(fhrs, ngrps)
    fhrs = [f.tolist() for f in fhrs]

    fhrgrp = ' '.join(['%03d' % x for x in range(1, ngrps+1)])
    fhrdep = ' '.join([f[-1] for f in fhrs])
    fhrlst = ' '.join(['_'.join(f) for f in fhrs])

    return fhrgrp, fhrdep, fhrlst


def get_workflow(dict_configs, cdump='gdas'):
    '''
        Create tasks for forecast only workflow
    '''

    envars = []
    envars.append(rocoto.create_envar(name='RUN_ENVIR', value='&RUN_ENVIR;'))
    envars.append(rocoto.create_envar(name='HOMEgfs', value='&HOMEgfs;'))
    envars.append(rocoto.create_envar(name='EXPDIR', value='&EXPDIR;'))
    envars.append(rocoto.create_envar(name='CDATE', value='<cyclestr>@Y@m@d@H</cyclestr>'))
    envars.append(rocoto.create_envar(name='CDUMP', value='&CDUMP;'))
    envars.append(rocoto.create_envar(name='PDY', value='<cyclestr>@Y@m@d</cyclestr>'))
    envars.append(rocoto.create_envar(name='cyc', value='<cyclestr>@H</cyclestr>'))

    base = dict_configs['base']
    do_gempak = base.get('DO_GEMPAK', 'NO').upper()
    do_awips = base.get('DO_AWIPS', 'NO').upper()
    do_wafs = base.get('WAFSF', 'NO').upper()
    do_metp = base.get('DO_METP', 'NO').upper()
    warm_start = base.get('EXP_WARM_START', ".false.")
    do_gomg = base.get('DO_OmF', 'NO').upper()
    do_analinc = base.get('do_analinc', 'NO').upper()
    do_post = base.get('DO_POST', 'YES').upper()
    hpssarch = base.get('HPSSARCH', 'YES').upper()
    icdump = base.get('ICDUMP', 'gdas')

    tasks = []

    print 'warm_start ', warm_start
    # getic
    if hpssarch in ['YES']:
        deps = []
        data = '&ROTDIR;/&CDUMP;.@Y@m@d/@H/atmos/INPUT/sfc_data.tile6.nc'
        dep_dict = {'type':'data', 'data':data}
        deps.append(rocoto.add_dependency(dep_dict))
        data = '&ROTDIR;/&CDUMP;.@Y@m@d/@H/atmos/RESTART/@Y@m@d.@H0000.sfcanl_data.tile6.nc'
        dep_dict = {'type':'data', 'data':data}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep_condition='nor', dep=deps)

        task = wfu.create_wf_task('getic', cdump=cdump, envar=envars, dependency=dependencies)
        tasks.append(task)
        tasks.append('\n')

    if do_analinc in ['Y', 'YES']:
        deps = []
        dep_dict = {'type': 'task', 'name': '%sfcst' % cdump, 'offset': '-06:00:00'}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep=deps)

        task = wfu.create_wf_task('getic4omg', cdump=cdump, envar=envars, dependency=dependencies,
                                  cycledef='gomg')
        tasks.append(task)
        tasks.append('\n')

    # init
    if warm_start == ".false.":
        deps = []
        data = '&ICSDIR;/%s.@Y@m@d/@H/%s.t@Hz.sanl'%(icdump, icdump)
        dep_dict = {'type':'data', 'data':data}
        deps.append(rocoto.add_dependency(dep_dict))
        data = '&ICSDIR;/%s.@Y@m@d/@H/%s.t@Hz.atmanl.nemsio'%(icdump, icdump)
        dep_dict = {'type':'data', 'data':data}
        deps.append(rocoto.add_dependency(dep_dict))
        data = '&ICSDIR;/%s.@Y@m@d/@H/%s.t@Hz.atmanl.nc'%(icdump, icdump)
        dep_dict = {'type':'data', 'data':data}
        deps.append(rocoto.add_dependency(dep_dict))
        data = '&ICSDIR;/%s.@Y@m@d/@H/atmos/%s.t@Hz.atmanl.nc'%(icdump, icdump)
        dep_dict = {'type':'data', 'data':data}
        deps.append(rocoto.add_dependency(dep_dict))
        data = '&ICSDIR;/%s.@Y@m@d/@H/atmos/RESTART/@Y@m@d.@H0000.sfcanl_data.tile6.nc'%(icdump)
        dep_dict = {'type':'data', 'data':data}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep_condition='or', dep=deps)

        if hpssarch in ['YES']:
          deps = []
          dep_dict = {'type': 'task', 'name': '%sgetic' % cdump}
          deps.append(rocoto.add_dependency(dep_dict))
          dependencies2 = rocoto.create_dependency(dep=deps)
    
        deps = []
        deps.append(dependencies)
        if hpssarch in ['YES']:
          deps.append(dependencies2)
          dependencies = rocoto.create_dependency(dep_condition='and', dep=deps)
    
        task = wfu.create_wf_task('init', cdump=cdump, envar=envars, dependency=dependencies)
        tasks.append(task)
        tasks.append('\n')
    
    # fcst
    if warm_start == ".false.":
        deps = []
        data = '&ROTDIR;/&CDUMP;.@Y@m@d/@H/atmos/INPUT/sfc_data.tile6.nc'
        dep_dict = {'type':'data', 'data':data}
        deps.append(rocoto.add_dependency(dep_dict))
        data = '&ROTDIR;/&CDUMP;.@Y@m@d/@H/atmos/RESTART/@Y@m@d.@H0000.sfcanl_data.tile6.nc'
        dep_dict = {'type':'data', 'data':data}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep_condition='or', dep=deps)
    else:
        deps = []
        dep_dict = {'type': 'task', 'name': '%sgetic' % cdump} 
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep=deps)

    task = wfu.create_wf_task('fcst', cdump=cdump, envar=envars, dependency=dependencies)
    tasks.append(task)
    tasks.append('\n')

    # prep
    if do_gomg in ['Y', 'YES']:
        deps = []
        dep_dict = {'type': 'task', 'name': '%sfcst' % cdump, 'offset': '-06:00:00'}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep=deps)

        task = wfu.create_wf_task('prep', cdump=cdump, envar=envars, dependency=dependencies,
                                  cycledef='gomg')
        tasks.append(task)
        tasks.append('\n')

    if do_analinc in ['Y', 'YES']:
        deps = []
        data = '&ICSDIR;/%s.@Y@m@d/@H/atmos/%s.t@Hz.atmanl.nc'%(icdump, icdump)
        dep_dict = {'type':'data', 'data':data}
        deps.append(rocoto.add_dependency(dep_dict))

        data = '&ROTDIR;/%s.@Y@m@d/@H/atmos/%s.t@Hz.logf009.txt' % (cdump, cdump)
        dep_dict = {'type': 'data', 'data': data, 'age': 30, 'offset': '-06:00:00'}
        deps.append(rocoto.add_dependency(dep_dict))

        dep_dict = {'type': 'task', 'name': '%sfcst' % cdump, 'offset': '-06:00:00'}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep_condition='and', dep=deps)

        task = wfu.create_wf_task('analinc', cdump=cdump, envar=envars, dependency=dependencies,
                                  cycledef='gomg')
        tasks.append(task)
        tasks.append('\n')

    # gomg
    if do_gomg in ['Y', 'YES']:
        deps = []
        dep_dict = {'type': 'task', 'name': '%sprep' % cdump}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep=deps)
        task = wfu.create_wf_task('gomg', cdump=cdump, envar=envars, dependency=dependencies,
                                  cycledef='gomg')
        tasks.append(task)
        tasks.append('\n')

        # analdiag
        deps = []
        dep_dict = {'type': 'task', 'name': '%sgomg' % cdump}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep=deps)
        task = wfu.create_wf_task('analdiag', cdump=cdump, envar=envars, dependency=dependencies,
                                  cycledef='gomg')
        tasks.append(task)
        tasks.append('\n')

        # archomg
        deps = []
        dep_dict = {'type': 'task', 'name': '%sanaldiag' % cdump}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep=deps)
        task = wfu.create_wf_task('archomg', cdump=cdump, envar=envars, dependency=dependencies,
                                  cycledef='gomg')
        tasks.append(task)
        tasks.append('\n')

    # post
    if do_post in ['Y', 'YES']:
        deps = []
        data = '&ROTDIR;/%s.@Y@m@d/@H/atmos/%s.t@Hz.log#dep#.txt' % (cdump, cdump)
        dep_dict = {'type': 'data', 'data': data}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep=deps)
        fhrgrp = rocoto.create_envar(name='FHRGRP', value='#grp#')
        fhrlst = rocoto.create_envar(name='FHRLST', value='#lst#')
        ROTDIR = rocoto.create_envar(name='ROTDIR', value='&ROTDIR;')
        postenvars = envars + [fhrgrp] + [fhrlst] + [ROTDIR]
        varname1, varname2, varname3 = 'grp', 'dep', 'lst'
        varval1, varval2, varval3 = get_postgroups(dict_configs['post'], cdump=cdump)
        vardict = {varname2: varval2, varname3: varval3}
        task = wfu.create_wf_task('post', cdump=cdump, envar=postenvars, dependency=dependencies,
                                  metatask='post', varname=varname1, varval=varval1, vardict=vardict)
        tasks.append(task)
        tasks.append('\n')

    # vrfy
    if do_metp in ['Y', 'YES'] and do_post in ['Y', 'YES']:
        deps = []
        dep_dict = {'type':'metatask', 'name':'%spost' % cdump}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep=deps)
        task = wfu.create_wf_task('vrfy', cdump=cdump, envar=envars, dependency=dependencies)
        tasks.append(task)
        tasks.append('\n')
    
    # metp
    if do_metp in ['Y', 'YES'] and do_post in ['Y', 'YES']:
        deps = []
        dep_dict = {'type':'metatask', 'name':'%spost' % cdump}
        deps.append(rocoto.add_dependency(dep_dict))
        dep_dict = {'type':'task', 'name':'%sarch' % cdump, 'offset':'-&INTERVAL;'}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep_condition='and', dep=deps)
        metpcase = rocoto.create_envar(name='METPCASE', value='#metpcase#')
        metpenvars = envars + [metpcase]
        varname1 = 'metpcase'
        varval1 = 'g2g1 g2o1 pcp1'
        task = wfu.create_wf_task('metp', cdump=cdump, envar=metpenvars, dependency=dependencies,
                                  metatask='metp', varname=varname1, varval=varval1)
        tasks.append(task)
        tasks.append('\n')

    # arch
    if do_post in ['Y', 'YES']:
        deps = []
        dep_dict = {'type':'metatask', 'name':'%spost' % cdump}
        deps.append(rocoto.add_dependency(dep_dict))
        if do_metp in ['Y', 'YES']:
            dep_dict = {'type':'task', 'name':'%svrfy' % cdump}
            deps.append(rocoto.add_dependency(dep_dict))
        dep_dict = {'type':'streq', 'left':'&ARCHIVE_TO_HPSS;', 'right':'YES'}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep_condition='and', dep=deps)
    else:
        deps = []
        dep_dict = {'type':'task', 'name':'%sfcst' % cdump}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep=deps)

    task = wfu.create_wf_task('arch', cdump=cdump, envar=envars, dependency=dependencies,
                              cycledef=cdump)
    tasks.append(task)
    tasks.append('\n')

    return ''.join(tasks)


def get_workflow_body(dict_configs, cdump='gdas'):
    '''
        Create the workflow body
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
    strings.append('\t<cycledef group="%s"  >&SDATE; &EDATE; &INTERVAL;</cycledef>\n' % cdump)
    if dict_configs['base']['DO_OmF'].upper() in ['Y', 'YES']:
        strings.append('\t<cycledef group="gomg"  >&SDATE_GOMG; &EDATE_GOMG; &INTERVAL;</cycledef>\n')
    strings.append('\n')
    strings.append(get_workflow(dict_configs, cdump=cdump))
    strings.append('\n')
    strings.append('</workflow>\n')

    return ''.join(strings)


def create_xml(dict_configs):
    '''
        Given an experiment directory containing config files and
        XML directory containing XML templates, create the workflow XML
    '''

    gfs_cyc=dict_configs['base']['gfs_cyc']
    interval_days=dict_configs['base']['interval_days']
    if interval_days > 0:
        dict_configs['base']['INTERVAL'] = '%s:00:00:00'%(interval_days)
    else:
        dict_configs['base']['INTERVAL'] = '%s:00:00'%(24/gfs_cyc)
    base = dict_configs['base']

    preamble = get_preamble()
    definitions = get_definitions(base)
    resources = get_resources(dict_configs, cdump=base['CDUMP'])
    workflow = get_workflow_body(dict_configs, cdump=base['CDUMP'])

    # Removes <memory>&MEMORY_JOB_DUMP</memory> post mortem from gdas tasks
    temp_workflow = ''
    memory_dict = []
    for each_resource_string in re.split(r'(\s+)', resources):
        if 'MEMORY' in each_resource_string:
            memory_dict.append(each_resource_string)
    for each_line in re.split(r'(\s+)', workflow):
        if 'MEMORY' not in each_line:
            temp_workflow += each_line
        else:
            if any( substring in each_line for substring in memory_dict):
                temp_workflow += each_line
    workflow = temp_workflow

    # Start writing the XML file
    fh = open('%s/%s.xml' % (base['EXPDIR'], base['PSLOT']), 'w')

    fh.write(preamble)
    fh.write(definitions)
    fh.write(resources)
    fh.write(workflow)

    fh.close()

    return

if __name__ == '__main__':
    main()
    sys.exit(0)
