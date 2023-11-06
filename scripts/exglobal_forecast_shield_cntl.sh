#! /usr/bin/env bash

################################################################################

source "$HOMEgfs/ush/preamble.sh"

SCRIPTDIR=$(dirname $(readlink -f "$0") )/../ush

# include all subroutines. Executions later.
source $SCRIPTDIR/parsing_namelists_shield_cntl.sh

machine=${machine:-"WCOSS_C"}
machine=$(echo $machine | tr '[a-z]' '[A-Z]')

# Cycling and forecast hour specific parameters 
CDUMPwave="${CDUMP}wave"
CASE=${CASE:-C768}
CDATE=${CDATE:-2017032500}
CDUMP=${CDUMP:-gdas}
FHMIN=${FHMIN:-0}
FHMAX=${FHMAX:-9}
FHOUT=${FHOUT:-1}
FHOUT_aux=${FHOUT_aux:-0}
FHDUR_aux=${FHDUR_aux:-0}
FHZER=${FHZER:-6}
FHCYC=${FHCYC:-24}
FHMAX_HF=${FHMAX_HF:-0}
FHOUT_HF=${FHOUT_HF:-1}
NSOUT=${NSOUT:-"-1"}
FDIAG=$FHOUT
first_time_step=${first_time_step:-".false."}
if [ $FHMAX_HF -gt 0 -a $FHOUT_HF -gt 0 ]; then FDIAG=$FHOUT_HF; fi
WRITE_DOPOST=${WRITE_DOPOST:-".false."}
restart_interval=${restart_interval:-0}
rst_invt1=`echo $restart_interval |cut -d " " -f 1`
gfsanl=${gfsanl:-"YES"}

PDY=$(echo $CDATE | cut -c1-8)
cyc=$(echo $CDATE | cut -c9-10)

# Directories.
pwd=$(pwd)
NWPROD=${NWPROD:-${NWROOT:-$pwd}}
HOMEgfs=${HOMEgfs:-$NWPROD}
FIX_DIR=${FIX_DIR:-$HOMEgfs/fix}
FIX_AM=${FIX_AM:-$FIX_DIR/fix_am}
export FIX_AER=${FIX_AER:-$FIX_DIR/fix_aer}
export FIX_LUT=${FIX_LUT:-$FIX_DIR/fix_lut}
FIXfv3=${FIXfv3:-$FIX_DIR/fix_fv3_gmted2010}
FIX_SHiELD=${FIX_SHiELD:-$FIX_DIR/fix_shield}
DATA=${DATA:-$pwd/fv3tmp$$}    # temporary running directory
ROTDIR=${ROTDIR:-$pwd}         # rotating archive directory
ICSDIR=${ICSDIR:-$pwd}         # cold start initial conditions
ICSTYP=${ICSTYP:-"gfs"}        # Initial condition type (gfs, ifs)
ECICSDIR=${ECICSDIR:-"/scratch2/GFDL/gfdlscr/Mingjing.Tong/scrub/ECIFS_ICS"} 
DMPDIR=${DMPDIR:-$pwd}         # global dumps for seaice, snow and sst analysis

# Model resolution specific parameters
DELTIM=${DELTIM:-225}
layout_x=${layout_x:-8}
layout_y=${layout_y:-16}
LEVS=${LEVS:-91}

# Utilities
NCP=${NCP:-"/bin/cp -p"}
NLN=${NLN:-"/bin/ln -sf"}
NMV=${NMV:-"/bin/mv"}
SEND=${SEND:-"YES"}   #move final result to rotating directory
ERRSCRIPT=${ERRSCRIPT:-'eval [[ $err = 0 ]]'}
KEEPDATA=${KEEPDATA:-"NO"}

# Other options
MEMBER=${MEMBER:-"-1"} # -1: control, 0: ensemble mean, >0: ensemble member $MEMBER
ENS_NUM=${ENS_NUM:-1}  # Single executable runs multiple members (e.g. GEFS)
PREFIX_ATMINC=${PREFIX_ATMINC:-""} # allow ensemble to use recentered increment

# IAU options
DOIAU=${DOIAU:-"NO"}
IAUFHRS=${IAUFHRS:-0}
IAU_DELTHRS=${IAU_DELTHRS:-0}
IAU_OFFSET=${IAU_OFFSET:-0}
replay=${replay:-0}

# Model specific stuff
FCSTEXECDIR=${FCSTEXECDIR:-$HOMEgfs/exec}
FCSTEXEC=${FCSTEXEC:-shield.x}
PARM_FV3DIAG=${PARM_FV3DIAG:-$HOMEgfs/parm/parm_fv3diag}
PARM_POST=${PARM_POST:-$HOMEgfs/parm/post}

# Wave coupling parameter defaults to false
cplwav=${cplwav:-.false.}

# Model config options
APRUN_FV3=${APRUN_FV3:-${APRUN_FCST:-${APRUN:-""}}}
if [ $machine = "gaea" ] ; then
   NTHREADS_FV3=4
   hyperthread=".true."
else
   NTHREADS_FV3=${NTHREADS_FV3:-${NTHREADS_FCST:-${nth_fv3:-1}}}
fi
cores_per_node=${cores_per_node:-${npe_node_max:-24}}
ntiles=${ntiles:-6}
NTASKS_FV3=${NTASKS_FV3:-$npe_fv3}
NNODES=$((NTASKS_FV3/npe_node_fcst))

TYPE=${TYPE:-"nh"}                  # choices:  nh, hydro
MONO=${MONO:-"non-mono"}            # choices:  mono, non-mono

QUILTING=${QUILTING:-".false."}
OUTPUT_GRID=${OUTPUT_GRID:-"gaussian_grid"}
OUTPUT_FILE=${OUTPUT_FILE:-"nemsio"}
WRITE_NEMSIOFLIP=${WRITE_NEMSIOFLIP:-".true."}
WRITE_FSYNCFLAG=${WRITE_FSYNCFLAG:-".true."}
affix="nemsio"
[[ "$OUTPUT_FILE" = "netcdf" ]] && affix="nc"

rCDUMP=${rCDUMP:-$CDUMP}
[[ $MODE = "forecast-only" ]] && rCDUMP=$ICDUMP

# interpolate from cubesphere grid to gaussian grid
DO_CUBE2GAUS=${DO_CUBE2GAUS:-"YES"}
C2GSH=${C2GSH:-$HOMEgfs/ush/cube2gaussian.sh}
export GAUATMSEXE=${GAUATMSEXE:-$HOMEgfs/exec/gaussian_c2g_atms.x}
NTHREADS_GAUATMS=${NTHREADS_GAUATMS:-40}
GAUSFCFCSTSH=${GAUSFCFCSTSH:-$HOMEgfs/ush/gaussian_sfcfcst.sh}
export GAUSFCFCSTEXE=${GAUSFCFCSTEXE:-$HOMEgfs/exec/gaussian_sfcfcst.exe}
NTHREADS_GAUSFCFCST=${NTHREADS_GAUSFCFCST:-1}

