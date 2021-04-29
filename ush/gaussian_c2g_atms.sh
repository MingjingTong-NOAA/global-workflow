#!/bin/ksh
################################################################################
####  UNIX Script Documentation Block
#                      .                                             .
# Script name:         gaussian_atmsfcst.sh
# Script description:  Makes a global gaussian grid atmospheric forecast files
#
# Author:        Mingjing Tong       Org: NP23         Date: 2020-01-30
#
# Abstract: This script makes a global gaussian grid atmospheric forecast from
#           fv3gfs forecast tiles
#
# Script history log:
# 2019-12-26  Tong  initial script
#
# Usage:  gaussian_c2g_atms.sh
#
#   Imported Shell Variables:
#     CASE          Model resolution.  Defaults to C768.
#     BASEDIR       Root directory where all scripts and fixed files reside.
#                   Default is /nwprod2.
#     HOMEgfs       Directory for gfs version.  Default is
#                   $BASEDIR/gfs_ver.v15.0.0}
#     FIXam         Directory for the global fixed climatology files.
#                   Defaults to $HOMEgfs/fix/fix_am
#     FIXfv3        Directory for the model grid and orography netcdf
#                   files.  Defaults to $HOMEgfs/fix/fix_fv3_gmted2010
#     FIXWGTS       Weight file to use for interpolation
#     EXECgfs       Directory of the program executable.  Defaults to
#                   $HOMEgfs/exec
#     DATA          Working directory
#                   (if nonexistent will be made, used and deleted)
#                   Defaults to current working directory
#     COMOUT        Output directory
#                   (if nonexistent will be made)
#                   defaults to current working directory
#     XC            Suffix to add to executables. Defaults to none.
#     GAUATMSEXE    Program executable.
#                   Defaults to $EXECgfs/gaussian_atms.exe
#     INISCRIPT     Preprocessing script.  Defaults to none.
#     LOGSCRIPT     Log posting script.  Defaults to none.
#     ERRSCRIPT     Error processing script
#                   defaults to 'eval [[ $err = 0 ]]'
#     ENDSCRIPT     Postprocessing script
#                   defaults to none
#     CDATE         Output forecast date in yyyymmddhh format. Required.
#     PGMOUT        Executable standard output
#                   defaults to $pgmout, then to '&1'
#     PGMERR        Executable standard error
#                   defaults to $pgmerr, then to '&1'
#     pgmout        Executable standard output default
#     pgmerr        Executable standard error default
#     REDOUT        standard output redirect ('1>' or '1>>')
#                   defaults to '1>', or to '1>>' to append if $PGMOUT is a file
#     REDERR        standard error redirect ('2>' or '2>>')
#                   defaults to '2>', or to '2>>' to append if $PGMERR is a file
#     VERBOSE       Verbose flag (YES or NO)
#                   defaults to NO
#     gfs_ver       Version number of gfs directory.  Default is
#                   v15.0.0.
#     OMP_NUM_
#     THREADS_SFC   Number of omp threads to use.  Default is 1.
#     APRUNSFC      Machine specific command to invoke the executable.
#                   Default is none.
#
#   Exported Shell Variables:
#     PGM           Current program name
#     pgm
#     ERR           Last return code
#     err
#
#   Modules and files referenced:
#     scripts    : $INISCRIPT
#                  $LOGSCRIPT
#                  $ERRSCRIPT
#                  $ENDSCRIPT
#
#     programs   : $GAUATMSEXE
#
#     fixed data : $FIXfv3/${CASE}/${CASE}_oro_data.tile*.nc
#                  $FIXWGTS
#                  $FIXam/global_hyblev.l65.txt
#
#     input data : $COMOUT/RESTART/${PDY}.${cyc}0000.fv_core.res.tile*.nc
#                  $COMOUT/RESTART/${PDY}.${cyc}0000.fv_tracer.res.tile*.nc
#                  $COMOUT/RESTART/${PDY}.${cyc}0000.phy_data.res.tile*.nc
#
#     output data: $PGMOUT
#                  $PGMERR
#                  $COMOUT/${APREFIX}atmf${ASUFFIX}
#
# Remarks:
#
#   Condition codes
#      0 - no problem encountered
#     >0 - some problem encountered
#
#  Control variable resolution priority
#    1 Command line argument.
#    2 Environment variable.
#    3 Inline default.
#
# Attributes:
#   Language: POSIX shell
#   Machine: IBM SP
#
################################################################################

# Source FV3GFS workflow modules
. $HOMEgfs/ush/load_fv3gfs_modules.sh
status=$?
[[ $status -ne 0 ]] && exit $status

#  Set environment.
VERBOSE=${VERBOSE:-"NO"}
if [[ "$VERBOSE" = "YES" ]] ; then
   echo $(date) EXECUTING $0 $* >&2
   set -x
   exec >> $DATA/logf$( printf "%03d" $fhour) 2>&1
fi

CASE=${CASE:-C768}
res=$(echo $CASE | cut -c2-)

#  Directories.
gfs_ver=${gfs_ver:-v15.0.0}
BASEDIR=${BASEDIR:-${NWROOT:-/nwprod2}}
HOMEgfs=${HOMEgfs:-$BASEDIR/gfs_ver.${gfs_ver}}
EXECgfs=${EXECgfs:-$HOMEgfs/exec}
FIXfv3=${FIXfv3:-$HOMEgfs/fix/fix_fv3_gmted2010}
FIXam=${FIXam:-$HOMEgfs/fix/fix_am}
FIXC2G=${FIXC2G:-$HOMEgfs/fix/fix_shield/gaus_N${res}.nc}
DATA=${DATA:-$(pwd)}

