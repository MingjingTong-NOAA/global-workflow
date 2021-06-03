#!/bin/ksh -x

###############################################################
## Abstract:
## Archive driver script
## RUN_ENVIR : runtime environment (emc | nco)
## HOMEgfs   : /full/path/to/workflow
## EXPDIR : /full/path/to/config/files
## CDATE  : current analysis date (YYYYMMDDHH)
## CDUMP  : cycle name (gdas / gfs)
## PDY    : current date (YYYYMMDD)
## cyc    : current cycle (HH)
###############################################################

###############################################################
# Source FV3GFS workflow modules
. $HOMEgfs/ush/load_fv3gfs_modules.sh
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
# Source relevant configs
configs="base arch"
for config in $configs; do
    . $EXPDIR/config.${config}
    status=$?
    [[ $status -ne 0 ]] && exit $status
done

# ICS are restarts and always lag INC by $assim_freq hours
ARCHINC_CYC=$ARCH_CYC
ARCHICS_CYC=$((ARCH_CYC-assim_freq))
if [ $ARCHICS_CYC -lt 0 ]; then
    ARCHICS_CYC=$((ARCHICS_CYC+24))
fi

# CURRENT CYCLE
APREFIX="${CDUMP}.t${cyc}z."
ASUFFIX=${ASUFFIX:-$SUFFIX}

if [ $ASUFFIX = ".nc" ]; then
   format="netcdf"
else
   format="nemsio"
fi


# Realtime parallels run GFS MOS on 1 day delay
# If realtime parallel, back up CDATE_MOS one day
CDATE_MOS=$CDATE
if [ $REALTIME = "YES" ]; then
    CDATE_MOS=$($NDATE -24 $CDATE)
fi
PDY_MOS=$(echo $CDATE_MOS | cut -c1-8)

###############################################################
# Archive online for verification and diagnostics
###############################################################

COMIN=${COMINatmos:-"$ROTDIR/$CDUMP.$PDY/$cyc/atmos"}
cd $COMIN

[[ ! -d $ARCDIR ]] && mkdir -p $ARCDIR
[[ -s tendency.dat ]] && $NCP tendency.dat $ARCDIR/tendency.${CDATE}.dat

# Archive 1 degree forecast GRIB2 files for verification
if [ $CDUMP = "gfs" -o $FHMAX = $FHMAX_GFS ]; then
    fhmax=$FHMAX_GFS
    fhr=0
    while [ $fhr -le $fhmax ]; do
        fhr2=$(printf %02i $fhr)
        fhr3=$(printf %03i $fhr)
        $NCP ${APREFIX}pgrb2.1p00.f$fhr3 $ARCDIR/pgbf${fhr2}.${CDUMP}.${CDATE}.grib2
        (( fhr = $fhr + $FHOUT_GFS ))
    done
fi

if [ -s avno.t${cyc}z.cyclone.trackatcfunix ]; then
    PLSOT4=`echo $PSLOT|cut -c 1-4 |tr '[a-z]' '[A-Z]'`
    cat avno.t${cyc}z.cyclone.trackatcfunix | sed s:AVNO:${PLSOT4}:g  > ${ARCDIR}/atcfunix.${CDUMP}.$CDATE
    cat avnop.t${cyc}z.cyclone.trackatcfunix | sed s:AVNO:${PLSOT4}:g  > ${ARCDIR}/atcfunixp.${CDUMP}.$CDATE
fi

if [ $CDUMP = "gdas" -a -s gdas.t${cyc}z.cyclone.trackatcfunix ]; then
    PLSOT4=`echo $PSLOT|cut -c 1-4 |tr '[a-z]' '[A-Z]'`
    cat gdas.t${cyc}z.cyclone.trackatcfunix | sed s:AVNO:${PLSOT4}:g  > ${ARCDIR}/atcfunix.${CDUMP}.$CDATE
    cat gdasp.t${cyc}z.cyclone.trackatcfunix | sed s:AVNO:${PLSOT4}:g  > ${ARCDIR}/atcfunixp.${CDUMP}.$CDATE
fi

if [ $CDUMP = "gfs" -o $FHMAX = $FHMAX_GFS ]; then
    $NCP storms.gfso.atcf_gen.$CDATE      ${ARCDIR}/.
    $NCP storms.gfso.atcf_gen.altg.$CDATE ${ARCDIR}/.
    $NCP trak.gfso.atcfunix.$CDATE        ${ARCDIR}/.
    $NCP trak.gfso.atcfunix.altg.$CDATE   ${ARCDIR}/.

    mkdir -p ${ARCDIR}/tracker.$CDATE/$CDUMP
    blist="epac natl"
    for basin in $blist; do
	cp -rp $basin                     ${ARCDIR}/tracker.$CDATE/$CDUMP
    done