APRUN_C2G=${APRUN_C2G:-${APRUN:-""}}
export APREFIX="${CDUMP}.t${cyc}z."
export ASUFFIX=${ASUFFIX:-$SUFFIX}

#------------------------------------------------------------------
# setup the runtime environment
if [ $machine = "WCOSS_C" ] ; then
  HUGEPAGES=${HUGEPAGES:-hugepages4M}
  . $MODULESHOME/init/sh 2>/dev/null
  module load iobuf craype-$HUGEPAGES 2>/dev/null
  export MPICH_GNI_COLL_OPT_OFF=${MPICH_GNI_COLL_OPT_OFF:-MPI_Alltoallv}
  export MKL_CBWR=AVX2
  export WRTIOBUF=${WRTIOBUF:-"4M"}
  export NC_BLKSZ=${NC_BLKSZ:-"4M"}
  export IOBUF_PARAMS="*nemsio:verbose:size=${WRTIOBUF},*:verbose:size=${NC_BLKSZ}"
fi

#-------------------------------------------------------
if [ ! -d $ROTDIR ]; then mkdir -p $ROTDIR; fi
mkdata=NO
if [ ! -d $DATA ]; then
   mkdata=YES
   mkdir -p $DATA
fi
cd $DATA || exit 8
mkdir -p $DATA/INPUT

if [ $cplwav = ".true." ]; then 
    if [ $CDUMP = "gdas" ]; then
      RSTDIR_WAVE=$ROTDIR/${CDUMP}.${PDY}/${cyc}/wave/restart
    else
      RSTDIR_WAVE=${RSTDIR_WAVE:-$ROTDIR/${CDUMP}.${PDY}/${cyc}/wave/restart}
    fi
    if [ ! -d $RSTDIR_WAVE ]; then mkdir -p $RSTDIR_WAVE ; fi
    $NLN $RSTDIR_WAVE restart_wave
fi

if [ $CDUMP = "gfs" -a $rst_invt1 -gt 0 ]; then
    RSTDIR_ATM=${RSTDIR:-$ROTDIR}/${CDUMP}.${PDY}/${cyc}/atmos/RERUN_RESTART
    if [ ! -d $RSTDIR_ATM ]; then mkdir -p $RSTDIR_ATM ; fi
    $NLN $RSTDIR_ATM RESTART
    filecount=$(find $RSTDIR_ATM -type f | wc -l)
else
    mkdir -p $DATA/RESTART
    filecount=0
fi

#-------------------------------------------------------
# determine if restart IC exists to continue from a previous forecast
RERUN="NO"
filecount=$(find $RSTDIR_ATM -type f | wc -l)
if [ $CDUMP = "gfs" -a $rst_invt1 -gt 0 -a $FHMAX -gt $rst_invt1 -a $filecount -gt 10 ]; then
    reverse=$(echo "${restart_interval[@]} " | tac -s ' ')
    for xfh in $reverse ; do
        yfh=$((xfh-(IAU_OFFSET/2)))
        SDATE=$($NDATE +$yfh $CDATE)
        PDYS=$(echo $SDATE | cut -c1-8)
        cycs=$(echo $SDATE | cut -c9-10)
        flag1=$RSTDIR_ATM/${PDYS}.${cycs}0000.coupler.res
        flag2=$RSTDIR_ATM/coupler.res
        if [ -s $flag1 ]; then
            CDATE_RST=$SDATE          
            [[ $RERUN = "YES" ]] && break
            mv $flag1 ${flag1}.old
            if [ -s $flag2 ]; then mv $flag2 ${flag2}.old ;fi
            RERUN="YES"
            [[ $xfh = $rst_invt1 ]] && RERUN="NO"
        fi 
    done
fi

#-------------------------------------------------------
# member directory
if [ $MEMBER -lt 0 ]; then
  prefix=$CDUMP
  rprefix=$rCDUMP
  memchar=""
else
  prefix=enkf$CDUMP
  rprefix=enkf$rCDUMP
  memchar=mem$(printf %03i $MEMBER)
fi
export memdir=$ROTDIR/${prefix}.$PDY/$cyc/atmos/$memchar
if [ ! -d $memdir ]; then mkdir -p $memdir; fi

GDATE=$($NDATE -$assim_freq $CDATE)
gPDY=$(echo $GDATE | cut -c1-8)
gcyc=$(echo $GDATE | cut -c9-10)
gmemdir=$ROTDIR/${rprefix}.$gPDY/$gcyc/atmos/$memchar
sCDATE=$($NDATE -3 $CDATE)

if [[ "$DOIAU" = "YES" ]]; then
  sCDATE=$($NDATE -3 $CDATE)
  sPDY=$(echo $sCDATE | cut -c1-8)
  scyc=$(echo $sCDATE | cut -c9-10)
  tPDY=$gPDY
  tcyc=$gcyc
else
  sCDATE=$CDATE
  sPDY=$PDY
  scyc=$cyc
  tPDY=$sPDY
  tcyc=$cyc
fi

if [ $replay -eq 1 ]; then
  if [ $nrestartbg -eq 1 ]; then
    rst_hrs="6"
  elif [ $nrestartbg -eq 3 ]; then
    rst_hrs="3 6 9"
  elif [ $nrestartbg -eq 7 ]; then
    rst_hrs="3 4 5 6 7 8 9"
  else
    echo "Unknown background number, ABORT!"
    exit 1
  fi
else
  rst_hrs="0"
fi

#-------------------------------------------------------
# initial conditions
warm_start=${warm_start:-".false."}
fcst_wo_da=${fcst_wo_da:-"NO"}
read_increment=${read_increment:-".false."}
res_latlon_dynamics='""'

# Determine if this is a warm start or cold start
if [ -f $gmemdir/RESTART/${sPDY}.${scyc}0000.coupler.res ]; then
  export warm_start=".true."
fi

# turn IAU and replay off for cold start
DOIAU_coldstart=${DOIAU_coldstart:-"NO"}
if [ $DOIAU = "YES" -a $warm_start = ".false." ] || [ $DOIAU_coldstart = "YES" -a $warm_start = ".true." ]; then
  export DOIAU="NO"
  echo "turning off IAU"
  DOIAU_coldstart="YES"
  IAU_OFFSET=0
  sCDATE=$CDATE
  sPDY=$PDY
  scyc=$cyc
  tPDY=$sPDY
  tcyc=$cyc
  replay=0
fi

if [[ $DOIAU = "YES" ]]; then
  FHMIN=$((IAU_DELTHRS/2+FHMIN))
  FHMAX=$((IAU_DELTHRS/2+FHMAX))
  iau_halfdelthrs=$((IAU_DELTHRS/2))
  if [ $FHOUT -ge 6 ]; then
    FDIAG=$((IAU_DELTHRS/2))
  fi
else
  iau_halfdelthrs=0
  if [[ $FHMIN -eq 0 ]]; then
    first_time_step=".true."
  fi
fi