#  Filenames.
XC=${XC}
GAUATMSEXE=${GAUATMSEXE:-$EXECgfs/gaussian_c2g_atms.x}

CDATE=${CDATE:?}

#  Other variables.
export NLN=${NLN:-"/bin/ln -sf"}
export PGMOUT=${PGMOUT:-${pgmout:-'&1'}}
export PGMERR=${PGMERR:-${pgmerr:-'&2'}}
export REDOUT=${REDOUT:-'1>'}
export REDERR=${REDERR:-'2>'}

# Set defaults
################################################################################
#  Preprocessing
$INISCRIPT
pwd=$(pwd)
if [[ -d $DATA ]]
then
   mkdata=NO
else
   mkdir -p $DATA
   mkdata=YES
fi
cd $DATA||exit 99
mkdir -p gaussian_atmsf$( printf "%03d" $RHR)
cd gaussian_atmsf$( printf "%03d" $RHR)

################################################################################
#  Make forecast file on gaussian grid
export PGM=$GAUATMSEXE
export pgm=$PGM
$LOGSCRIPT

$NCP $GAUATMSEXE ./

export OMP_NUM_THREADS=${OMP_NUM_THREADS_ATMS:-40}

RSTR=${RSTR:-"3"}
RINTV=${RINTV:-"1"}
REND=${REND:-"9"}

yyyy=$(echo $CDATE | cut -c1-4)
mm=$(echo $CDATE | cut -c5-6)
dd=$(echo $CDATE | cut -c7-8)
hh=$(echo $CDATE | cut -c9-10)

if [ $OUTPUT_FILE = "netcdf" ]; then
   nemsio=".false."
else
   nemsio=".true."
fi

# Executable namelist
cat > fv3_da.nml <<EOF
   &fv3_da_nml
    finer_steps = 0,
    nvar3dout = 14,
    write_res = .true.,
    read_res = .true.,
    write_nemsio = $nemsio,
    rmhydro = ${rmhydro},
    pseudo_ps = ${pseudo_ps},
    data_file(1) = "fv_tracer.res",
    data_file(2) = "fv_core.res",
    data_file(3) = "${phy_data}",
    data_out = "atmf$( printf "%03d" $fhour)${ASUFFIX}",
    gaus_file = "gaus_N${res}",
    atmos_nthreads = $OMP_NUM_THREADS,
    yy=$yyyy,
    mm=$mm,
    dd=$dd,
    hh=$hh,
    fhr=$fhour,
    ideflate=1,
    nbits=14,

/
EOF

# input interpolation weights
$NLN $FIXC2G ./gaus_N${res}.nc

$NLN $DATA/grid_spec.tile1.nc ./grid_spec.tile1.nc
$NLN $DATA/grid_spec.tile2.nc ./grid_spec.tile2.nc
$NLN $DATA/grid_spec.tile3.nc ./grid_spec.tile3.nc
$NLN $DATA/grid_spec.tile4.nc ./grid_spec.tile4.nc
$NLN $DATA/grid_spec.tile5.nc ./grid_spec.tile5.nc
$NLN $DATA/grid_spec.tile6.nc ./grid_spec.tile6.nc
$NLN $DATA/control.dat ./control.dat

rPDY=$(echo $RDATE | cut -c1-8)
rcyc=$(echo $RDATE | cut -c9-10)
if [[ $RHR -ne $REND ]] ; then
   list1=`ls -C1 $DATA/RESTART/${rPDY}.${rcyc}0*.fv_core.res.*`
   list2=`ls -C1 $DATA/RESTART/${rPDY}.${rcyc}0*.fv_tracer.res.*`
   list3=`ls -C1 $DATA/RESTART/${rPDY}.${rcyc}0*.phy_data.*`
   list4=`ls -C1 $DATA/RESTART/${rPDY}.${rcyc}0*.coupler.res`	
else
   list1=`ls -C1 $DATA/RESTART/fv_core.res.*`
   list2=`ls -C1 $DATA/RESTART/fv_tracer.res.*`
   list3=`ls -C1 $DATA/RESTART/phy_data.*`
   list4=`ls -C1 $DATA/RESTART/coupler.res`
fi
for list in $list1 $list2 $list3; do
    for file in $list; do
       if [[ $RHR -ne $REND ]] ; then
          $NLN $file ./${file#$DATA/RESTART/${rPDY}.${rcyc}0*.}
       else
          $NLN $file ./${file#$DATA/RESTART/}
       fi
    done
done  
   
# output gaussian global forecast files
$NLN $memdir/${APREFIX}atmf$( printf "%03d" $fhour)${ASUFFIX} ./atmf$( printf "%03d" $fhour)${ASUFFIX}

eval $GAUATMSEXE >> $DATA/logf$( printf "%03d" $fhour)
export ERR=$?
export err=$ERR
$ERRSCRIPT||exit 2

################################################################################
#  Postprocessing
cd $pwd
[[ $mkdata = YES ]]&&rmdir $DATA
$ENDSCRIPT
set +x
if [[ "$VERBOSE" = "YES" ]]
then
   echo $(date) EXITING $0 with return code $err >&2
fi
exit $err