fi

# Archive atmospheric gaussian gfs forecast files for fit2obs
VFYARC=${VFYARC:-$ROTDIR/vrfyarch}
[[ ! -d $VFYARC ]] && mkdir -p $VFYARC
if [ $FITSARC = "YES" ]; then
    mkdir -p $VFYARC/${CDUMP}.$PDY/$cyc
    fhmax=${FHMAX_FITS:-$FHMAX_GFS}
    fhr=0
    while [[ $fhr -le $fhmax ]]; do
      fhr3=$(printf %03i $fhr)
      sfcfile=${CDUMP}.t${cyc}z.sfcf${fhr3}${ASUFFIX}
      sigfile=${CDUMP}.t${cyc}z.atmf${fhr3}${ASUFFIX}
      $NCP $sfcfile $VFYARC/${CDUMP}.$PDY/$cyc/
      $NCP $sigfile $VFYARC/${CDUMP}.$PDY/$cyc/
      (( fhr = $fhr + 6 ))
    done
fi


###############################################################
# Archive data to HPSS
if [ $HPSSARCH = "YES" ]; then
###############################################################

#--determine when to save ICs for warm start and forecast-only runs 
SAVEWARMICA="NO"
SAVEWARMICB="NO"
SAVEFCSTIC="NO"
firstday=$($NDATE +24 $SDATE)
mm=`echo $CDATE|cut -c 5-6`
dd=`echo $CDATE|cut -c 7-8`
nday=$(( (mm-1)*30+dd ))
mod=$(($nday % $ARCH_WARMICFREQ))
if [ $CDATE -eq $firstday -a $cyc -eq $ARCHINC_CYC ]; then SAVEWARMICA="YES" ; fi
if [ $CDATE -eq $firstday -a $cyc -eq $ARCHICS_CYC ]; then SAVEWARMICB="YES" ; fi
if [ $mod -eq 0 -a $cyc -eq $ARCHINC_CYC ]; then SAVEWARMICA="YES" ; fi
if [ $mod -eq 0 -a $cyc -eq $ARCHICS_CYC ]; then SAVEWARMICB="YES" ; fi

if [ $ARCHICS_CYC -eq 18 ]; then
    nday1=$((nday+1))
    mod1=$(($nday1 % $ARCH_WARMICFREQ))
    if [ $mod1 -eq 0 -a $cyc -eq $ARCHICS_CYC ] ; then SAVEWARMICB="YES" ; fi
    if [ $mod1 -ne 0 -a $cyc -eq $ARCHICS_CYC ] ; then SAVEWARMICB="NO" ; fi
    if [ $CDATE -eq $SDATE -a $cyc -eq $ARCHICS_CYC ] ; then SAVEWARMICB="YES" ; fi
fi

mod=$(($nday % $ARCH_FCSTICFREQ))
if [[ $replay -gt 0 && ( $mod -eq 0 || $CDATE -eq $firstday ) ]]; then SAVEFCSTIC="YES" ; fi


ARCH_LIST="$COMIN/archlist"
[[ -d $ARCH_LIST ]] && rm -rf $ARCH_LIST
mkdir -p $ARCH_LIST
cd $ARCH_LIST

$HOMEgfs/ush/hpssarch_fcst.sh $CDUMP
status=$?
if [ $status -ne 0  ]; then
    echo "$HOMEgfs/ush/hpssarch_gen.sh $CDUMP failed, ABORT!"
    exit $status
fi

cd $ROTDIR

#for targrp in ${CDUMP}a ${CDUMP}b - NOTE - do not check htar error status
for targrp in ${CDUMP}a ${CDUMP}b; do
    htar -P -cvf $ATARDIR/$CDATE/${targrp}.tar `cat $ARCH_LIST/${targrp}.txt`
done

#for targrp in ${CDUMP}_flux ${CDUMP}_netcdf/nemsio ${CDUMP}_pgrb2b; do
if [ ${SAVEFCSTNEMSIO:-"YES"} = "YES" ]; then
    for targrp in ${CDUMP}_flux ${CDUMP}_${format}b ${CDUMP}_pgrb2b; do
        htar -P -cvf $ATARDIR/$CDATE/${targrp}.tar `cat $ARCH_LIST/${targrp}.txt`
        status=$?
        if [ $status -ne 0  -a $CDATE -ge $firstday ]; then
            echo "HTAR $CDATE ${targrp}.tar failed"
            exit $status
        fi
    done
