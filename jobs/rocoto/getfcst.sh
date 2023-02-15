#! /usr/bin/env bash

source "$HOMEgfs/ush/preamble.sh"

###############################################################
## Abstract:
## Get GFS intitial conditions
## RUN_ENVIR : runtime environment (emc | nco)
## HOMEgfs   : /full/path/to/workflow
## EXPDIR : /full/path/to/config/files
## CDATE  : current date (YYYYMMDDHH)
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
configs="base getfcst prep" 
for config in $configs; do
    . $EXPDIR/config.${config}
    status=$?
    [[ $status -ne 0 ]] && exit $status
done

###############################################################
# Source machine runtime environment
. $BASE_ENV/${machine}.env getfcst
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
# Set script and dependency variables

export GDATE=$($NDATE -${assim_freq:-"06"} $CDATE)
export gyy=$(echo $GDATE | cut -c1-4)
export gmm=$(echo $GDATE | cut -c5-6)
export gdd=$(echo $GDATE | cut -c7-8)
export ghh=$(echo $GDATE | cut -c9-10)

export FCSTDATA=${FCSTDATA:-$ROTDIR}

# Create FCSTDATA/ROTDIR
if [ ! -d $FCSTDATA ]; then mkdir -p $FCSTDATA ; fi
cd $FCSTDATA

pulldata="NO"
if [[ $FCSTFROM == "forecast-only" ]]; then
   if [ ! -s ${FCSTDATA}/${CDUMP}.${gyy}${gmm}${gdd}/${ghh}/atmos/${CDUMP}.t${ghh}z.atmf006.nc ]; then
     htar -xvf ${FTARDIR}/${FCSTEXP}/${GDATE}/${CDUMP}_netcdfb.tar
     status=$?
     if [ $status -ne 0 ]; then
       echo "pull data failed"
       exit $status
     fi
   fi
else
   >${ROTDIR}/logs/${CDATE}/list.txt
   if [[ $FCSTEXP == "gfs" ]]; then
      fhrs=$(seq 3 3 9)
   else
      fhrs=$(seq 3 9)
   fi
   for n in $fhrs; do
      if [ ! -s ${FCSTDATA}/${CDUMP}.${gyy}${gmm}${gdd}/${ghh}/atmos/${CDUMP}.t${ghh}z.atmf00${n}.nc ]; then
         echo "./${CDUMP}.${gyy}${gmm}${gdd}/${ghh}/atmos/${CDUMP}.t${ghh}z.atmf00${n}.nc" >>${ROTDIR}/logs/${CDATE}/list.txt
         pulldata="YES"
      fi
      if [ ! -s ${FCSTDATA}/${CDUMP}.${gyy}${gmm}${gdd}/${ghh}/atmos/${CDUMP}.t${ghh}z.sfcf00${n}.nc ]; then
         echo "./${CDUMP}.${gyy}${gmm}${gdd}/${ghh}/atmos/${CDUMP}.t${ghh}z.sfcf00${n}.nc" >>${ROTDIR}/logs/${CDATE}/list.txt
         pulldata="YES"
      fi
      if [[ ${DO_MAKEPREPBUFR:-"NO"} == "YES" ]]; then
         if [ ! -s ${FCSTDATA}/${CDUMP}.${gyy}${gmm}${gdd}/${ghh}/atmos/${CDUMP}.t${ghh}z.logf00${n}.txt ]; then
           echo "./${CDUMP}.${gyy}${gmm}${gdd}/${ghh}/atmos/${CDUMP}.t${ghh}z.logf00${n}.txt" >>${ROTDIR}/logs/${CDATE}/list.txt
           pulldata="YES"
         fi
      fi
   done
   if [[ $pulldata == "YES" ]]; then
      if [[ $FCSTEXP == "gfs" ]]; then
         tarball=com_gfs_${version}_${CDUMP}.${gyy}${gmm}${gdd}_${ghh}.gdas_nc.tar
      else
         tarball=${CDUMP}.tar
      fi
      htar -xvf ${FTARDIR}/${tarball} -L ${ROTDIR}/logs/${CDATE}/list.txt
      status=$?
      if [ $status -ne 0 ]; then
         echo "pull data failed"
         exit $status
      fi
   else
      echo "data exist, skip pulling data"
   fi
fi

if [[ ! -s ${FCSTDATA}/${CDUMP}.${gyy}${gmm}${gdd}/${ghh}/atmos/${CDUMP}.t${ghh}z.logf006.txt && ${DO_MAKEPREPBUFR:-"NO"} == "YES" ]]; then
  # create fake log files
  if [[ ! -s ${FCSTDATA}/${CDUMP}.${gyy}${gmm}${gdd}/${ghh}/atmos/${CDUMP}.t${ghh}z.logf006.txt ]]; then
     for fhr in 3 6 9; do
        cat > ${FCSTDATA}/${CDUMP}.${gyy}${gmm}${gdd}/${ghh}/atmos/${CDUMP}.t${ghh}z.logf00${fhr}.txt << EOF
 completed fv3gfs fhour=${fhr}.000 $GDATE
EOF
     done
  fi
fi

if [[ $FCSTFROM == "forecast-only" ]]; then
  COMOUT=${ICSDIR}/${ICDUMP}.${gyy}${gmm}${gdd}/${ghh}/atmos
  $NLN ${COMOUT}/*abias* ${ROTDIR}/${CDUMP}.${gyy}${gmm}${gdd}/${ghh}/atmos/
  $NLN ${COMOUT}/*radstat ${ROTDIR}/${CDUMP}.${gyy}${gmm}${gdd}/${ghh}/atmos/
else
  if [ ! -s ${FCSTDATA}/${CDUMP}.${gyy}${gmm}${gdd}/${ghh}/atmos/gdas.t${ghh}z.radstat ]; then 
    if [[ $FCSTEXP == "gfs" ]]; then
       tarball=com_gfs_${version}_${CDUMP}.${gyy}${gmm}${gdd}_${ghh}.gdas_restart.tar
    else
       tarball=${CDUMP}.tar
    fi
    htar -xvf ${FTARDIR}/${tarball} ./${CDUMP}.${gyy}${gmm}${gdd}/${ghh}/atmos/gdas.t${ghh}z.radstat
    if [[ $FCSTEXP == "gfs" ]]; then
       tarball=com_gfs_${version}_${CDUMP}.${gyy}${gmm}${gdd}_${ghh}.gdas_restart.tar
    else
       tarball=${CDUMP}_restarta.tar
    fi
    htar -tvf ${FTARDIR}/${tarball} > ${ROTDIR}/logs/${CDATE}/list1
  fi
  if [ ! -s ${FCSTDATA}/${CDUMP}.${gyy}${gmm}${gdd}/${ghh}/atmos/gdas.t${ghh}z.abias ]; then 
    >${ROTDIR}/logs/${CDATE}/list2
    grep abias ${ROTDIR}/logs/${CDATE}/list1 | awk '{ print $7 }' >> ${ROTDIR}/logs/${CDATE}/list2
    htar -xvf ${FTARDIR}/${tarball} -L ${ROTDIR}/logs/${CDATE}/list2
  fi
fi

if [ ! -d $ROTDIR/${CDUMP}.${gyy}${gmm}${gdd}/${ghh}/atmos ]; then 
   mkdir -p $ROTDIR/${CDUMP}.${gyy}${gmm}${gdd}/${ghh}/atmos
fi
$NLN ${FCSTDATA}/${CDUMP}.${gyy}${gmm}${gdd}/${ghh}/atmos/* ${ROTDIR}/${CDUMP}.${gyy}${gmm}${gdd}/${ghh}/atmos/

exit 0