restart_start_secs=$((FHMIN*3600))
restart_secs=$((FHOUT*3600))
if [[ "$CDUMP" = "gfs" && "$DO_CUBE2GAUS" = "NO" ]] ; then
   restart_start_secs=0
   restart_secs=0
fi
if [[ $FHOUT_aux > 0 ]]; then
   FHMIN_aux=$((FHMIN+3))
   FHMAX_aux=$((FHMIN_aux+FHDUR_aux))
   restart_secs_aux=$((FHOUT_aux*3600))
   restart_start_secs_aux=$((FHMIN_aux*3600))
   restart_duration_secs_aux=$((FHDUR_aux*3600))
else
   restart_secs_aux=0
   restart_start_secs_aux=0 
   restart_duration_secs_aux=0
fi
#-------------------------------------------------------
if [ $warm_start = ".true." -o $RERUN = "YES" ]; then
#-------------------------------------------------------
#.............................
  if [ $RERUN = "NO" ]; then
#.............................

  # Link all (except sfc_data) restart files from $gmemdir
    for file in $(ls $gmemdir/RESTART/${sPDY}.${scyc}0000.*.nc); do
      file2=$(echo $(basename -- $file))
      file2=$(echo $file2 | cut -d. -f3-) # remove the date from file
      fsuf=$(echo $file2 | cut -d. -f1)
      if [ $fsuf != "sfc_data" ]; then
         $NLN $file $DATA/INPUT/$file2
      fi
    done

  # Link sfcanl_data restart files from $memdir
    if [[ ($CDUMP = "gfs" && $gfsanl = "NO") || $MODE = "replay" ]]; then
      sfcanldir=$ROTDIR/gdas.$PDY/$cyc/atmos/$memchar
    else
      sfcanldir=$memdir
    fi
    for file in $(ls $sfcanldir/RESTART/${sPDY}.${scyc}0000.*.nc); do
      file2=$(echo $(basename -- $file))
      file2=$(echo $file2 | cut -d. -f3-) # remove the date from file
      fsufanl=$(echo $file2 | cut -d. -f1)
      if [ $fsufanl = "sfcanl_data" ]; then
        file2=$(echo $file2 | sed -e "s/sfcanl_data/sfc_data/g")
        # when NSST is off, use tref
        if [[ $DONST = "YES" || $DOGCYCLE = "YES" || ($MODE = "forecast-only" && $IAU_OFFSET -ne 0) ]]; then
           $NLN $file $DATA/INPUT/$file2
        else
           $NLN $file $DATA/INPUT/sfc_org
           ncrename -O -v tsea,tsea_org $DATA/INPUT/sfc_org out.nc
           ncrename -O -v tref,tsea out.nc $DATA/INPUT/$file2
        fi
      fi
    done

  # Need a coupler.res when doing IAU
    if [ $DOIAU = "YES" ]; then
      rm -f $DATA/INPUT/coupler.res
      cat >> $DATA/INPUT/coupler.res << EOF
     2        (Calendar: no_calendar=0, thirty_day_months=1, julian=2, gregorian=3, noleap=4)
  ${gPDY:0:4}  ${gPDY:4:2}  ${gPDY:6:2}  ${gcyc}     0     0        Model start time:   year, month, day, hour, minute, second
  ${sPDY:0:4}  ${sPDY:4:2}  ${sPDY:6:2}  ${scyc}     0     0        Current model time: year, month, day, hour, minute, second
EOF
    fi

  # Link increments
    if [ $replay -eq 1 ]; then 
      # compute increment inside model
      read_increment=".false."
      IAU_FORCING_VAR=${IAU_FORCING_VAR:-"'ua','va','temp','delp','delz','sphum','o3mr',"}
      IAU_INC_FILES="''"
    else
      if [[ ($CDUMP = "gfs" && $gfsanl = "NO") || $MODE = "replay" ]]; then
         INCDUMP="gdas"
         incmemdir=$ROTDIR/${INCDUMP}.$PDY/$cyc/atmos/$memchar
      else
         INCDUMP=$CDUMP
         incmemdir=$memdir
      fi
      if [ $DOIAU = "YES" ]; then
        for i in $(echo $IAUFHRS | sed "s/,/ /g" | rev); do
          incfhr=$(printf %03i $i)
          if [ $incfhr = "006" ]; then
            increment_file=$incmemdir/${INCDUMP}.t${cyc}z.${PREFIX_ATMINC}atminc.nc
          else
            increment_file=$incmemdir/${INCDUMP}.t${cyc}z.${PREFIX_ATMINC}atmi${incfhr}.nc
          fi
          if [ ! -f $increment_file ]; then
            echo "ERROR: DOIAU = $DOIAU, but missing increment file for fhr $incfhr at $increment_file"
            echo "Abort!"
            exit 1
          fi
          $NLN $increment_file $DATA/INPUT/fv_increment$i.nc
          IAU_INC_FILES="'fv_increment$i.nc',${IAU_INC_FILES:-}"
        done
        read_increment=".false."
        res_latlon_dynamics='""'
      else
        if [ $fcst_wo_da = "NO" ]; then 
          increment_file=$incmemdir/${INCDUMP}.t${cyc}z.${PREFIX_INC}atminc.nc
          if [ -f $increment_file ]; then
            $NLN $increment_file $DATA/INPUT/fv_increment.nc
            read_increment=".true."
            res_latlon_dynamics="fv_increment.nc"
          fi
        else
          read_increment=".false."
        fi
      fi
    fi
  
#.............................
  else  ##RERUN                         

    export warm_start=".true."
    PDYT=$(echo $CDATE_RST | cut -c1-8)
    cyct=$(echo $CDATE_RST | cut -c9-10)
    for file in $(ls $RSTDIR_ATM/${PDYT}.${cyct}0000.*); do
      file2=$(echo $(basename -- $file))
      file2=$(echo $file2 | cut -d. -f3-) 
      $NLN $file $DATA/INPUT/$file2
    done
   
    hour_rst=`$NHOUR $CDATE_RST $CDATE`
    IAU_FHROT=$((IAU_OFFSET+hour_rst))         
    if [ $DOIAU = "YES" ]; then
      IAUFHRS=-1         
      IAU_DELTHRS=0
      IAU_INC_FILES="''"
    fi

    rst_list_rerun=""
    xfh=$restart_interval_gfs
    if [ $xfh -gt 0 ]; then
       while [ $xfh -le $FHMAX_GFS ]; do
         rst_list_rerun="$rst_list_rerun $xfh"
         xfh=$((xfh+restart_interval_gfs))
       done
       restart_interval="$rst_list_rerun"
    fi

  fi
#.............................

