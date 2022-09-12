#!/bin/ksh -x

###############################################################
## Abstract:
## Get ensemble forecast for ensemble replay
## RUN_ENVIR : runtime environment (emc | nco)
## HOMEgfs   : /full/path/to/workflow
## EXPDIR : /full/path/to/config/files
## CDATE  : current date (YYYYMMDDHH)
## CDUMP  : cycle name (gdas / gfs)
## PDY    : current date (YYYYMMDD)
## cyc    : current cycle (HH)
## ENSGRP : ensemble sub-group to archive (0, 1, 2, ...)
###############################################################

###############################################################
# Source FV3GFS workflow modules
. $HOMEgfs/ush/load_fv3gfs_modules.sh
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
# Source relevant configs
configs="base eget"
for config in $configs; do
    . $EXPDIR/config.${config}
    status=$?
    [[ $status -ne 0 ]] && exit $status
done

###############################################################
# Set script and dependency variables

export GDATE=$($NDATE -${assim_freq:-"06"} $CDATE)
gPDY=$(echo $GDATE | cut -c1-8)
gcyc=$(echo $GDATE | cut -c9-10)

export COMPONENT=${COMPONENT:-atmos}

RESTARTEXP=${RESTARTEXP:-${PSLOT}}
NMEM_EARCGRP=${NMEM_EARCGRP:-10}
NTARS=$((NMEM_ENKF/NMEM_EARCGRP))
[[ $NTARS -eq 0 ]] && NTARS=1
[[ $((NTARS*NMEM_EARCGRP)) -lt $NMEM_ENKF ]] && NTARS=$((NTARS+1))

cd $ROTDIR

ARCH_LIST="$ROTDIR/enkf${CDUMP}.${gPDY}/${gcyc}/$COMPONENT/earc$ENSGRP"
[[ -d $ARCH_LIST ]] && rm -rf $ARCH_LIST
mkdir -p $ARCH_LIST
cd $ARCH_LIST

export n=$((10#${ENSGRP}))

pulldata="NO"
rm -f enkf${CDUMP}_grp${ENSGRP}.txt
touch enkf${CDUMP}_grp${ENSGRP}.txt
if [[ $n -eq 0 ]]; then
  dirpath="enkf${CDUMP}.${gPDY}/${gcyc}/atmos/"
  dirname="./${dirpath}"
  head="${CDUMP}.t${gcyc}z."
  if [ ! -s $ENSDIR/${dirname}${head}atmf006.ensmean${SUFFIX} ]; then
    echo "${dirname}${head}atmf006.ensmean${SUFFIX}      " >>enkf${CDUMP}_grp${ENSGRP}.txt
    echo "${dirname}${head}sfcf006.ensmean${SUFFIX}      " >>enkf${CDUMP}_grp${ENSGRP}.txt
    pulldata="YES"
  fi
  tarball="enkf${CDUMP}.tar"
else
  m=1
  while [ $m -le $NMEM_EARCGRP ]; do
    nm=$(((n-1)*NMEM_EARCGRP+m))
    mem=$(printf %03i $nm)
    dirpath="enkf${CDUMP}.${gPDY}/${gcyc}/atmos/mem${mem}/"
    dirname="./${dirpath}"
    head="${CDUMP}.t${gcyc}z."
    fh=3
    while [ $fh -le 9 ]; do
       fhr=$(printf %03i $fh)
       fname=$ENSDIR/${dirname}${head}atmf${fhr}${SUFFIX}
       fsize=`wc -c $fname | awk '{print $1}'`
       if [[ ! -s $fname || $fsize -lt 390000000 ]]; then
         echo "${dirname}${head}atmf${fhr}${SUFFIX}       " >>enkf${CDUMP}_grp${ENSGRP}.txt
         echo "${dirname}${head}sfcf${fhr}${SUFFIX}       " >>enkf${CDUMP}_grp${ENSGRP}.txt
         pulldata="YES"
       fi
       fh=$((fh+1))
    done
    m=$((m+1))
    tarball="enkf${CDUMP}_grp${ENSGRP}.tar"
  done
fi

[[ ! -d $ENSDIR ]] && mkdir -p $ENSDIR
cd $ENSDIR

TARCMD="htar"
if [ $pulldata = "YES" ]; then
  $TARCMD -xvf ${ETARDIR}/${RESTARTEXP}/${GDATE}/${tarball} -L $ARCH_LIST/enkf${CDUMP}_grp${ENSGRP}.txt
  status=$?
  if [ $status -ne 0 ]; then
    echo "$(echo $TARCMD | tr 'a-z' 'A-Z') $GDATE enkf${CDUMP}_grp${ENSGRP}.tar failed"
    exit $status
  fi
else
  echo "data exist, skip pulling data"
fi

if [[ $ENSDIR != $ROTDIR ]]; then
   echo "link data to run directory"
   if [[ $n -eq 0 ]]; then
      dirpath="enkf${CDUMP}.${gPDY}/${gcyc}/atmos/"
      dirname="./${dirpath}"
      head="${CDUMP}.t${gcyc}z."
      $NLN $ENSDIR/${dirname}${head}atmf006.ensmean${SUFFIX} $ROTDIR/${dirname}${head}atmf006.ensmean${SUFFIX}
      $NLN $ENSDIR/${dirname}${head}sfcf006.ensmean${SUFFIX} $ROTDIR/${dirname}${head}sfcf006.ensmean${SUFFIX}
   else
      m=1
      while [ $m -le $NMEM_EARCGRP ]; do
        nm=$(((n-1)*NMEM_EARCGRP+m))
        mem=$(printf %03i $nm)
        dirpath="enkf${CDUMP}.${gPDY}/${gcyc}/atmos/mem${mem}" 
        $NLN $ENSDIR/${dirpath} $ROTDIR/enkf${CDUMP}.${gPDY}/${gcyc}/atmos/
        m=$((m+1))
      done
   fi
else
   echo "data exist in run directory, exit"
   exit 0
fi

# Exit out cleanly
exit 0