fi

if [ $replay -gt 0 ]; then
  if [ $SAVEWARMICB = "YES" -o $SAVEFCSTIC = "YES" ]; then
    htar -P -cvf $ATARDIR/$CDATE/${CDUMP}_restartb.tar `cat $ARCH_LIST/${CDUMP}_restartb.txt`
    status=$?
    if [ $status -ne 0  -a $CDATE -ge $firstday ]; then
        echo "HTAR $CDATE ${CDUMP}_restartb.tar failed"
        exit $status
    fi
    GDATE=$($NDATE -6 $CDATE)
    htar -P -cvf $ATARDIR/$GDATE/${CDUMP}_restartb.tar `cat $ARCH_LIST/${CDUMP}_restartbm6.txt`
    status=$?
    if [ $status -ne 0  -a $GDATE -ge $firstday ]; then
        echo "HTAR $GDATE ${CDUMP}_restartb.tar failed"
        exit $status
    fi
  fi
fi

###############################################################
fi  ##end of HPSS archive
###############################################################

###############################################################
# Clean up previous cycles; various depths
GDATEEND=$($NDATE -12 $CDATE)
GDATE=$($NDATE -120 $CDATE)
while [ $GDATE -le $GDATEEND ]; do
    gPDY=$(echo $GDATE | cut -c1-8)
    gcyc=$(echo $GDATE | cut -c9-10)

    # Remove the TMPDIR directory
    COMIN="$RUNDIR/$GDATE"
    [[ -d $COMIN ]] && rm -rf $COMIN

    # Remove ICS directory
    [[ -d $ICSDIR/$GDATE ]] && rm -rf $ICSDIR/$GDATE
    
    [[ -d $ICSDIR/input/${ICDUMP}.${gPDY}/${gcyc} ]] && rm -rf $ICSDIR/input/${ICDUMP}.${gPDY}/${gcyc}

    GDATE=$($NDATE +$assim_freq $GDATE)
done

if [[ "${DELETE_COM_IN_ARCHIVE_JOB:-YES}" == NO ]] ; then
    exit 0
fi

# Step back every assim_freq hours
# and remove old rotating directories for successful cycles
# defaults from 24h to 120h
DO_GLDAS=${DO_GLDAS:-"NO"}
GDATEEND=$($NDATE -${RMOLDEND:-36}  $CDATE)
GDATE=$($NDATE -${RMOLDSTD:-120} $CDATE)
GLDAS_DATE=$($NDATE -96 $CDATE)
RTOFS_DATE=$($NDATE -48 $CDATE)
while [ $GDATE -le $GDATEEND ]; do
    gPDY=$(echo $GDATE | cut -c1-8)
    gcyc=$(echo $GDATE | cut -c9-10)
    COMIN="$ROTDIR/${CDUMP}.$gPDY/$gcyc/atmos"
    if [ -d $COMIN ]; then
        rocotolog="$EXPDIR/logs/${GDATE}.log"
	if [ -f $rocotolog ]; then
            testend=$(tail -n 1 $rocotolog | grep "This cycle is complete: Success")
            rc=$?
            if [ $rc -eq 0 ]; then
               rm -rf $COMIN 
            fi
	fi
    fi

    # Remove any empty directories
    if [ -d $COMIN ]; then
        [[ ! "$(ls -A $COMIN)" ]] && rm -rf $COMIN
    fi

    GDATE=$($NDATE +$assim_freq $GDATE)
done

# Remove archived atmospheric gaussian files used for fit2obs in $VFYARC that are $FHMAX_FITS hrs behind.
# touch existing files to prevent the files from being removed by the operation system.
if [ $CDUMP = "gfs" ]; then
    fhmax=$((FHMAX_FITS+48))       
    RDATE=$($NDATE -$fhmax $CDATE)
    rPDY=$(echo $RDATE | cut -c1-8)
    COMIN="$VFYARC/$CDUMP.$rPDY"
    [[ -d $COMIN ]] && rm -rf $COMIN

    TDATE=$($NDATE -$FHMAX_FITS $CDATE)
    while [ $TDATE -lt $CDATE ]; do
        tPDY=$(echo $TDATE | cut -c1-8)
        tcyc=$(echo $TDATE | cut -c9-10)
        TDIR=$VFYARC/$CDUMP.$tPDY/$tcyc
        [[ -d $TDIR ]] && touch $TDIR/*
        TDATE=$($NDATE +6 $TDATE)
    done
fi

###############################################################
exit 0