else ## cold start                            

  if [ $MODE = "cycled" ]; then
    icsdir=$memdir
  else
    icsdir=${ICSDIR}/${ICDUMP}.${PDY}/${cyc}/atmos/${CASE}
  fi
  for file in $(ls $icsdir/INPUT/*.nc); do
    file2=$(echo $(basename -- $file))
    fsuf=$(echo $file2 | cut -c1-3)
    if [ $fsuf = "gfs" ]; then
      $NLN $file $DATA/INPUT/$file2
    fi
    if [[ $fsuf = "sfc" ]]; then
       if [[ $DONST = "YES" || ( $DOGCYCLE = "YES" && "$CDATE" != "$SDATE" ) ]]; then
          $NLN $file $DATA/INPUT/$file2
       else
          $NLN $file $DATA/INPUT/sfc_org
          ncrename -O -v tsea,tsea_org $DATA/INPUT/sfc_org out.nc
          ncrename -O -v tref,tsea out.nc $DATA/INPUT/$file2
       fi 
    fi
  done
  if [ $ICSTYP = "ifs" ]; then
    $NLN ${ECICSDIR}/IFS_AN0_${PDY}.${cyc}Z.nc $DATA/INPUT/gk03_CF0.nc
  fi

#-------------------------------------------------------
fi 

# link analysis and restart files for replay
if [ $replay -eq 1 ]; then
   mkdir -p $DATA/EXTIC
   mkdir -p $DATA/ATMINC
   mkdir -p $DATA/ATMANL
   # link external IC
   for file in $(ls $ROTDIR/${rprefix}.$PDY/$cyc/atmos/$memchar/INPUT/*.nc); do
     file2=$(echo $(basename -- $file))
     fsuf=$(echo $file2 | cut -c1-3)
     if [ $fsuf = "gfs" ]; then
       $NLN $file $DATA/EXTIC/$file2
     fi
   done
   if [ $ICSTYP = "ifs" ]; then
     $NLN ${ECICSDIR}/IFS_AN0_${PDY}.${cyc}Z.nc $DATA/EXTIC/gk03_CF0.nc
   fi

   # Link restart background files
   gCDATE=$($NDATE -6 $CDATE) 
   
   nbg=1
   for rst_int in $rst_hrs; do
     if [[ $rst_int -ge 0 ]]; then
       mkdir -p $DATA/INPUT${nbg}    
       RDATE=$($NDATE +$rst_int $gCDATE)
       rPDY=$(echo $RDATE | cut -c1-8)
       rcyc=$(echo $RDATE | cut -c9-10)
       if [[ -s $gmemdir/RESTART/${rPDY}.${rcyc}0000.coupler.res ]]; then
          for file in $(ls $gmemdir/RESTART/${rPDY}.${rcyc}0000.*.nc); do
             file2=$(echo $(basename -- $file))
             file2=$(echo $file2 | cut -d. -f3-) # remove the date from file
             fsuf=$(echo $file2 | cut -d. -f1)
             if [ $fsuf != "sfc_data" ]; then
                $NLN $file $DATA/INPUT${nbg}/$file2
             fi
          done
       elif [[ $rst_int -eq 9 && -s $gmemdir/RESTART/coupler.res ]]; then
          $NLN $gmemdir/RESTART/fv_core*.nc $DATA/INPUT${nbg}/
          $NLN $gmemdir/RESTART/fv_tracer*.nc $DATA/INPUT${nbg}/
          $NLN $gmemdir/RESTART/fv_srf_wnd*.nc $DATA/INPUT${nbg}/
          $NLN $gmemdir/RESTART/phy_data*.nc $DATA/INPUT${nbg}/
          $NLN $gmemdir/RESTART/coupler.res $DATA/INPUT${nbg}/
       else
          echo "missing restart file at $rst_int hour, ABORT!"
          exit 1
       fi 
       nbg=$((nbg+1))
     fi
   done
fi

#-------------------------------------------------------

nfiles=$(ls -1 $DATA/INPUT/* | wc -l)
if [ $nfiles -le 0 ]; then
  echo "Initial conditions must exist in $DATA/INPUT, ABORT!"
  msg="Initial conditions must exist in $DATA/INPUT, ABORT!"
  postmsg "$jlogfile" "$msg"
  exit 1
fi

# If doing IAU, change forecast hours
if [[ "$DOIAU" = "YES" ]]; then
# FHMAX=$((FHMAX+6))
  if [ $FHMAX_HF -gt 0 ]; then
     FHMAX_HF=$((FHMAX_HF+6))
  fi
fi

#--------------------------------------------------------------------------
# Grid and orography data
for n in $(seq 1 $ntiles); do
  $NLN $FIXfv3/$CASE/${CASE}_grid.tile${n}.nc     $DATA/INPUT/${CASE}_grid.tile${n}.nc
  $NLN $FIXfv3/$CASE/${CASE}_oro_data.tile${n}.nc $DATA/INPUT/oro_data.tile${n}.nc
done
$NLN $FIXfv3/$CASE/${CASE}_mosaic.nc  $DATA/INPUT/grid_spec.nc

# GFS standard input data
IAER=${IAER:-111}
ICO2=${ICO2:-2}

if [ ${new_o3forc:-YES} = YES ]; then
    O3FORC=ozprdlos_2015_new_sbuvO3_tclm15_nuchem.f77
else
    O3FORC=global_o3prdlos.f77
fi
H2OFORC=${H2OFORC:-"global_h2o_pltc.f77"}
$NLN $FIX_AM/${O3FORC}                         $DATA/INPUT/global_o3prdlos.f77
$NLN $FIX_AM/${H2OFORC}                        $DATA/INPUT/global_h2oprdlos.f77
$NLN $FIX_AM/global_solarconstant_noaa_an.txt  $DATA/INPUT/solarconstant_noaa_an.txt
$NLN $FIX_AM/global_sfc_emissivity_idx.txt     $DATA/INPUT/sfc_emissivity_idx.txt

## merra2 aerosol climo (only for gfs)
for n in 01 02 03 04 05 06 07 08 09 10 11 12; do
$NLN $FIX_AER/merra2.aerclim.2003-2014.m${n}.nc $DATA/aeroclim.m${n}.nc
done
$NLN $FIX_LUT/optics_BC.v1_3.dat $DATA/optics_BC.dat
$NLN $FIX_LUT/optics_OC.v1_3.dat $DATA/optics_OC.dat
$NLN $FIX_LUT/optics_DU.v15_3.dat $DATA/optics_DU.dat
$NLN $FIX_LUT/optics_SS.v3_3.dat $DATA/optics_SS.dat
$NLN $FIX_LUT/optics_SU.v1_3.dat $DATA/optics_SU.dat

$NLN $FIX_AM/global_co2historicaldata_glob.txt $DATA/INPUT/co2historicaldata_glob.txt
$NLN $FIX_AM/co2monthlycyc.txt                 $DATA/INPUT/co2monthlycyc.txt
if [ $ICO2 -gt 0 ]; then
  for file in $(ls $FIX_AM/fix_co2_proj/global_co2historicaldata*) ; do
    $NLN $file $DATA/INPUT/$(echo $(basename -- $file) | sed -e "s/global_//g")
  done
fi

$NLN $FIX_AM/global_climaeropac_global.txt     $DATA/INPUT/aerosol.dat
if [ $IAER -gt 0 ] ; then
  for file in $(ls $FIX_AM/global_volcanic_aerosols*) ; do
    $NLN $file $DATA/INPUT/$(echo $(basename -- $file) | sed -e "s/global_//g")
  done
fi

#-------------wavewave----------------------
if [ $cplwav = ".true." ]; then

  for file in $(ls $COMINwave/rundata/rmp_src_to_dst_conserv_*) ; do
    $NLN $file $DATA/
  done
  $NLN $COMINwave/rundata/ww3_multi.${CDUMPwave}${WAV_MEMBER}.${cycle}.inp $DATA/ww3_multi.inp

  array=($WAVECUR_FID $WAVEICE_FID $WAVEWND_FID $waveuoutpGRD $waveGRD $waveesmfGRD $wavesbsGRD $wavepostGRD $waveinterpGRD)
  grdALL=`printf "%s\n" "${array[@]}" | sort -u | tr '\n' ' '`

  for wavGRD in ${grdALL}; do
    $NLN $COMINwave/rundata/${CDUMPwave}.mod_def.$wavGRD $DATA/mod_def.$wavGRD
  done

  export WAVHCYC=${WAVHCYC:-6}
  export WRDATE=`$NDATE -${WAVHCYC} $CDATE`
  export WRPDY=`echo $WRDATE | cut -c1-8`
  export WRcyc=`echo $WRDATE | cut -c9-10`
  export WRDIR=${ROTDIR}/${CDUMPRSTwave}.${WRPDY}/${WRcyc}/wave/restart
  export datwave=$COMOUTwave/rundata
  export wavprfx=${CDUMPwave}${WAV_MEMBER}

  for wavGRD in $waveGRD ; do
    if [ $RERUN = "NO" ]; then
      if [ ! -f ${WRDIR}/${sPDY}.${scyc}0000.restart.${wavGRD} ]; then 
        echo "WARNING: NON-FATAL ERROR wave IC is missing, will start from rest"
      fi
      $NLN ${WRDIR}/${sPDY}.${scyc}0000.restart.${wavGRD} $DATA/restart.${wavGRD}
    else
      if [ ! -f ${RSTDIR_WAVE}/${PDYT}.${cyct}0000.restart.${wavGRD} ]; then
        echo "WARNING: NON-FATAL ERROR wave IC is missing, will start from rest"
      fi
      $NLN ${RSTDIR_WAVE}/${PDYT}.${cyct}0000.restart.${wavGRD} $DATA/restart.${wavGRD}
    fi
    eval $NLN $datwave/${wavprfx}.log.${wavGRD}.${PDY}${cyc} log.${wavGRD}
  done

  if [ "$WW3ICEINP" = "YES" ]; then
    wavicefile=$COMINwave/rundata/${CDUMPwave}.${WAVEICE_FID}.${cycle}.ice
    if [ ! -f $wavicefile ]; then
      echo "ERROR: WW3ICEINP = ${WW3ICEINP}, but missing ice file"
      echo "Abort!"
      exit 1
    fi
    $NLN ${wavicefile} $DATA/ice.${WAVEICE_FID}
  fi

  if [ "$WW3CURINP" = "YES" ]; then
    wavcurfile=$COMINwave/rundata/${CDUMPwave}.${WAVECUR_FID}.${cycle}.cur
    if [ ! -f $wavcurfile ]; then
      echo "ERROR: WW3CURINP = ${WW3CURINP}, but missing current file"
      echo "Abort!"
      exit 1
    fi
    $NLN $wavcurfile $DATA/current.${WAVECUR_FID}
  fi

  # Link output files
  cd $DATA
  eval $NLN $datwave/${wavprfx}.log.mww3.${PDY}${cyc} log.mww3

  # Loop for gridded output (uses FHINC)
  fhr=$FHMIN_WAV
  while [ $fhr -le $FHMAX_WAV ]; do
    YMDH=`$NDATE $fhr $CDATE`
    YMD=$(echo $YMDH | cut -c1-8)
    HMS="$(echo $YMDH | cut -c9-10)0000"
      for wavGRD in ${waveGRD} ; do
        eval $NLN $datwave/${wavprfx}.out_grd.${wavGRD}.${YMD}.${HMS} ${YMD}.${HMS}.out_grd.${wavGRD}
      done
      FHINC=$FHOUT_WAV
      if [ $FHMAX_HF_WAV -gt 0 -a $FHOUT_HF_WAV -gt 0 -a $fhr -lt $FHMAX_HF_WAV ]; then
        FHINC=$FHOUT_HF_WAV
      fi
    fhr=$((fhr+FHINC))
  done

  # Loop for point output (uses DTPNT)
  fhr=$FHMIN_WAV
  while [ $fhr -le $FHMAX_WAV ]; do
    YMDH=`$NDATE $fhr $CDATE`
    YMD=$(echo $YMDH | cut -c1-8)
    HMS="$(echo $YMDH | cut -c9-10)0000"
      eval $NLN $datwave/${wavprfx}.out_pnt.${waveuoutpGRD}.${YMD}.${HMS} ${YMD}.${HMS}.out_pnt.${waveuoutpGRD}
      FHINC=$FHINCP_WAV
    fhr=$((fhr+FHINC))
  done

fi #cplwav=true
#-------------wavewave----------------------

# inline post fix files
if [ $WRITE_DOPOST = ".true." ]; then
    $NLN $PARM_POST/post_tag_gfs${LEVS}             $DATA/itag               
    $NLN $PARM_POST/postxconfig-NT-GFS-TWO.txt      $DATA/postxconfig-NT.txt 
    $NLN $PARM_POST/postxconfig-NT-GFS-F00-TWO.txt  $DATA/postxconfig-NT_FH00.txt
    $NLN $PARM_POST/params_grib2_tbl_new            $DATA/params_grib2_tbl_new
fi
#------------------------------------------------------------------

# changeable parameters
# dycore definitions
res=$(echo $CASE |cut -c2-5)
resp=$((res+1))
npx=$resp
npy=$resp
npz=$LEVS
io_layout=${io_layout:-"1,1"}
#ncols=$(( (${npx}-1)*(${npy}-1)*3/2 ))

# spectral truncation and regular grid resolution based on FV3 resolution
JCAP_CASE=$((2*res-2))
LONB_CASE=$((4*res))
LATB_CASE=$((2*res))

JCAP=${JCAP:-$JCAP_CASE}
LONB=${LONB:-$LONB_CASE}
LATB=${LATB:-$LATB_CASE}

LONB_IMO=${LONB_IMO:-$LONB_CASE}
LATB_JMO=${LATB_JMO:-$LATB_CASE}

# Fix files
FNGLAC=${FNGLAC:-"$FIX_AM/global_glacier.2x2.grb"}
FNMXIC=${FNMXIC:-"$FIX_AM/global_maxice.2x2.grb"}
FNTSFC=${FNTSFC:-"$FIX_AM/RTGSST.1982.2012.monthly.clim.grb"}
do_ocean=${do_ocean:-".true."}
if [ $DONST = "YES" ]; then
  do_ocean=".false."
fi
if [ $do_ocean = ".true." ]; then
  FNMLDC=${FNMLDC:-"$FIX_SHiELD/climo_data.v201807/mld/mld_DR003_c1m_reg2.0.grb"}
else
  FNMLDC="        "
fi
FNSNOC=${FNSNOC:-"$FIX_AM/global_snoclim.1.875.grb"}
FNZORC=${FNZORC:-"igbp"}
FNALBC2=${FNALBC2:-"$FIX_AM/global_albedo4.1x1.grb"}
FNAISC=${FNAISC:-"$FIX_AM/CFSR.SEAICE.1982.2012.monthly.clim.grb"}
FNTG3C=${FNTG3C:-"$FIX_AM/global_tg3clim.2.6x1.5.grb"}
FNVEGC=${FNVEGC:-"$FIX_AM/global_vegfrac.0.144.decpercent.grb"}
FNMSKH=${FNMSKH:-"$FIX_AM/global_slmask.t1534.3072.1536.grb"}
FNVMNC=${FNVMNC:-"$FIX_AM/global_shdmin.0.144x0.144.grb"}
FNVMXC=${FNVMXC:-"$FIX_AM/global_shdmax.0.144x0.144.grb"}
FNSLPC=${FNSLPC:-"$FIX_AM/global_slope.1x1.grb"}
FNALBC=${FNALBC:-"$FIX_AM/global_snowfree_albedo.bosu.t${JCAP}.${LONB}.${LATB}.rg.grb"}
FNVETC=${FNVETC:-"$FIX_AM/global_vegtype.igbp.t${JCAP}.${LONB}.${LATB}.rg.grb"}
FNSOTC=${FNSOTC:-"$FIX_AM/global_soiltype.statsgo.t${JCAP}.${LONB}.${LATB}.rg.grb"}
FNABSC=${FNABSC:-"$FIX_AM/global_mxsnoalb.uariz.t${JCAP}.${LONB}.${LATB}.rg.grb"}
FNSMCC=${FNSMCC:-"$FIX_AM/global_soilmgldas.statsgo.t${JCAP}.${LONB}.${LATB}.grb"}

# If the appropriate resolution fix file is not present, use the highest resolution available (T1534)
[[ ! -f $FNALBC ]] && FNALBC="$FIX_AM/global_snowfree_albedo.bosu.t1534.3072.1536.rg.grb"
[[ ! -f $FNVETC ]] && FNVETC="$FIX_AM/global_vegtype.igbp.t1534.3072.1536.rg.grb"
[[ ! -f $FNSOTC ]] && FNSOTC="$FIX_AM/global_soiltype.statsgo.t1534.3072.1536.rg.grb"
[[ ! -f $FNABSC ]] && FNABSC="$FIX_AM/global_mxsnoalb.uariz.t1534.3072.1536.rg.grb"
[[ ! -f $FNSMCC ]] && FNSMCC="$FIX_AM/global_soilmgldas.statsgo.t1534.3072.1536.grb"

# NSST Options
# nstf_name contains the NSST related parameters
# nstf_name(1) : NST_MODEL (NSST Model) : 0 = OFF, 1 = ON but uncoupled, 2 = ON and coupled
# nstf_name(2) : NST_SPINUP : 0 = OFF, 1 = ON,
# nstf_name(3) : NST_RESV (Reserved, NSST Analysis) : 0 = OFF, 1 = ON
# nstf_name(4) : ZSEA1 (in mm) : 0
# nstf_name(5) : ZSEA2 (in mm) : 0
# nst_anl      : .true. or .false., NSST analysis over lake
NST_MODEL=${NST_MODEL:-0}
NST_SPINUP=${NST_SPINUP:-0}
NST_RESV=${NST_RESV-0}
ZSEA1=${ZSEA1:-0}
ZSEA2=${ZSEA2:-0}
nstf_name=${nstf_name:-"$NST_MODEL,$NST_SPINUP,$NST_RESV,$ZSEA1,$ZSEA2"}
nst_anl=${nst_anl:-".false."}


# blocking factor used for threading and general physics performance
#nyblocks=`expr \( $npy - 1 \) \/ $layout_y `
#nxblocks=`expr \( $npx - 1 \) \/ $layout_x \/ 32`
#if [ $nxblocks -le 0 ]; then nxblocks=1 ; fi
blocksize=${blocksize:-32}

# the pre-conditioning of the solution
# =0 implies no pre-conditioning
# >0 means new adiabatic pre-conditioning
# <0 means older adiabatic pre-conditioning
na_init=${na_init:-0}
[[ $warm_start = ".true." ]] && na_init=0

# variables for controlling initialization of NCEP/NGGPS ICs
filtered_terrain=${filtered_terrain:-".true."}
ncep_levs=${ncep_levs:-128}
gfs_dwinds=${gfs_dwinds:-".true."}

# various debug options
no_dycore=${no_dycore:-".false."}
dycore_only=${adiabatic:-".false."}
chksum_debug=${chksum_debug:-".false."}
print_freq=${print_freq:-6}

if [ ${TYPE} = "nh" ]; then # non-hydrostatic options

  hydrostatic=".false."
  phys_hydrostatic=".false."     # enable heating in hydrostatic balance in non-hydrostatic simulation
  use_hydro_pressure=".false."   # use hydrostatic pressure for physics
  if [ $warm_start = ".true." ]; then
    make_nh=".false."              # restarts contain non-hydrostatic state
  else
    if [ $ICSTYP = "gfs" ]; then
      make_nh=".false." 
    else
      make_nh=".true."
    fi
  fi
  consv_te=1.
  if [ $CDUMP = "gdas" ]; then
    k_split=${k_split:-2}
    n_split=${n_split:-6}
  else
    k_split=${k_split:-1}
    n_split=${n_split:-8}
  fi
else # hydrostatic options
  hydrostatic=".true."
  phys_hydrostatic=".false."     # ignored when hydrostatic = T
  use_hydro_pressure=".false."   # ignored when hydrostatic = T
  make_nh=".false."              # running in hydrostatic mode
  consv_te=0.
  k_split=${k_split:-2}
  n_split=${n_split:-6}
fi

# Conserve total energy as heat globally
consv_te=${consv_te:-1.} # range 0.-1., 1. will restore energy to orig. val. before physics

if [ $(echo $MONO | cut -c-4) = "mono" ];  then # monotonic options

  d_con=${d_con_mono:-"1."}
  do_vort_damp=".false."
  if [ ${TYPE} = "nh" ]; then # non-hydrostatic
    hord_mt=${hord_mt_nh_mono:-"10"}
    hord_xx=${hord_xx_nh_mono:-"10"}
  else # hydrostatic
    hord_mt=${hord_mt_hydro_mono:-"10"}
    hord_xx=${hord_xx_hydro_mono:-"10"}
  fi

else # non-monotonic options

  d_con=${d_con_nonmono:-"1."}
  do_vort_damp=".true."
  if [ ${TYPE} = "nh" ]; then # non-hydrostatic
    hord_mt=${hord_mt_nh_nonmono:-"5"}
    hord_xx=${hord_xx_nh_nonmono:-"5"}
  else # hydrostatic
    hord_mt=${hord_mt_hydro_nonmono:-"10"}
    hord_xx=${hord_xx_hydro_nonmono:-"10"}
  fi

fi

if [ $(echo $MONO | cut -c-4) != "mono" -a $TYPE = "nh" ]; then
  vtdm4=${vtdm4_nh_nonmono:-"0.03"}
else
  vtdm4=${vtdm4:-"0.05"}
fi

if [ $warm_start = ".true." ]; then # warm start from restart file

  external_ic=".false."
  mountain=".true."
  if [ $replay -eq 1 ]; then
    if [ $ICSTYP = "gfs" ]; then
      nudge_qv=${nudge_qv:-".true."}
      nggps_ic=${nggps_ic:-".true."}
      ncep_ic=${ncep_ic:-".false."}
      ecmwf_ic=".false."
      res_latlon_dynamics='""'
    else
      nudge_qv=".false."
      nggps_ic=".false."
      ncep_ic=".false."
      ecmwf_ic=".true."
      res_latlon_dynamics='"EXTIC/gk03_CF0.nc"'
    fi
  else
    nudge_qv=${nudge_qv:-".true."}
    nggps_ic=".false."
    ncep_ic=".false."
    ecmwf_ic=".false."
  fi

  if [ $read_increment = ".true." ]; then # add increment on the fly to the restarts
    res_latlon_dynamics="fv_increment.nc"
  fi

else # CHGRES'd GFS analyses
  if [ $ICSTYP = "gfs" ]; then
    nudge_qv=${nudge_qv:-".true."}
    nggps_ic=".true."
    ecmwf_ic=".false."
    res_latlon_dynamics='""'
  else
    nudge_qv=".false."
    nggps_ic=".false."
    ecmwf_ic=".true."
    res_latlon_dynamics='"INPUT/gk03_CF0.nc"'
  fi
  ncep_ic=${ncep_ic:-".false."}
  external_ic=".true."
  mountain=".false."
  read_increment=".false."
fi

# Stochastic Physics Options
if [ ${SET_STP_SEED:-"YES"} = "YES" ]; then
  ISEED_SKEB=$((CDATE*1000 + MEMBER*10 + 1))
  ISEED_SHUM=$((CDATE*1000 + MEMBER*10 + 2))
  ISEED_SPPT=$((CDATE*1000 + MEMBER*10 + 3))
else
  ISEED=${ISEED:-0}
fi
DO_SKEB=${DO_SKEB:-"NO"}
DO_SPPT=${DO_SPPT:-"NO"}
DO_SHUM=${DO_SHUM:-"NO"}
DO_LAND_PERT=${DO_LAND_PERT:-"NO"}

if [ $DO_SKEB = "YES" ]; then
    do_skeb=".true."
fi
if [ $DO_SHUM = "YES" ]; then
    do_shum=".true."
fi
if [ $DO_SPPT = "YES" ]; then
    do_sppt=".true."
fi
curr_date="${sPDY:0:4},${sPDY:4:2},${sPDY:6:2},${scyc},0,0"

# Create input.nml
shield_namelists

#------------------------------------------------------------------
# make symbolic links to write forecast files directly in memdir
cd $DATA
if [ $QUILTING = ".true." -a $OUTPUT_GRID = "gaussian_grid" ]; then
  fhr=$FHMIN
  while [ $fhr -le $FHMAX ]; do
    FH3=$(printf %03i $fhr)
    FH2=$(printf %02i $fhr)
    atmi=atmf${FH3}.$affix
    sfci=sfcf${FH3}.$affix
    logi=logf${FH3}
    pgbi=GFSPRS.GrbF${FH2}
    flxi=GFSFLX.GrbF${FH2}
    atmo=$memdir/${CDUMP}.t${cyc}z.atmf${FH3}.$affix
    sfco=$memdir/${CDUMP}.t${cyc}z.sfcf${FH3}.$affix
    logo=$memdir/${CDUMP}.t${cyc}z.logf${FH3}.txt
    pgbo=$memdir/${CDUMP}.t${cyc}z.master.grb2f${FH3}
    flxo=$memdir/${CDUMP}.t${cyc}z.sfluxgrbf${FH3}.grib2
    eval $NLN $atmo $atmi
    eval $NLN $sfco $sfci
    eval $NLN $logo $logi
    if [ $WRITE_DOPOST = ".true." ]; then
      eval $NLN $pgbo $pgbi
      eval $NLN $flxo $flxi
    fi
    FHINC=$FHOUT
    if [ $FHMAX_HF -gt 0 -a $FHOUT_HF -gt 0 -a $fhr -lt $FHMAX_HF ]; then
      FHINC=$FHOUT_HF
    fi
    fhr=$((fhr+FHINC))
  done
else
  echo 'shield history files'
  if [[ "$CDUMP" = "gfs" && "$DO_CUBE2GAUS" = "NO" ]] ; then
     for n in $(seq 1 $ntiles); do
       eval $NLN $memdir/grid_spec.tile${n}.nc        grid_spec.tile${n}.nc
       eval $NLN $memdir/atmos_4xdaily.tile${n}.nc    atmos_4xdaily.tile${n}.nc
       eval $NLN $memdir/atmos_static.tile${n}.nc     atmos_static.tile${n}.nc
       eval $NLN $memdir/atmos_sos.tile${n}.nc        atmos_sos.tile${n}.nc
       eval $NLN $memdir/nggps2d.tile${n}.nc          nggps2d.tile${n}.nc
       eval $NLN $memdir/nggps3d_4xdaily.tile${n}.nc  nggps3d_4xdaily.tile${n}.nc
       eval $NLN $memdir/tracer3d_4xdaily.tile${n}.nc tracer3d_4xdaily.tile${n}.nc
     done
  fi
  for n in $(seq 1 $ntiles); do
     eval $NLN $memdir/gfs_physics.tile${n}.nc        gfs_physics.tile${n}.nc
  done
  eval $NLN $memdir/tendency.dat  fort.555
fi

# Link restart files for replay
rst_hrs1=`echo $rst_hrs |cut -d " " -f 1`
gFHMAX=$FHMAX
if [[ $CDUMP = "gdas" || $rst_hrs1 -gt 0 ]]; then
  if [[ $rst_hrs1 -gt 0 ]]; then
    if [ $nrestartbg = 1 ]; then
      rst_link_list="3 6"
    else
      rst_link_list=$rst_hrs
      gFHMAX=$((FHMAX - 3)) 
    fi
  else
    if [ $DOIAU = "YES" ] || [ $DOIAU_coldstart = "YES" ]; then
      rst_link_list="3 6"
    else
      rst_link_list="6"
    fi
  fi
  mkdir -p $memdir/RESTART
  for rst_int in $rst_link_list ; do
    if [ $rst_int -ge 0 ]; then
      RDATE=$($NDATE +$rst_int $CDATE)
      rPDY=$(echo $RDATE | cut -c1-8)
      rcyc=$(echo $RDATE | cut -c9-10)
      if [ $rst_int -lt $gFHMAX ]; then
        for file in "fv_core.res" "fv_tracer.res" "phy_data" "fv_srf_wnd.res" "sfc_data" ; do
          $NLN $memdir/RESTART/${rPDY}.${rcyc}0000.${file}.tile1.nc $DATA/RESTART/${rPDY}.${rcyc}0000.${file}.tile1.nc
          $NLN $memdir/RESTART/${rPDY}.${rcyc}0000.${file}.tile2.nc $DATA/RESTART/${rPDY}.${rcyc}0000.${file}.tile2.nc
          $NLN $memdir/RESTART/${rPDY}.${rcyc}0000.${file}.tile3.nc $DATA/RESTART/${rPDY}.${rcyc}0000.${file}.tile3.nc
          $NLN $memdir/RESTART/${rPDY}.${rcyc}0000.${file}.tile4.nc $DATA/RESTART/${rPDY}.${rcyc}0000.${file}.tile4.nc
          $NLN $memdir/RESTART/${rPDY}.${rcyc}0000.${file}.tile5.nc $DATA/RESTART/${rPDY}.${rcyc}0000.${file}.tile5.nc
          $NLN $memdir/RESTART/${rPDY}.${rcyc}0000.${file}.tile6.nc $DATA/RESTART/${rPDY}.${rcyc}0000.${file}.tile6.nc
        done
        $NLN $memdir/RESTART/${rPDY}.${rcyc}0000.fv_core.res.nc $DATA/RESTART/${rPDY}.${rcyc}0000.fv_core.res.nc
        $NLN $memdir/RESTART/${rPDY}.${rcyc}0000.coupler.res $DATA/RESTART/${rPDY}.${rcyc}0000.coupler.res
      else
        for file in "fv_core.res" "fv_tracer.res" "phy_data" "fv_srf_wnd.res" "sfc_data" ; do
          $NLN $memdir/RESTART/${file}.tile1.nc $DATA/RESTART/${file}.tile1.nc
          $NLN $memdir/RESTART/${file}.tile2.nc $DATA/RESTART/${file}.tile2.nc
          $NLN $memdir/RESTART/${file}.tile3.nc $DATA/RESTART/${file}.tile3.nc
          $NLN $memdir/RESTART/${file}.tile4.nc $DATA/RESTART/${file}.tile4.nc
          $NLN $memdir/RESTART/${file}.tile5.nc $DATA/RESTART/${file}.tile5.nc
          $NLN $memdir/RESTART/${file}.tile6.nc $DATA/RESTART/${file}.tile6.nc
        done
        $NLN $memdir/RESTART/fv_core.res.nc $DATA/RESTART/fv_core.res.nc
        $NLN $memdir/RESTART/coupler.res $DATA/RESTART/coupler.res
      fi
    fi
  done
fi

#------------------------------------------------------------------
# run the executable

$NCP $FCSTEXECDIR/$FCSTEXEC $DATA/.
export OMP_NUM_THREADS=$NTHREADS_FV3
$APRUN_FV3 $DATA/$FCSTEXEC 1>&1 2>&2
export ERR=$?
export err=$ERR
$ERRSCRIPT || exit $err

#------------------------------------------------------------------
# cubesphere to gaussian
#------------------------------------------------------------------
if [[ "$CDUMP" = "gdas" || "$DO_CUBE2GAUS" = "YES" ]] ; then
  cd $DATA

  cat > serial-tasks.config <<EOF
  # rank command
EOF

  export OMP_NUM_THREADS_ATMS=$nth_fcst
  export OMP_NUM_THREADS_SFC=$NTHREADS_GAUSFCFCST
  export rmhydro=${rmhydro:-".false."}
  export pseudo_ps=${pseudo_ps:-".false."}
  export phy_data=${phy_data=:-""}
  export sCDATE=$sCDATE
  export FHMIN=$FHMIN
  export FHMAX=$FHMAX
  export DELTIM=$DELTIM
  export iau_halfdelthrs=$iau_halfdelthrs
  export FHZER=$FHZER

  RHR=$FHMIN
  mc=0
  while [[ $RHR -le $FHMAX ]] ; do
     echo "s/_RHR/$RHR/"          > changedate
     echo "s/_auxfhr/"NO"/"      >> changedate
     echo "s/_atminc/".false."/" >> changedate
     sed -f changedate $C2GSH > c2g_$( printf "%03d" $mc).sh
     chmod 755 c2g_$( printf "%03d" $mc).sh
     cat >> serial-tasks.config <<EOF
     $mc c2g_$( printf "%03d" $mc).sh
EOF
     RHR=$(($RHR+$FHOUT))
     mc=$((mc+1)) 
  done

# Auxiliary forecast hours
  if [[ $restart_secs_aux -gt 0 ]]; then
     RHR_aux=$FHMIN_aux
     while [[ $RHR_aux -le $FHMAX_aux ]] ; do 
        # check if duplicated
        found=0
        drhr=$((FHMIN+FHOUT))
        while [[ $drhr -le $FHMAX_aux ]]; do
           if [[ $RHR_aux -eq $drhr ]]; then
              found=1
              break
           fi
           drhr=$((drhr+FHOUT))
        done
        if [[ $found -eq 0 ]]; then
           echo "s/_RHR/$RHR_aux/"      > changedate
           echo "s/_auxfhr/"YES"/"     >> changedate
           echo "s/_atminc/".false."/" >> changedate
           sed -f changedate $C2GSH > c2g_$( printf "%03d" $mc).sh
           chmod 755 c2g_$( printf "%03d" $mc).sh
     cat >> serial-tasks.config <<EOF
     $mc c2g_$( printf "%03d" $mc).sh
EOF
           mc=$((mc+1))
        fi
        RHR_aux=$((RHR_aux+FHOUT_aux))
     done
  fi

# replay increment file
  if [[ $replay -eq 1 && $warm_start = ".true." ]]; then
     echo "s/_RHR/0/"            > changedate
     echo "s/_auxfhr/"NO"/"     >> changedate
     echo "s/_atminc/".true."/" >> changedate
     sed -f changedate $C2GSH > c2g_$( printf "%03d" $mc).sh
     chmod 755 c2g_$( printf "%03d" $mc).sh
     cat >> serial-tasks.config <<EOF
     $mc c2g_$( printf "%03d" $mc).sh
EOF
     mc=$((mc+1))
  fi

  npe_c2g=$mc
  APRUN_C2G="$launcher -n $npe_c2g --tasks-per-node=$tasks_per_node_c2g --cpus-per-task=$cpus_per_task_c2g -l --multi-prog"

  $APRUN_C2G serial-tasks.config 1>&1 2>&2
  rc=$?
  export ERR=$rc
  export err=$ERR
  $ERRSCRIPT || exit 11
fi

################################################################################
# Postprocessing
cd $pwd
[[ $mkdata = "YES" ]] && rm -rf $DATA


################################################################################

exit $err

################################################################################

